import { IInputs, IOutputs } from "./generated/ManifestTypes";

/* Shape we access from the model-driven page context (typed loosely on purpose). */
interface ContextInfo {
    entityId: string;
    entityTypeName: string;
    entityRecordName: string;
}

/* A parsed customer bank-account row ready for rendering. */
interface BankAccount {
    id: string;
    name: string;
    holder: string;
    accountNumber: string;
    isActive: boolean;
    isDefault: boolean;
    hasStandingOrder: boolean;
    standingSince: string;
    standingRef: string;
    bankId: string;
    bankCode: string;
    bankName: string;
    branchId: string;
    branchCode: string;
    branchName: string;
    syncStatus: number | null;
}

/* Lightweight bank / branch reference used by the add panel pickers. */
interface BankRef { id: string; code: string; name: string; }
interface BranchRef { id: string; code: string; name: string; bankId: string; }

/* A receipt / tax-invoice-receipt document settled from a given bank account. */
interface ReceiptDoc {
    id: string;
    number: string;
    typeCode: string;
    typeLabel: string;
    amount: number;
    amountText: string;
    currency: string;
    dateText: string;
    statusText: string;
    pdfUrl: string;
    docUrl: string;
    sortKey: number;
}

/* Bank codes whose uploaded logo web resource is an SVG (all others are PNG). */
const LOGO_SVG_CODES = new Set<string>(["20"]);
const LOGO_BASE = "/WebResources/alex_/banklogos/bank_";

/* alex_syncstatus choice values (mirrors the field definition). */
const SYNC_PENDING = 100000000;

export class BankAccountWallet implements ComponentFramework.StandardControl<IInputs, IOutputs> {
    private context!: ComponentFramework.Context<IInputs>;
    private root!: HTMLDivElement;
    private isRtl = false;
    private parentId = "";
    private parentType = "";
    private accounts: BankAccount[] = [];
    private status: "loading" | "ready" | "error" = "loading";
    private prevLoading = false;

    // Add panel (Apple-style slide-in drawer attached to <body>).
    private panelRoot: HTMLDivElement | null = null;
    private banks: BankRef[] = [];
    private branchesByBank: Record<string, BranchRef[]> = {};
    private saving = false;
    private panelKeyHandler = (e: KeyboardEvent): void => {
        if (e.key === "Escape") this.closePanel();
    };

    // Receipts pane (Apple-style drawer) — documents settled from one bank account.
    private recRoot: HTMLDivElement | null = null;
    private recBodyEl: HTMLDivElement | null = null;
    private recAcctId = "";
    private recStatus: "loading" | "ready" | "error" = "loading";
    private recDocs: ReceiptDoc[] = [];
    private recView: "list" | "detail" = "list";
    private recKeyHandler = (e: KeyboardEvent): void => {
        if (e.key === "Escape") this.closeReceipts();
    };

    public init(
        context: ComponentFramework.Context<IInputs>,
        _notifyOutputChanged: () => void,
        _state: ComponentFramework.Dictionary,
        container: HTMLDivElement
    ): void {
        this.context = context;
        context.mode.trackContainerResize(true);

        this.isRtl = context.userSettings.languageId === 1037; // Hebrew
        this.root = document.createElement("div");
        this.root.className = "ppb-wallet";
        this.root.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
        container.appendChild(this.root);

        this.resolveParent();
        this.render();
        void this.load();
    }

    public updateView(context: ComponentFramework.Context<IInputs>): void {
        this.context = context;
        const ds = context.parameters.accounts;
        const loading = !!ds && ds.loading;
        if (this.prevLoading && !loading) void this.load();
        this.prevLoading = loading;

        const prevId = this.parentId;
        this.resolveParent();
        if (this.parentId && this.parentId !== prevId) void this.load();
    }

    public getOutputs(): IOutputs {
        return {};
    }

    public destroy(): void {
        document.removeEventListener("keydown", this.panelKeyHandler, true);
        document.removeEventListener("keydown", this.recKeyHandler, true);
        if (this.panelRoot) { this.panelRoot.remove(); this.panelRoot = null; }
        if (this.recRoot) { this.recRoot.remove(); this.recRoot = null; }
    }

    /* ---------------------------------------------------------------- data */

    private resolveParent(): void {
        const ci =
            ((this.context.mode as unknown as { contextInfo?: ContextInfo }).contextInfo) ||
            ((this.context as unknown as { page?: ContextInfo }).page);
        if (ci && ci.entityId) {
            this.parentId = (ci.entityId || "").replace(/[{}]/g, "").toLowerCase();
            this.parentType = (ci.entityTypeName || "").toLowerCase();
        }
    }

    private lookupField(): string | null {
        if (this.parentType === "contact") return "_alex_contactid_value";
        if (this.parentType === "account") return "_alex_accountid_value";
        return null;
    }

