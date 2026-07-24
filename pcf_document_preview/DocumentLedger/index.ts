import { IInputs, IOutputs } from "./generated/ManifestTypes";

interface ContextInfo {
    entityId?: string;
    entityTypeName?: string;
}

interface LedgerDocument {
    alex_payplusdocumentid?: string;
    alex_documentnumber?: string;
    alex_name?: string;
    alex_documenttypecode?: string;
    alex_documentrole?: number;
    alex_businessstatus?: number;
    alex_totalamount?: number;
    alex_vatamount?: number;
    alex_vatpercentage?: number;
    alex_balanceamount?: number;
    alex_paidamount?: number;
    alex_currencycode?: string;
    alex_customername?: string;
    alex_documentdate?: string;
    alex_issuedon?: string;
    createdon?: string;
    modifiedon?: string;
    _alex_reversesdocumentid_value?: string;
    _alex_invoiceid_value?: string;
    _alex_contactid_value?: string;
    _alex_accountid_value?: string;
}

type LoadState = "loading" | "ready" | "empty" | "waiting" | "error";
type Scope = "invoice" | "contact" | "account";
type TypeClass = "charge" | "credit" | "receipt" | "info";
type StatusGroup = "issued" | "pending" | "failed" | "cancelled";

interface TypeMeta {
    he: string;
    en: string;
    cls: TypeClass;
    sign: number; // ledger sign for total: +1 charge, -1 credit, 0 informational
    usesPaid?: boolean;
}

interface StatusMeta {
    he: string;
    en: string;
    group: StatusGroup;
}

const CANCELLED = 100000007;

// Existing DocumentPreview custom page (preview + quick actions), reused for the side pane.
const PREVIEW_CUSTOM_PAGE_NAME = "alex_payplusdocumentpreview_b4f29";

const TYPE_MAP: Record<string, TypeMeta> = {
    inv_tax: { he: "חשבונית מס", en: "Tax invoice", cls: "charge", sign: 1 },
    inv_tax_receipt: { he: "חשבונית מס קבלה", en: "Tax invoice receipt", cls: "receipt", sign: 1, usesPaid: true },
    inv_receipt: { he: "קבלה", en: "Receipt", cls: "receipt", sign: -1, usesPaid: true },
    inv_refund: { he: "חשבונית זיכוי", en: "Credit invoice", cls: "credit", sign: -1 },
    inv_proforma: { he: "חשבונית עסקה", en: "Proforma invoice", cls: "info", sign: 0 },
    inv_pay_request: { he: "בקשת תשלום", en: "Payment request", cls: "info", sign: 0 },
    dc_quote: { he: "הצעת מחיר", en: "Quote", cls: "info", sign: 0 },
    purchase: { he: "מסמך רכש", en: "Purchase", cls: "info", sign: 0 }
};

const STATUS_MAP: Record<number, StatusMeta> = {
    100000000: { he: "תצוגה מקדימה ממתינה", en: "Preview pending", group: "pending" },
    100000001: { he: "תצוגה מקדימה מוכנה", en: "Preview ready", group: "pending" },
    100000002: { he: "הפקה ממתינה", en: "Issue pending", group: "pending" },
    100000003: { he: "הופק", en: "Issued", group: "issued" },
    100000004: { he: "פעולה התבקשה", en: "Action requested", group: "pending" },
    100000005: { he: "פעולה נרשמה", en: "Action composed", group: "pending" },
    100000006: { he: "נכשל", en: "Failed", group: "failed" },
    100000007: { he: "בוטל", en: "Cancelled", group: "cancelled" },
    100000008: { he: "נסגר", en: "Closed", group: "cancelled" }
};

const SELECT_FIELDS = [
    "alex_payplusdocumentid",
    "alex_documentnumber",
    "alex_name",
    "alex_documenttypecode",
    "alex_documentrole",
    "alex_businessstatus",
    "alex_totalamount",
    "alex_vatamount",
    "alex_vatpercentage",
    "alex_balanceamount",
    "alex_paidamount",
    "alex_currencycode",
    "alex_customername",
    "alex_documentdate",
    "alex_issuedon",
    "createdon",
    "modifiedon",
    "_alex_reversesdocumentid_value",
    "_alex_invoiceid_value",
    "_alex_contactid_value",
    "_alex_accountid_value"
].join(",");