    private async load(): Promise<void> {
        const lf = this.lookupField();
        if (!this.parentId || !lf) {
            this.accounts = [];
            this.status = "ready";
            this.render();
            return;
        }
        this.status = this.accounts.length ? "ready" : "loading";
        this.render();

        const select =
            "$select=alex_customerbankaccountid,alex_name,alex_accountholdername,alex_accountnumber," +
            "alex_isdefault,alex_isactive,alex_hasstandingorder,alex_standingordersince," +
            "alex_standingorderreference,alex_syncstatus";
        const expand =
            "$expand=alex_BankId($select=alex_bankid,alex_bankcode,alex_name)," +
            "alex_BranchId($select=alex_bankbranchid,alex_branchcode,alex_name)";
        const query =
            "?" + select + "&" + expand +
            "&$filter=" + lf + " eq " + this.parentId + " and alex_isactive eq true" +
            "&$orderby=alex_isdefault desc,createdon desc";

        try {
            const res = await this.context.webAPI.retrieveMultipleRecords("alex_customerbankaccount", query);
            this.accounts = res.entities.map((e) => this.parseAccount(e));
            this.status = "ready";
        } catch {
            this.status = "error";
        }
        this.render();
    }

    private parseAccount(e: ComponentFramework.WebApi.Entity): BankAccount {
        const bank = (e["alex_BankId"] as Record<string, unknown> | null) || null;
        const branch = (e["alex_BranchId"] as Record<string, unknown> | null) || null;
        return {
            id: String(e["alex_customerbankaccountid"] || ""),
            name: String(e["alex_name"] || ""),
            holder: String(e["alex_accountholdername"] || ""),
            accountNumber: String(e["alex_accountnumber"] || ""),
            isActive: e["alex_isactive"] !== false,
            isDefault: e["alex_isdefault"] === true,
            hasStandingOrder: e["alex_hasstandingorder"] === true,
            standingSince: String(e["alex_standingordersince"] || ""),
            standingRef: String(e["alex_standingorderreference"] || ""),
            bankId: bank ? String(bank["alex_bankid"] || "") : "",
            bankCode: bank ? String(bank["alex_bankcode"] || "") : "",
            bankName: bank ? String(bank["alex_name"] || "") : "",
            branchId: branch ? String(branch["alex_bankbranchid"] || "") : "",
            branchCode: branch ? String(branch["alex_branchcode"] || "") : "",
            branchName: branch ? String(branch["alex_name"] || "") : "",
            syncStatus: typeof e["alex_syncstatus"] === "number" ? (e["alex_syncstatus"] as number) : null,
        };
    }

    /* ------------------------------------------------------------- helpers */

    private t(key: string): string {
        try { return this.context.resources.getString(key) || key; } catch { return key; }
    }

    private el(tag: string, className?: string, text?: string): HTMLElement {
        const n = document.createElement(tag);
        if (className) n.className = className;
        if (text != null) n.textContent = text;
        return n;
    }

    private logoUrl(code: string): string {
        const ext = LOGO_SVG_CODES.has(code) ? "svg" : "png";
        return LOGO_BASE + code + "." + ext;
    }

    private maskAccount(num: string): string {
        const clean = (num || "").replace(/\s+/g, "");
        if (clean.length <= 4) return clean || this.t("dash");
        return "•••• " + clean.slice(-4);
    }

    private initials(name: string): string {
        const s = (name || "").trim();
        if (!s) return "?";
        const parts = s.split(/\s+/).filter(Boolean);
        const chars = parts.slice(0, 2).map((p) => p.charAt(0)).join("");
        return chars.toUpperCase() || "?";
    }

    /* -------------------------------------------------------------- render */

    private render(): void {
        this.root.innerHTML = "";

        // Header / toolbar.
        const head = this.el("div", "ppb-head");
        const titles = this.el("div", "ppb-head-titles");
        const title = this.el("div", "ppb-title");
        title.appendChild(this.el("span", "ppb-logo", "₪"));
        title.appendChild(this.el("span", undefined, this.t("title")));
        titles.appendChild(title);
        const count = this.accounts.length;
        const suffix = count === 1 ? this.t("countOne") : this.t("countSuffix");
        titles.appendChild(this.el("div", "ppb-sub", count ? `${count} ${suffix}` : this.t("subtitle")));
        head.appendChild(titles);

        const actions = this.el("div", "ppb-actions");
        const addBtn = this.el("button", "ppb-btn ppb-btn-primary") as HTMLButtonElement;
        addBtn.type = "button";
        addBtn.appendChild(this.iconPlus());
        addBtn.appendChild(this.el("span", undefined, this.t("addBtn")));
        addBtn.disabled = !this.lookupField();
        addBtn.addEventListener("click", () => this.openPanel());
        actions.appendChild(addBtn);
        head.appendChild(actions);
        this.root.appendChild(head);

        // Body.
        if (this.status === "loading") {
            this.root.appendChild(this.el("div", "ppb-note", this.t("loading")));
            return;
        }
        if (this.status === "error") {
            this.root.appendChild(this.el("div", "ppb-note ppb-note-err", this.t("loadError")));
            return;
        }
        if (!this.accounts.length) {
            const empty = this.el("div", "ppb-empty");
            empty.appendChild(this.el("div", "ppb-empty-ic", "🏦"));
            empty.appendChild(this.el("div", "ppb-empty-title", this.t("emptyTitle")));
            empty.appendChild(this.el("div", "ppb-empty-body", this.t("emptyBody")));
            this.root.appendChild(empty);
            return;
        }

        const grid = this.el("div", "ppb-grid");
        this.accounts.forEach((a) => grid.appendChild(this.renderCard(a)));
        this.root.appendChild(grid);
    }

    private renderCard(a: BankAccount): HTMLElement {
        const card = this.el("div", "ppb-card ppb-card-click" + (a.isActive ? "" : " ppb-inactive"));
        card.setAttribute("role", "button");
        card.setAttribute("tabindex", "0");
        card.addEventListener("click", () => this.openReceipts(a));
        card.addEventListener("keydown", (e) => {
            const ke = e as KeyboardEvent;
            if (ke.key === "Enter" || ke.key === " ") { ke.preventDefault(); this.openReceipts(a); }
        });

        const top = this.el("div", "ppb-card-top");
        const logoWrap = this.el("div", "ppb-logo-wrap");
        if (a.bankCode) {
            const img = document.createElement("img");
            img.className = "ppb-bank-img";
            img.alt = a.bankName;
            img.src = this.logoUrl(a.bankCode);
            img.addEventListener("error", () => {
                img.remove();
                logoWrap.appendChild(this.el("div", "ppb-logo-fallback", this.initials(a.bankName)));
            });
            logoWrap.appendChild(img);
        } else {
            logoWrap.appendChild(this.el("div", "ppb-logo-fallback", this.initials(a.bankName)));
        }
        top.appendChild(logoWrap);

        const badges = this.el("div", "ppb-badges");
        if (a.isDefault) badges.appendChild(this.el("span", "ppb-badge ppb-badge-default", this.t("badgeDefault")));
        if (a.hasStandingOrder) {
            const b = this.el("span", "ppb-badge ppb-badge-standing");
            b.appendChild(this.iconRepeat());
            b.appendChild(this.el("span", undefined, this.t("badgeStanding")));
            badges.appendChild(b);
        }
        if (!a.isActive) badges.appendChild(this.el("span", "ppb-badge ppb-badge-off", this.t("badgeInactive")));
        top.appendChild(badges);
        card.appendChild(top);

        card.appendChild(this.el("div", "ppb-bankname", a.bankName || a.name || this.t("dash")));

        const acct = this.el("div", "ppb-acct");
        acct.appendChild(this.el("span", "ppb-acct-num", a.accountNumber || this.t("dash")));
        const branchTxt = a.branchCode && a.branchName
            ? `${this.t("lblBranch")} ${a.branchCode} · ${a.branchName}`
            : a.branchCode
                ? `${this.t("lblBranch")} ${a.branchCode}`
                : (a.branchName || "");
        if (branchTxt) acct.appendChild(this.el("span", "ppb-acct-branch", branchTxt));
        card.appendChild(acct);

        const holder = this.el("div", "ppb-holder");
        holder.appendChild(this.el("span", "ppb-holder-lbl", this.t("lblHolder")));
        holder.appendChild(this.el("span", "ppb-holder-val", a.holder || this.t("dash")));
        card.appendChild(holder);

        const foot = this.el("div", "ppb-card-foot");
        foot.appendChild(this.el("span", "ppb-card-foot-lbl", this.t("viewReceipts")));
        foot.appendChild(this.iconChevron());
        card.appendChild(foot);

        return card;
    }

    /* --------------------------------------------------------- add panel */