const SCOPE_FILTER_FIELD: Record<Scope, string> = {
    invoice: "_alex_invoiceid_value",
    contact: "_alex_contactid_value",
    account: "_alex_accountid_value"
};

export class DocumentLedger implements ComponentFramework.StandardControl<IInputs, IOutputs> {
    private context!: ComponentFramework.Context<IInputs>;
    private root!: HTMLDivElement;
    private hostValue = "";
    private isRtl = false;
    private state: LoadState = "loading";
    private errorText = "";
    private scope: Scope | null = null;
    private recordId = "";
    private documents: LedgerDocument[] = [];
    private loadToken = 0;
    private selectedTypes = new Set<string>();
    private selectedStatusGroups = new Set<StatusGroup>();
    private searchText = "";

    public init(
        context: ComponentFramework.Context<IInputs>,
        _notifyOutputChanged: () => void,
        _state: ComponentFramework.Dictionary,
        container: HTMLDivElement
    ): void {
        this.context = context;
        this.hostValue = context.parameters.hostValue.raw || "";
        this.isRtl = this.detectRtl(context);
        context.mode.trackContainerResize(true);

        this.root = document.createElement("div");
        this.root.className = "ppl";
        this.root.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
        container.appendChild(this.root);

        this.resolveContext();
        this.render();
        void this.loadDocuments();
    }

    public updateView(context: ComponentFramework.Context<IInputs>): void {
        this.context = context;
        this.hostValue = context.parameters.hostValue.raw || this.hostValue;
        const nextRtl = this.detectRtl(context);
        if (nextRtl !== this.isRtl) {
            this.isRtl = nextRtl;
            this.root.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
        }
        const prevKey = `${this.scope}|${this.recordId}`;
        this.resolveContext();
        if (`${this.scope}|${this.recordId}` !== prevKey) {
            void this.loadDocuments();
        }
    }

    public getOutputs(): IOutputs {
        return { hostValue: this.hostValue };
    }

    public destroy(): void {
        this.root.replaceChildren();
    }

    // ---------- context ----------
    private asString(value: unknown): string {
        return typeof value === "string" ? value : "";
    }

    private resolveContext(): void {
        const modeInfo = (this.context.mode as unknown as { contextInfo?: ContextInfo }).contextInfo;
        const pageInfo = (this.context as unknown as { page?: ContextInfo }).page;
        const overrideId = this.asString(this.context.parameters.recordId?.raw);
        const overrideEntity = this.asString(this.context.parameters.entityLogicalName?.raw).toLowerCase();
        const overrideScope = this.asString(this.context.parameters.scope?.raw).toLowerCase();

        const entity = (overrideEntity || this.asString(modeInfo?.entityTypeName) || this.asString(pageInfo?.entityTypeName)).toLowerCase();
        this.recordId = (overrideId || this.asString(modeInfo?.entityId) || this.asString(pageInfo?.entityId)).replace(/[{}]/g, "").toLowerCase();

        if (overrideScope === "invoice" || overrideScope === "contact" || overrideScope === "account") {
            this.scope = overrideScope;
        } else if (entity === "invoice" || entity === "contact" || entity === "account") {
            this.scope = entity as Scope;
        } else {
            this.scope = null;
        }
    }

    private detectRtl(context: ComponentFramework.Context<IInputs>): boolean {
        const userSettings = context.userSettings as unknown as { languageId?: number; isRTL?: boolean; isRtl?: boolean };
        if (userSettings.languageId === 1037 || userSettings.isRTL === true || userSettings.isRtl === true) return true;
        const xrmLang = this.hostLanguageId();
        if (xrmLang === 1037) return true;
        const lang = (document.documentElement.lang || "").toLowerCase();
        const dir = (document.documentElement.dir || document.body.dir || "").toLowerCase();
        if (dir === "rtl" || lang.startsWith("he")) return true;
        return (navigator.languages || [navigator.language]).some((l) => (l || "").toLowerCase().startsWith("he"));
    }