    private async openPanel(): Promise<void> {
        if (this.panelRoot) return;
        const lf = this.lookupField();
        if (!lf) return;

        const rootPane = this.el("div", "ppb-pane-root") as HTMLDivElement;
        rootPane.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
        const backdrop = this.el("div", "ppb-backdrop");
        backdrop.addEventListener("click", () => this.closePanel());
        rootPane.appendChild(backdrop);

        const drawer = this.el("div", "ppb-drawer");
        rootPane.appendChild(drawer);
        document.body.appendChild(rootPane);
        this.panelRoot = rootPane;
        document.addEventListener("keydown", this.panelKeyHandler, true);

        // Header.
        const head = this.el("div", "ppb-pane-head");
        const htitles = this.el("div");
        htitles.appendChild(this.el("div", "ppb-pane-title", this.t("panelTitle")));
        htitles.appendChild(this.el("div", "ppb-pane-sub", this.t("panelSub")));
        head.appendChild(htitles);
        const close = this.el("button", "ppb-pane-close") as HTMLButtonElement;
        close.type = "button";
        close.setAttribute("aria-label", this.t("close"));
        close.textContent = "✕";
        close.addEventListener("click", () => this.closePanel());
        head.appendChild(close);
        drawer.appendChild(head);

        // Body (form).
        const body = this.el("div", "ppb-pane-body");
        drawer.appendChild(body);

        // Bank picker.
        const bankSel = document.createElement("select");
        bankSel.className = "ppb-input";
        bankSel.appendChild(new Option(this.t("fBankPh"), ""));
        body.appendChild(this.field(this.t("fBank"), bankSel));

        // Branch picker + manual fallback.
        const branchSel = document.createElement("select");
        branchSel.className = "ppb-input";
        branchSel.disabled = true;
        branchSel.appendChild(new Option(this.t("fBranchPh"), ""));
        const branchManual = document.createElement("input");
        branchManual.className = "ppb-input";
        branchManual.type = "text";
        branchManual.inputMode = "numeric";
        branchManual.placeholder = this.t("fBranchManualPh");
        branchManual.style.display = "none";
        const branchField = this.field(this.t("fBranch"), branchSel);
        branchField.appendChild(branchManual);
        const manualToggle = this.el("button", "ppb-linkbtn", this.t("fBranchManualToggle")) as HTMLButtonElement;
        manualToggle.type = "button";
        let manualMode = false;
        manualToggle.addEventListener("click", () => {
            manualMode = !manualMode;
            branchSel.style.display = manualMode ? "none" : "";
            branchManual.style.display = manualMode ? "" : "none";
        });
        branchField.appendChild(manualToggle);
        body.appendChild(branchField);

        bankSel.addEventListener("change", () => {
            void this.fillBranches(bankSel.value, branchSel);
        });

        // Account number + holder.
        const acctInput = document.createElement("input");
        acctInput.className = "ppb-input";
        acctInput.type = "text";
        acctInput.inputMode = "numeric";
        acctInput.placeholder = this.t("fAccountNoPh");
        body.appendChild(this.field(this.t("fAccountNo"), acctInput));

        const holderInput = document.createElement("input");
        holderInput.className = "ppb-input";
        holderInput.type = "text";
        holderInput.placeholder = this.t("fHolderPh");
        body.appendChild(this.field(this.t("fHolder"), holderInput));

        // Default toggle.
        const defToggle = this.toggle(this.t("fDefault"));
        body.appendChild(defToggle.row);

        // Standing order toggle + conditional fields.
        const soToggle = this.toggle(this.t("fStanding"), this.t("fStandingHint"));
        body.appendChild(soToggle.row);

        const soExtra = this.el("div", "ppb-so-extra");
        soExtra.style.display = "none";
        const sinceInput = document.createElement("input");
        sinceInput.className = "ppb-input";
        sinceInput.type = "date";
        soExtra.appendChild(this.field(this.t("fStandingSince"), sinceInput));
        const refInput = document.createElement("input");
        refInput.className = "ppb-input";
        refInput.type = "text";
        refInput.placeholder = this.t("fStandingRefPh");
        soExtra.appendChild(this.field(this.t("fStandingRef"), refInput));
        body.appendChild(soExtra);
        soToggle.input.addEventListener("change", () => {
            soExtra.style.display = soToggle.input.checked ? "" : "none";
        });

        // Footer.
        const foot = this.el("div", "ppb-pane-foot");
        const cancelBtn = this.el("button", "ppb-btn ppb-btn-ghost", this.t("cancel")) as HTMLButtonElement;
        cancelBtn.type = "button";
        cancelBtn.addEventListener("click", () => this.closePanel());
        const saveBtn = this.el("button", "ppb-btn ppb-btn-primary", this.t("save")) as HTMLButtonElement;
        saveBtn.type = "button";
        saveBtn.addEventListener("click", () => {
            void this.save({
                pane: rootPane, saveBtn,
                bankSel, branchSel, branchManual, manual: () => manualMode,
                acctInput, holderInput,
                isDefault: defToggle.input, hasSo: soToggle.input, sinceInput, refInput,
            });
        });
        foot.appendChild(cancelBtn);
        foot.appendChild(saveBtn);
        drawer.appendChild(foot);

        // Animate in.
        requestAnimationFrame(() => rootPane.classList.add("ppb-open"));

        // Load banks (async, after the panel is visible).
        await this.ensureBanks();
        this.banks.forEach((b) => bankSel.appendChild(new Option(`${b.name}${b.code ? " (" + b.code + ")" : ""}`, b.id)));
    }

    private field(label: string, control: HTMLElement): HTMLElement {
        const f = this.el("label", "ppb-field");
        f.appendChild(this.el("span", "ppb-field-lbl", label));
        f.appendChild(control);
        return f;
    }

    private toggle(label: string, hint?: string): { row: HTMLElement; input: HTMLInputElement } {
        const row = this.el("label", "ppb-toggle-row");
        const texts = this.el("div", "ppb-toggle-texts");
        texts.appendChild(this.el("span", "ppb-toggle-lbl", label));
        if (hint) texts.appendChild(this.el("span", "ppb-toggle-hint", hint));
        row.appendChild(texts);
        const sw = this.el("span", "ppb-switch");
        const input = document.createElement("input");
        input.type = "checkbox";
        input.className = "ppb-switch-in";
        sw.appendChild(input);
        sw.appendChild(this.el("span", "ppb-switch-slider"));
        row.appendChild(sw);
        return { row, input };
    }

    private async ensureBanks(): Promise<void> {
        if (this.banks.length) return;
        try {
            const res = await this.context.webAPI.retrieveMultipleRecords(
                "alex_bank",
                "?$select=alex_bankid,alex_bankcode,alex_name&$orderby=alex_bankcode asc"
            );
            this.banks = res.entities.map((e) => ({
                id: String(e["alex_bankid"] || ""),
                code: String(e["alex_bankcode"] || ""),
                name: String(e["alex_name"] || ""),
            }));
        } catch { /* leave empty; manual branch entry still works */ }
    }

    private async fillBranches(bankId: string, sel: HTMLSelectElement): Promise<void> {
        sel.innerHTML = "";
        sel.appendChild(new Option(this.t("fBranchPh"), ""));
        sel.disabled = true;
        if (!bankId) return;
        let list = this.branchesByBank[bankId];
        if (!list) {
            try {
                const res = await this.context.webAPI.retrieveMultipleRecords(
                    "alex_bankbranch",
                    "?$select=alex_bankbranchid,alex_branchcode,alex_name&$filter=_alex_bankid_value eq " +
                    bankId + "&$orderby=alex_branchcode asc"
                );
                list = res.entities.map((e) => ({
                    id: String(e["alex_bankbranchid"] || ""),
                    code: String(e["alex_branchcode"] || ""),
                    name: String(e["alex_name"] || ""),
                    bankId,
                }));
                this.branchesByBank[bankId] = list;
            } catch { list = []; }
        }
        list.forEach((b) => sel.appendChild(new Option(`${b.code ? b.code + " · " : ""}${b.name}`, b.id)));
        sel.disabled = false;
    }

    private async save(f: {
        pane: HTMLDivElement; saveBtn: HTMLButtonElement;
        bankSel: HTMLSelectElement; branchSel: HTMLSelectElement; branchManual: HTMLInputElement;
        manual: () => boolean;
        acctInput: HTMLInputElement; holderInput: HTMLInputElement;
        isDefault: HTMLInputElement; hasSo: HTMLInputElement; sinceInput: HTMLInputElement; refInput: HTMLInputElement;
    }): Promise<void> {
        if (this.saving) return;
        const lf = this.lookupField();
        if (!lf) return;

        const bankId = f.bankSel.value;
        const acct = f.acctInput.value.trim();
        const holder = f.holderInput.value.trim();
        const manualMode = f.manual();
        const branchId = manualMode ? "" : f.branchSel.value;
        const branchManual = manualMode ? f.branchManual.value.trim() : "";

        if (!bankId) return this.toast(this.t("vBank"), "err", f.pane);
        if (!branchId && !branchManual) return this.toast(this.t("vBranch"), "err", f.pane);
        if (!acct) return this.toast(this.t("vAccountNo"), "err", f.pane);
        if (!holder) return this.toast(this.t("vHolder"), "err", f.pane);

        const bank = this.banks.find((b) => b.id === bankId);
        const namePieces = [bank ? bank.name : "", this.maskAccount(acct)].filter(Boolean);

        const rec: Record<string, unknown> = {
            "alex_name": namePieces.join(" ") || holder,
            "alex_accountnumber": acct,
            "alex_accountholdername": holder,
            "alex_isactive": true,
            "alex_isdefault": f.isDefault.checked,
            "alex_hasstandingorder": f.hasSo.checked,
            "alex_syncstatus": SYNC_PENDING,
            "alex_BankId@odata.bind": "/alex_banks(" + bankId + ")",
        };
        if (branchId) rec["alex_BranchId@odata.bind"] = "/alex_bankbranchs(" + branchId + ")";
        if (branchManual) rec["alex_name"] = (rec["alex_name"] as string) + " · " + branchManual;
        if (this.parentType === "contact") rec["alex_ContactId@odata.bind"] = "/contacts(" + this.parentId + ")";
        else rec["alex_AccountId@odata.bind"] = "/accounts(" + this.parentId + ")";
        if (f.hasSo.checked) {
            if (f.sinceInput.value) rec["alex_standingordersince"] = f.sinceInput.value;
            if (f.refInput.value.trim()) rec["alex_standingorderreference"] = f.refInput.value.trim();
        }

        this.saving = true;
        f.saveBtn.disabled = true;
        f.saveBtn.textContent = this.t("saving");
        try {
            await this.context.webAPI.createRecord("alex_customerbankaccount", rec);
            this.closePanel();
            this.toast(this.t("saved"), "ok");
            await this.load();
        } catch {
            this.saving = false;
            f.saveBtn.disabled = false;
            f.saveBtn.textContent = this.t("save");
            this.toast(this.t("saveError"), "err", f.pane);
        }
    }

    private closePanel(): void {
        if (!this.panelRoot) return;
        const pane = this.panelRoot;
        this.panelRoot = null;
        this.saving = false;
        document.removeEventListener("keydown", this.panelKeyHandler, true);
        pane.classList.remove("ppb-open");
        window.setTimeout(() => pane.remove(), 320);
    }