    private hostLanguageId(): number | null {
        for (const candidate of [window, window.parent] as (Window | null)[]) {
            try {
                const xrm = (candidate as unknown as { Xrm?: { Utility?: { getGlobalContext?: () => { userSettings?: { languageId?: number } } } } }).Xrm;
                const id = xrm?.Utility?.getGlobalContext?.().userSettings?.languageId;
                if (typeof id === "number") return id;
            } catch {
                // cross-origin frame
            }
        }
        return null;
    }

    // ---------- data ----------
    private async loadDocuments(): Promise<void> {
        if (!this.scope || !this.recordId) {
            this.state = "waiting";
            this.documents = [];
            this.render();
            return;
        }
        const token = ++this.loadToken;
        this.state = "loading";
        this.errorText = "";
        this.render();
        try {
            if (!this.context.webAPI?.retrieveMultipleRecords) {
                throw new Error(this.t("webApiUnavailable"));
            }
            const field = SCOPE_FILTER_FIELD[this.scope];
            const query = `?$select=${SELECT_FIELDS}&$filter=${field} eq ${this.recordId}&$orderby=createdon desc`;
            const result = await this.context.webAPI.retrieveMultipleRecords("alex_payplusdocument", query);
            if (token !== this.loadToken) return;
            this.documents = (result.entities || []) as LedgerDocument[];
            this.state = this.documents.length ? "ready" : "empty";
            this.render();
        } catch (error) {
            if (token !== this.loadToken) return;
            this.documents = [];
            this.state = "error";
            this.errorText = error instanceof Error ? error.message : String(error);
            this.render();
        }
    }

    // ---------- accounting ----------
    private typeMeta(code?: string): TypeMeta {
        return (code && TYPE_MAP[code]) || { he: code || "-", en: code || "-", cls: "info", sign: 0 };
    }

    private isCancelled(doc: LedgerDocument): boolean {
        return doc.alex_businessstatus === CANCELLED;
    }

    private signedImpact(doc: LedgerDocument): number {
        if (this.isCancelled(doc)) return 0;
        const meta = this.typeMeta(doc.alex_documenttypecode);
        if (meta.sign === 0) return 0;
        const base = meta.usesPaid
            ? (typeof doc.alex_paidamount === "number" ? doc.alex_paidamount : doc.alex_totalamount || 0)
            : (doc.alex_totalamount || 0);
        return meta.sign * Math.abs(base);
    }

    private beforeVat(doc: LedgerDocument): number {
        const total = doc.alex_totalamount || 0;
        const vat = doc.alex_vatamount || 0;
        return total - vat;
    }

    private docDate(doc: LedgerDocument): string | undefined {
        return doc.alex_documentdate || doc.alex_issuedon || doc.createdon;
    }

    // Derived payment state for charge documents (from remaining balance).
    private paymentState(doc: LedgerDocument): { label: string; cls: "paid" | "open" } | null {
        const meta = this.typeMeta(doc.alex_documenttypecode);
        if (this.isCancelled(doc) || meta.sign <= 0) return null;
        if (typeof doc.alex_balanceamount !== "number") return null;
        if (doc.alex_balanceamount <= 0.004) return { label: this.t("paid"), cls: "paid" };
        return { label: this.t("open"), cls: "open" };
    }

    // ---------- filtering ----------
    private visibleDocuments(): LedgerDocument[] {
        const search = this.searchText.trim().toLowerCase();
        return this.documents.filter((doc) => {
            if (this.selectedTypes.size && !this.selectedTypes.has(doc.alex_documenttypecode || "")) return false;
            if (this.selectedStatusGroups.size) {
                const g = STATUS_MAP[doc.alex_businessstatus ?? -1]?.group;
                if (!g || !this.selectedStatusGroups.has(g)) return false;
            }
            if (search) {
                const hay = `${doc.alex_documentnumber || ""} ${doc.alex_name || ""} ${doc.alex_customername || ""}`.toLowerCase();
                if (hay.indexOf(search) < 0) return false;
            }
            return true;
        });
    }