    /* ------------------------------------------------------ receipts pane */

    private openReceipts(a: BankAccount): void {
        if (this.recRoot) return;
        this.recAcctId = a.id;
        this.recStatus = "loading";
        this.recDocs = [];
        this.recView = "list";
        this.buildReceiptsShell(a);
        void this.loadReceipts(a);
    }

    private buildReceiptsShell(a: BankAccount): void {
        const root = this.el("div", "ppb-pane-root ppb-rec-root") as HTMLDivElement;
        root.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
        const backdrop = this.el("div", "ppb-backdrop");
        backdrop.addEventListener("click", () => this.closeReceipts());
        root.appendChild(backdrop);

        const drawer = this.el("div", "ppb-drawer ppb-rec-drawer");

        const head = this.el("div", "ppb-pane-head");
        const htitles = this.el("div");
        const title = this.el("div", "ppb-pane-title");
        title.appendChild(this.iconReceipt());
        title.appendChild(this.el("span", undefined, this.t("recTitle")));
        htitles.appendChild(title);
        htitles.appendChild(this.el("div", "ppb-pane-sub", this.t("recSub")));
        head.appendChild(htitles);
        const close = this.el("button", "ppb-pane-close") as HTMLButtonElement;
        close.type = "button";
        close.textContent = "✕";
        close.setAttribute("aria-label", this.t("close"));
        close.addEventListener("click", () => this.closeReceipts());
        head.appendChild(close);
        drawer.appendChild(head);

        const chip = this.el("div", "ppb-rec-chip");
        chip.appendChild(this.el("span", "ppb-rec-chip-bank", a.bankName || a.name || ""));
        chip.appendChild(this.el("span", "ppb-rec-chip-acct", a.accountNumber || ""));
        drawer.appendChild(chip);

        const body = this.el("div", "ppb-pane-body ppb-rec-body") as HTMLDivElement;
        drawer.appendChild(body);
        this.recBodyEl = body;

        root.appendChild(drawer);
        document.body.appendChild(root);
        this.recRoot = root;
        document.addEventListener("keydown", this.recKeyHandler, true);
        this.renderReceiptsBody();
        requestAnimationFrame(() => root.classList.add("ppb-open"));
    }

    private async loadReceipts(a: BankAccount): Promise<void> {
        if (!a.id) { this.recStatus = "ready"; this.renderReceiptsBody(); return; }
        try {
            // Step 1 — payment lines collected from this account that produced a receipt document.
            const lq =
                "?$select=_alex_receiptdocumentid_value" +
                "&$filter=_alex_customerbankaccountid_value eq " + a.id + " and _alex_receiptdocumentid_value ne null" +
                "&$orderby=createdon desc";
            const lines = await this.context.webAPI.retrieveMultipleRecords("alex_paypluspaymentline", lq);
            const ids: string[] = [];
            lines.entities.forEach((e) => {
                const v = ((e["_alex_receiptdocumentid_value"] as string) || "").replace(/[{}]/g, "").toLowerCase();
                if (v && ids.indexOf(v) < 0) ids.push(v);
            });
            if (this.recAcctId !== a.id) return; // pane switched/closed while loading
            if (!ids.length) { this.recDocs = []; this.recStatus = "ready"; this.renderReceiptsBody(); return; }

            // Step 2 — load the receipt / tax-invoice-receipt documents themselves.
            const filter = ids.map((id) => "alex_payplusdocumentid eq " + id).join(" or ");
            const dq =
                "?$select=alex_payplusdocumentid,alex_name,alex_documentnumber,alex_documenttypecode," +
                "alex_totalamount,alex_currencycode,alex_documentdate,alex_issuedon," +
                "alex_pdfurl,alex_documenturl,alex_businessstatus,createdon" +
                "&$filter=(" + filter + ")";
            const docs = await this.context.webAPI.retrieveMultipleRecords("alex_payplusdocument", dq);
            if (this.recAcctId !== a.id) return;
            this.recDocs = docs.entities.map((e) => this.parseDoc(e)).sort((x, y) => y.sortKey - x.sortKey);
            this.recStatus = "ready";
        } catch {
            if (this.recAcctId !== a.id) return;
            this.recStatus = "error";
        }
        this.renderReceiptsBody();
    }

    private parseDoc(e: ComponentFramework.WebApi.Entity): ReceiptDoc {
        const fv = (k: string): string => (e[k + "@OData.Community.Display.V1.FormattedValue"] as string) || "";
        const code = ((e["alex_documenttypecode"] as string) || "").toLowerCase();
        const amount = e["alex_totalamount"] != null ? Number(e["alex_totalamount"]) : 0;
        const currency = (e["alex_currencycode"] as string) || "ILS";
        const dateIso = (e["alex_documentdate"] as string) || (e["alex_issuedon"] as string) || (e["createdon"] as string) || "";
        return {
            id: ((e["alex_payplusdocumentid"] as string) || "").replace(/[{}]/g, ""),
            number: (e["alex_documentnumber"] as string) || "",
            typeCode: code,
            typeLabel: this.docTypeLabel(code),
            amount,
            amountText: fv("alex_totalamount") || this.formatMoney(amount, currency),
            currency,
            dateText: fv("alex_documentdate") || this.formatDate(dateIso),
            statusText: fv("alex_businessstatus"),
            pdfUrl: (e["alex_pdfurl"] as string) || "",
            docUrl: (e["alex_documenturl"] as string) || "",
            sortKey: dateIso ? new Date(dateIso).getTime() : 0,
        };
    }