    private currencyCode(): string {
        const found = this.documents.find((d) => d.alex_currencycode);
        return found?.alex_currencycode || "ILS";
    }

    private formatMoney(value: number): string {
        const locale = this.isRtl ? "he-IL" : "en-US";
        try {
            return new Intl.NumberFormat(locale, { style: "currency", currency: this.currencyCode(), minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value);
        } catch {
            return value.toFixed(2);
        }
    }

    private formatDate(iso?: string): string {
        if (!iso) return "";
        const d = new Date(iso);
        if (isNaN(d.getTime())) return "";
        return d.toLocaleDateString(this.isRtl ? "he-IL" : "en-US", { day: "2-digit", month: "2-digit", year: "numeric" });
    }

    // ---------- rendering ----------
    private render(): void {
        this.root.replaceChildren();
        const shell = this.el("div", "ppl-shell");
        this.root.appendChild(shell);

        if (this.state === "loading") {
            shell.appendChild(this.stateBlock(this.el("div", "ppl-spinner"), this.t("loading")));
            return;
        }
        if (this.state === "waiting") {
            shell.appendChild(this.stateBlock(this.iconBox("📄"), this.t("noContext")));
            return;
        }
        if (this.state === "error") {
            shell.appendChild(this.stateBlock(this.iconBox("⚠️"), `${this.t("error")}: ${this.errorText}`));
            return;
        }

        shell.appendChild(this.renderSummary());
        shell.appendChild(this.renderFilters());

        if (this.state === "empty") {
            shell.appendChild(this.stateBlock(this.iconBox("📄"), this.t("empty")));
            return;
        }

        const visible = this.visibleDocuments();
        if (!visible.length) {
            shell.appendChild(this.stateBlock(this.iconBox("🔍"), this.t("noMatch")));
            return;
        }
        shell.appendChild(this.renderTable(visible));
    }

    private renderSummary(): HTMLElement {
        const active = this.documents.filter((d) => !this.isCancelled(d));
        let charges = 0;
        let credits = 0;
        for (const doc of active) {
            const impact = this.signedImpact(doc);
            if (impact > 0) charges += impact;
            else if (impact < 0) credits += Math.abs(impact);
        }
        const balance = charges - credits;

        const wrap = this.el("div", "ppl-summary");
        wrap.appendChild(this.summaryCard(this.t("charges"), this.formatMoney(charges), null));
        wrap.appendChild(this.summaryCard(this.t("credits"), this.formatMoney(credits), null));

        const balCard = this.summaryCard(this.t("balance"), this.formatMoney(balance), this.t("balanceSub"), "ppl-balance");
        const valueEl = balCard.querySelector(".ppl-card-value") as HTMLElement;
        valueEl.classList.add(balance > 0.004 ? "ppl-pos" : balance < -0.004 ? "ppl-neg" : "ppl-zero");
        wrap.appendChild(balCard);

        wrap.appendChild(this.summaryCard(this.t("count"), String(this.documents.length), this.t("countSub")));
        return wrap;
    }

    private summaryCard(label: string, value: string, sub: string | null, extraCls = ""): HTMLElement {
        const card = this.el("div", `ppl-card ${extraCls}`.trim());
        card.appendChild(this.el("div", "ppl-card-label", label));
        card.appendChild(this.el("div", "ppl-card-value", value));
        if (sub) card.appendChild(this.el("div", "ppl-card-sub", sub));
        return card;
    }

    private renderFilters(): HTMLElement {
        const bar = this.el("div", "ppl-filters");

        const typeGroup = this.el("div", "ppl-group");
        const presentTypes: string[] = [];
        for (const doc of this.documents) {
            const code = doc.alex_documenttypecode || "";
            if (code && presentTypes.indexOf(code) < 0) presentTypes.push(code);
        }
        for (const code of presentTypes) {
            const meta = this.typeMeta(code);
            const chip = this.chip(this.isRtl ? meta.he : meta.en, this.selectedTypes.has(code), () => {
                if (this.selectedTypes.has(code)) this.selectedTypes.delete(code);
                else this.selectedTypes.add(code);
                this.render();
            });
            typeGroup.appendChild(chip);
        }
        bar.appendChild(typeGroup);

        const presentGroups: StatusGroup[] = [];
        for (const doc of this.documents) {
            const g = STATUS_MAP[doc.alex_businessstatus ?? -1]?.group;
            if (g && presentGroups.indexOf(g) < 0) presentGroups.push(g);
        }
        if (presentTypes.length && presentGroups.length) bar.appendChild(this.el("div", "ppl-sep"));

        const statusGroup = this.el("div", "ppl-group");
        const groupLabels: Record<StatusGroup, string> = {
            issued: this.t("gIssued"),
            pending: this.t("gPending"),
            failed: this.t("gFailed"),
            cancelled: this.t("gCancelled")
        };
        for (const g of presentGroups) {
            const chip = this.chip(groupLabels[g], this.selectedStatusGroups.has(g), () => {
                if (this.selectedStatusGroups.has(g)) this.selectedStatusGroups.delete(g);
                else this.selectedStatusGroups.add(g);
                this.render();
            });
            statusGroup.appendChild(chip);
        }
        bar.appendChild(statusGroup);

        const searchWrap = this.el("div", "ppl-search");
        const input = document.createElement("input");
        input.type = "search";
        input.placeholder = this.t("searchPh");
        input.value = this.searchText;
        input.addEventListener("input", () => {
            this.searchText = input.value;
            this.renderTableOnly();
        });
        searchWrap.appendChild(input);
        bar.appendChild(searchWrap);
        return bar;
    }

    private renderTableOnly(): void {
        const shell = this.root.querySelector(".ppl-shell");
        if (!shell) return;
        const old = shell.querySelector(".ppl-scroll, .ppl-state");
        const visible = this.visibleDocuments();
        const next = visible.length ? this.renderTable(visible) : this.stateBlock(this.iconBox("🔍"), this.t("noMatch"));
        if (old) shell.replaceChild(next, old);
        else shell.appendChild(next);
    }

    private renderTable(rows: LedgerDocument[]): HTMLElement {
        const scroll = this.el("div", "ppl-scroll");
        const table = document.createElement("table");
        table.className = "ppl-table";

        const thead = document.createElement("thead");
        const htr = document.createElement("tr");
        const headers: [string, boolean][] = [
            [this.t("colDoc"), false],
            [this.t("colType"), false],
            [this.t("colDate"), false],
            [this.t("colBeforeVat"), true],
            [this.t("colVat"), true],
            [this.t("colTotal"), true],
            [this.t("colStatus"), false]
        ];
        for (const [label, num] of headers) {
            const th = document.createElement("th");
            th.textContent = label;
            if (num) th.className = "ppl-num";
            htr.appendChild(th);
        }
        thead.appendChild(htr);
        table.appendChild(thead);

        const tbody = document.createElement("tbody");
        for (const doc of rows) {
            tbody.appendChild(this.renderRow(doc));
        }
        table.appendChild(tbody);
        scroll.appendChild(table);
        return scroll;
    }

    private renderRow(doc: LedgerDocument): HTMLElement {
        const meta = this.typeMeta(doc.alex_documenttypecode);
        const cancelled = this.isCancelled(doc);
        const tr = document.createElement("tr");
        if (cancelled) tr.className = "ppl-row-cancelled";
        tr.addEventListener("click", () => this.openDocument(doc));

        // doc column
        const docTd = document.createElement("td");
        const main = this.el("div", "ppl-doc-main");
        main.appendChild(this.el("div", "ppl-doc-number", doc.alex_documentnumber || doc.alex_name || "—"));
        if (this.scope === "account" && doc.alex_customername) main.appendChild(this.el("div", "ppl-doc-sub", doc.alex_customername));
        docTd.appendChild(main);
        tr.appendChild(docTd);

        // type pill
        const typeTd = document.createElement("td");
        typeTd.appendChild(this.pill(this.isRtl ? meta.he : meta.en, `ppl-pill-type ppl-t-${meta.cls}`));
        tr.appendChild(typeTd);

        // date (document date, fallback issued / created)
        tr.appendChild(this.tdText(this.formatDate(this.docDate(doc))));

        // amounts (sign applied by ledger direction)
        const sign = cancelled ? 0 : meta.sign;
        const displaySign = sign < 0 ? -1 : 1;
        const muted = sign === 0 || cancelled;

        tr.appendChild(this.tdMoney(this.beforeVat(doc) * displaySign, sign, muted));
        tr.appendChild(this.tdMoney((doc.alex_vatamount || 0) * displaySign, sign, true));
        const totalTd = this.tdMoney((doc.alex_totalamount || 0) * displaySign, sign, muted);
        (totalTd.firstChild as HTMLElement)?.classList.add("ppl-amt-total");
        tr.appendChild(totalTd);

        // status pill + derived payment state
        const statusTd = document.createElement("td");
        const statusWrap = this.el("div", "ppl-status-cell");
        const sm = STATUS_MAP[doc.alex_businessstatus ?? -1];
        if (sm) statusWrap.appendChild(this.pill(this.isRtl ? sm.he : sm.en, `ppl-pill-status ppl-s-${sm.group}`));
        const pay = this.paymentState(doc);
        if (pay) statusWrap.appendChild(this.pill(pay.label, `ppl-pill-pay ppl-pay-${pay.cls}`));
        statusTd.appendChild(statusWrap);
        tr.appendChild(statusTd);

        return tr;
    }

    private tdText(text: string): HTMLElement {
        const td = document.createElement("td");
        td.textContent = text;
        return td;
    }

    private tdMoney(value: number, sign: number, muted = false): HTMLElement {
        const td = document.createElement("td");
        td.className = "ppl-num";
        const span = document.createElement("span");
        span.textContent = this.formatMoney(value);
        if (muted) span.className = "ppl-amt-muted";
        else if (sign < 0) span.className = "ppl-amt-credit";
        else span.className = "ppl-amt-charge";
        td.appendChild(span);
        return td;
    }

    // ---------- side pane ----------
    private openDocument(doc: LedgerDocument): void {
        const id = (doc.alex_payplusdocumentid || "").replace(/[{}]/g, "");
        if (!id) return;
        const xrm = this.getXrm();
        const nav = xrm?.Navigation;
        if (!nav || typeof nav.navigateTo !== "function") return;
        const title = doc.alex_documentnumber || doc.alex_name || this.t("colDoc");

        // Preferred: the existing DocumentPreview custom page (preview + quick actions), same as the ribbon.
        const customPage = {
            pageType: "custom",
            name: PREVIEW_CUSTOM_PAGE_NAME,
            entityName: "alex_payplusdocument",
            recordId: id
        };
        const navOptions = {
            target: 2,
            position: 1,
            width: { value: 82, unit: "%" },
            height: { value: 86, unit: "%" },
            title
        };
        try {
            // Bound call — navigateTo needs its `this` to be Xrm.Navigation.
            const result = nav.navigateTo(customPage, navOptions) as { catch?: (cb: (e?: unknown) => void) => void } | undefined;
            if (result && typeof result.catch === "function") {
                result.catch(() => this.openRecordFallback(nav, id, title));
            }
        } catch {
            this.openRecordFallback(nav, id, title);
        }
    }

    private openRecordFallback(nav: NonNullable<XrmLike["Navigation"]>, id: string, title: string): void {
        try {
            nav.navigateTo?.(
                { pageType: "entityrecord", entityName: "alex_payplusdocument", entityId: id },
                { target: 2, position: 1, width: { value: 82, unit: "%" }, height: { value: 86, unit: "%" }, title }
            );
        } catch {
            // no-op; nothing else we can do in edit mode
        }
    }

    private getXrm(): XrmLike | null {
        for (const candidate of [window, window.parent] as (Window | null)[]) {
            try {
                const xrm = (candidate as unknown as { Xrm?: XrmLike }).Xrm;
                if (xrm) return xrm;
            } catch {
                // cross-origin
            }
        }
        return null;
    }

    // ---------- dom helpers ----------
    private el(tag: string, className = "", text?: string): HTMLElement {
        const node = document.createElement(tag);
        if (className) node.className = className;
        if (text !== undefined) node.textContent = text;
        return node;
    }

    private chip(label: string, active: boolean, onClick: () => void): HTMLButtonElement {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = active ? "ppl-chip ppl-active" : "ppl-chip";
        btn.textContent = label;
        btn.addEventListener("click", onClick);
        return btn;
    }

    private pill(label: string, cls: string): HTMLElement {
        const span = document.createElement("span");
        span.className = `ppl-pill ${cls}`;
        span.textContent = label;
        return span;
    }

    private iconBox(glyph: string): HTMLElement {
        return this.el("div", "ppl-empty-icon", glyph);
    }

    private stateBlock(icon: HTMLElement, message: string): HTMLElement {
        const block = this.el("div", "ppl-state");
        block.appendChild(icon);
        block.appendChild(this.el("span", "", message));
        return block;
    }

    // ---------- i18n ----------
    private t(key: string): string {
        const he: Record<string, string> = {
            loading: "טוען מסמכים...",
            noContext: "פתחו רשומת חשבונית, איש קשר או תיק לקוח כדי להציג מסמכים.",
            empty: "אין מסמכי PayPlus לרשומה זו.",
            noMatch: "אין מסמכים התואמים לסינון.",
            error: "שגיאה",
            webApiUnavailable: "הפקד יפעל לאחר פרסום הדף בתוך אפליקציית model-driven. Web API אינו זמין במצב עריכה.",
            charges: "סך חיובים",
            credits: "סך זיכויים",
            balance: "יתרה סופית",
            balanceSub: "לאחר קיזוז זיכויים ותקבולים",
            count: "מסמכים",
            countSub: "כולל מבוטלים",
            gIssued: "הופק",
            gPending: "ממתין",
            gFailed: "נכשל",
            gCancelled: "בוטל",
            searchPh: "חיפוש מסמך...",
            colDoc: "מסמך",
            colType: "סוג",
            colDate: "תאריך מסמך",
            colBeforeVat: "לפני מע\"מ",
            colVat: "מע\"מ",
            colTotal: "כולל",
            colStatus: "מצב",
            paid: "נפרע",
            open: "לתשלום"
        };
        const en: Record<string, string> = {
            loading: "Loading documents...",
            noContext: "Open an invoice, contact or account record to view documents.",
            empty: "No PayPlus documents for this record.",
            noMatch: "No documents match the current filter.",
            error: "Error",
            webApiUnavailable: "This control runs after publishing inside a model-driven app. Web API is not available in edit mode.",
            charges: "Total charges",
            credits: "Total credits",
            balance: "Final balance",
            balanceSub: "After credits and receipts",
            count: "Documents",
            countSub: "Including cancelled",
            gIssued: "Issued",
            gPending: "Pending",
            gFailed: "Failed",
            gCancelled: "Cancelled",
            searchPh: "Search document...",
            colDoc: "Document",
            colType: "Type",
            colDate: "Doc date",
            colBeforeVat: "Before VAT",
            colVat: "VAT",
            colTotal: "Total",
            colStatus: "Status",
            paid: "Paid",
            open: "Open"
        };
        const table = this.isRtl ? he : en;
        return table[key] ?? key;
    }
}

interface XrmLike {
    Navigation?: {
        navigateTo?: (pageInput: unknown, navigationOptions?: unknown) => unknown;
    };
}