    private docTypeLabel(code: string): string {
        const map: Record<string, [string, string]> = {
            inv_receipt: ["קבלה", "Receipt"],
            inv_tax_receipt: ["חשבונית מס קבלה", "Tax invoice receipt"],
            inv_tax: ["חשבונית מס", "Tax invoice"],
            inv_refund: ["חשבונית זיכוי", "Credit invoice"],
            inv_proforma: ["חשבונית עסקה", "Proforma invoice"],
        };
        const t = map[code];
        if (t) return this.isRtl ? t[0] : t[1];
        return code || this.t("dash");
    }

    private formatMoney(value: number, currency: string): string {
        try {
            return new Intl.NumberFormat(this.isRtl ? "he-IL" : "en-US", {
                style: "currency", currency: currency || "ILS", minimumFractionDigits: 2, maximumFractionDigits: 2,
            }).format(value || 0);
        } catch {
            return (value || 0).toFixed(2) + " " + (currency || "");
        }
    }

    private formatDate(iso: string): string {
        if (!iso) return this.t("dash");
        const d = new Date(iso);
        if (isNaN(d.getTime())) return this.t("dash");
        return d.toLocaleDateString(this.isRtl ? "he-IL" : "en-US", { day: "2-digit", month: "2-digit", year: "numeric" });
    }

    private renderReceiptsBody(): void {
        const body = this.recBodyEl;
        if (!body) return;
        body.innerHTML = "";

        if (this.recStatus === "loading") { body.appendChild(this.el("div", "ppb-note", this.t("recLoading"))); return; }
        if (this.recStatus === "error") { body.appendChild(this.el("div", "ppb-note ppb-note-err", this.t("recError"))); return; }
        if (!this.recDocs.length) {
            const empty = this.el("div", "ppb-empty");
            empty.appendChild(this.el("div", "ppb-empty-ic", "🧾"));
            empty.appendChild(this.el("div", "ppb-empty-title", this.t("recEmptyTitle")));
            empty.appendChild(this.el("div", "ppb-empty-body", this.t("recEmptyBody")));
            body.appendChild(empty);
            return;
        }

        const total = this.recDocs.reduce((s, d) => s + (d.amount || 0), 0);
        const cur = this.recDocs[0]?.currency || "ILS";
        const summary = this.el("div", "ppb-rec-summary");
        const it1 = this.el("div", "ppb-rec-sum-item");
        it1.appendChild(this.el("span", "ppb-rec-sum-k", this.t("recCount")));
        it1.appendChild(this.el("span", "ppb-rec-sum-v", String(this.recDocs.length)));
        const it2 = this.el("div", "ppb-rec-sum-item");
        it2.appendChild(this.el("span", "ppb-rec-sum-k", this.t("recTotal")));
        it2.appendChild(this.el("span", "ppb-rec-sum-v", this.formatMoney(total, cur)));
        summary.appendChild(it1);
        summary.appendChild(it2);
        body.appendChild(summary);

        const list = this.el("div", "ppb-rec-list");
        this.recDocs.forEach((d) => list.appendChild(this.buildReceiptRow(d)));
        body.appendChild(list);
    }

    private buildReceiptRow(d: ReceiptDoc): HTMLElement {
        const row = this.el("button", "ppb-rec-row") as HTMLButtonElement;
        row.type = "button";
        const ic = this.el("span", "ppb-rec-row-ic");
        ic.appendChild(this.iconReceipt());
        row.appendChild(ic);
        const main = this.el("div", "ppb-rec-row-main");
        main.appendChild(this.el("span", "ppb-rec-row-title", d.number ? d.typeLabel + " · " + d.number : d.typeLabel));
        const sub = [d.dateText, d.statusText].filter(Boolean).join(" · ");
        main.appendChild(this.el("span", "ppb-rec-row-sub", sub || this.t("dash")));
        row.appendChild(main);
        row.appendChild(this.el("span", "ppb-rec-row-amt", d.amountText));
        const chev = this.el("span", "ppb-rec-row-chev");
        chev.appendChild(this.iconChevron());
        row.appendChild(chev);
        row.addEventListener("click", () => this.showReceiptDetail(d));
        return row;
    }

    private showReceiptDetail(d: ReceiptDoc): void {
        this.recView = "detail";
        this.recRoot?.querySelector(".ppb-rec-drawer")?.classList.add("ppb-rec-expanded");
        this.renderReceiptDetail(d);
    }

    private showReceiptList(): void {
        this.recView = "list";
        this.recRoot?.querySelector(".ppb-rec-drawer")?.classList.remove("ppb-rec-expanded");
        this.renderReceiptsBody();
    }

    private renderReceiptDetail(d: ReceiptDoc): void {
        const body = this.recBodyEl;
        if (!body) return;
        body.innerHTML = "";
        // Only http(s) URLs are embeddable; guard against javascript:/data: etc.
        const raw = d.pdfUrl || d.docUrl;
        const url = /^https?:\/\//i.test(raw) ? raw : "";
        const title = d.number ? d.typeLabel + " · " + d.number : d.typeLabel;

        const bar = this.el("div", "ppb-rec-detail-bar");
        const back = this.el("button", "ppb-rec-back") as HTMLButtonElement;
        back.type = "button";
        back.appendChild(this.iconBack());
        back.appendChild(this.el("span", undefined, this.t("recBack")));
        back.addEventListener("click", () => this.showReceiptList());
        bar.appendChild(back);
        bar.appendChild(this.el("div", "ppb-rec-detail-title", title));
        if (url) {
            const ext = this.el("button", "ppb-rec-iconbtn") as HTMLButtonElement;
            ext.type = "button";
            ext.title = this.t("recOpenExternal");
            ext.appendChild(this.iconExternal());
            ext.addEventListener("click", () => { try { this.context.navigation.openUrl(url); } catch { /* ignore */ } });
            bar.appendChild(ext);
        }
        body.appendChild(bar);

        if (url) {
            const wrap = this.el("div", "ppb-rec-frame-wrap");
            const iframe = document.createElement("iframe");
            iframe.className = "ppb-rec-frame";
            iframe.src = url;
            iframe.title = title;
            wrap.appendChild(iframe);
            body.appendChild(wrap);
        } else {
            const empty = this.el("div", "ppb-rec-detail-empty");
            empty.appendChild(this.iconReceipt());
            empty.appendChild(this.el("span", undefined, this.t("recNoPdf")));
            body.appendChild(empty);
        }
    }

    private closeReceipts(): void {
        if (!this.recRoot) return;
        const root = this.recRoot;
        this.recRoot = null;
        this.recBodyEl = null;
        this.recAcctId = "";
        document.removeEventListener("keydown", this.recKeyHandler, true);
        root.classList.remove("ppb-open");
        window.setTimeout(() => root.remove(), 320);
    }

    /* ---------------------------------------------------------------- toast */

    private toast(message: string, kind: "ok" | "err", host?: HTMLElement): void {
        const parent = host || document.body;
        const t = this.el("div", "ppb-toast ppb-toast-" + kind);
        t.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
        t.appendChild(this.el("span", "ppb-toast-msg", message));
        parent.appendChild(t);
        requestAnimationFrame(() => t.classList.add("ppb-toast-in"));
        window.setTimeout(() => {
            t.classList.remove("ppb-toast-in");
            window.setTimeout(() => t.remove(), 260);
        }, 3200);
    }

    /* ---------------------------------------------------------------- icons */

    private svg(path: string, extra?: string): SVGElement {
        const ns = "http://www.w3.org/2000/svg";
        const s = document.createElementNS(ns, "svg");
        s.setAttribute("viewBox", "0 0 24 24");
        s.setAttribute("class", "pp-ic" + (extra ? " " + extra : ""));
        s.setAttribute("aria-hidden", "true");
        const p = document.createElementNS(ns, "path");
        p.setAttribute("d", path);
        p.setAttribute("fill", "currentColor");
        s.appendChild(p);
        return s;
    }

    private iconPlus(): SVGElement {
        return this.svg("M11 5h2v6h6v2h-6v6h-2v-6H5v-2h6V5z");
    }

    private iconRepeat(): SVGElement {
        return this.svg("M7 7h9V4l4 4-4 4V9H9v3H7V7zm10 10H8v3l-4-4 4-4v3h7v-3h2v5z");
    }

    private iconReceipt(): SVGElement {
        return this.svg("M6 2h12v20l-3-2-3 2-3-2-3 2V2zm3 5h6v2H9V7zm0 4h6v2H9v-2z");
    }

    private iconChevron(): SVGElement {
        return this.svg("M9.29 6.71a1 1 0 0 0 0 1.41L13.17 12l-3.88 3.88a1 1 0 1 0 1.41 1.41l4.59-4.59a1 1 0 0 0 0-1.41L10.7 6.71a1 1 0 0 0-1.41 0z", "ppb-ic-dir");
    }

    private iconBack(): SVGElement {
        return this.svg("M14.71 6.71a1 1 0 0 0-1.41 0l-4.59 4.59a1 1 0 0 0 0 1.41l4.59 4.59a1 1 0 0 0 1.41-1.41L10.83 12l3.88-3.88a1 1 0 0 0 0-1.41z", "ppb-ic-dir");
    }

    private iconExternal(): SVGElement {
        return this.svg("M14 3h7v7h-2V6.4l-8.3 8.3-1.4-1.4L17.6 5H14V3zM5 5h5v2H7v10h10v-3h2v5H5V5z");
    }
}
