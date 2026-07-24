import { IInputs, IOutputs } from "./generated/ManifestTypes";

/* Shape we access from the model-driven page context (typed loosely on purpose). */
interface ContextInfo {
    entityId: string;
    entityTypeName: string;
    entityRecordName: string;
}

/* A parsed credit-card row ready for rendering. */
interface WalletCard {
    id: string;
    display: string;
    last4: string;
    holder: string;
    expMonth: string;
    expYear: string;
    isActive: boolean;
    isDefault: boolean;
    channelValue: number | null;
    channelLabel: string;
    modifiedOn: string;
    modifiedByName: string;
    custUid: string;
}

/* A receipt / tax-invoice-receipt document that was settled with a given card. */
interface ReceiptDoc {
    id: string;
    number: string;
    name: string;
    typeCode: string;
    typeLabel: string;
    amount: number;
    amountText: string;
    currency: string;
    dateText: string;
    statusText: string;
    pdfUrl: string;
    docUrl: string;
    copyUrl: string;
    sortKey: number;
}

/* Minimal Xrm shim for opening a document record / preview page from the side pane. */
interface XrmNavLike {
    Navigation?: {
        navigateTo?: (pageInput: unknown, navigationOptions?: unknown) => unknown;
    };
}

/* Existing DocumentPreview custom page (preview + quick actions), reused when opening a receipt. */
const PREVIEW_CUSTOM_PAGE_NAME = "alex_payplusdocumentpreview_b4f29";

/* Document action-request choice values (mirrors DocumentPreview / the action-request Flow). */
const REQUESTED_ACTION_SEND = 100000000;
const REQUESTED_ACTION_STATUS_PENDING = 100000000;
const REQUESTED_LINK_TYPE_COPY = 100000001;
const REQUESTED_LINK_TYPE_ORIGINAL = 100000000;
const REQUESTED_CHANNEL: Record<SendChannel, number> = { email: 100000000, sms: 100000001, whatsapp: 100000002 };
const DOC_BUSINESS_STATUS_ACTION_REQUESTED = 100000004;

/* Per-document-type send permissions resolved from alex_payplusconfiguration billing policy. */
type SendChannel = "email" | "sms" | "whatsapp";
interface SendConfig { email: boolean; sms: boolean; whatsapp: boolean; }

/* Minimal primaryControl shim so we can reuse the tested global PayPlus ribbon logic. */
interface PayPlusApi {
    openCardPane: (pc: unknown) => void;
    sendSelfService: (pc: unknown, channel: string) => void;
}

export class CreditCardWallet implements ComponentFramework.StandardControl<IInputs, IOutputs> {
    private context!: ComponentFramework.Context<IInputs>;
    private root!: HTMLDivElement;
    private isRtl = false;
    private parentId = "";
    private parentType = "";
    private cards: WalletCard[] = [];
    private status: "loading" | "ready" | "error" = "loading";
    private prevLoading = false;
    private menuOpen = false;
    private reloadTimers: number[] = [];
    private ppScriptPromise: Promise<void> | null = null;
    private outsideHandler = (e: MouseEvent): void => this.onOutsideClick(e);

    // Receipts side pane (Apple-style drawer) — shows documents settled with one card.
    private paneRoot: HTMLDivElement | null = null;
    private paneBodyEl: HTMLDivElement | null = null;
    private paneCardId = "";
    private paneStatus: "loading" | "ready" | "error" = "loading";
    private paneDocs: ReceiptDoc[] = [];
    private paneView: "list" | "detail" = "list";
    private paneDetailDoc: ReceiptDoc | null = null;
    private sendConfigCache: Record<string, SendConfig> = {};
    private paneKeyHandler = (e: KeyboardEvent): void => {
        if (e.key !== "Escape") return;
        if (this.paneView === "detail") this.showReceiptList();
        else this.closePane();
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
        this.root.className = "pp-wallet";
        this.root.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
        container.appendChild(this.root);

        document.addEventListener("click", this.outsideHandler, true);

        this.resolveParent();
        this.render();
        void this.load();
    }

    public updateView(context: ComponentFramework.Context<IInputs>): void {
        this.context = context;
        // Reload when the bound subgrid finishes a refresh (e.g. a card was added elsewhere).
        const ds = context.parameters.wallet;
        const loading = !!ds && ds.loading;
        if (this.prevLoading && !loading) {
            void this.load();
        }
        this.prevLoading = loading;

        // Reload if the host record changed.
        const prevId = this.parentId;
        this.resolveParent();
        if (this.parentId && this.parentId !== prevId) {
            void this.load();
        }
    }

    public getOutputs(): IOutputs {
        return {};
    }

    public destroy(): void {
        document.removeEventListener("click", this.outsideHandler, true);
        document.removeEventListener("keydown", this.paneKeyHandler, true);
        this.reloadTimers.forEach((t) => window.clearTimeout(t));
        if (this.paneRoot) { this.paneRoot.remove(); this.paneRoot = null; this.paneBodyEl = null; }
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
        if (this.parentType === "contact") return "_alex_contact_value";
        if (this.parentType === "account") return "_alex_account_value";
        return null;
    }

    private async load(): Promise<void> {
        const lf = this.lookupField();
        if (!this.parentId || !lf) {
            this.cards = [];
            this.status = "ready";
            this.render();
            return;
        }
        this.status = this.cards.length ? "ready" : "loading";
        this.render();

        const select =
            "$select=alex_name,alex_last4,alex_cardholdername,alex_expirymonth,alex_expiryyear," +
            "alex_isactive,alex_isdefault,alex_channel,alex_paypluscustomeruid,modifiedon,_modifiedby_value";
        const query =
            "?" + select +
            "&$filter=" + lf + " eq " + this.parentId +
            "&$orderby=alex_isactive desc,alex_isdefault desc,modifiedon desc";

        try {
            const res = await this.context.webAPI.retrieveMultipleRecords("alex_creditcard", query);
            this.cards = res.entities.map((e) => this.parseCard(e));
            this.status = "ready";
        } catch {
            this.status = "error";
        }
        this.render();
    }

    private parseCard(e: ComponentFramework.WebApi.Entity): WalletCard {
        const fv = (k: string): string => (e[k + "@OData.Community.Display.V1.FormattedValue"] as string) || "";
        return {
            id: (e["alex_creditcardid"] as string) || "",
            display: (e["alex_name"] as string) || "",
            last4: ((e["alex_last4"] as string) || "").toString().replace(/\D/g, "").slice(-4),
            holder: (e["alex_cardholdername"] as string) || "",
            expMonth: ((e["alex_expirymonth"] as string) || "").toString().replace(/\D/g, "").slice(0, 2),
            expYear: ((e["alex_expiryyear"] as string) || "").toString().replace(/\D/g, "").slice(-2),
            isActive: e["alex_isactive"] === true,
            isDefault: e["alex_isdefault"] === true,
            channelValue: e["alex_channel"] != null ? Number(e["alex_channel"]) : null,
            channelLabel: fv("alex_channel"),
            modifiedOn: fv("modifiedon"),
            modifiedByName: fv("_modifiedby_value"),
            custUid: (e["alex_paypluscustomeruid"] as string) || ""
        };
    }

    /* --------------------------------------------------------------- render */

    private s(key: string): string {
        return this.context.resources.getString(key) || key;
    }

    private esc(v: string): string {
        return (v || "").replace(/[&<>"']/g, (c) =>
            ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string)
        );
    }

    private render(): void {
        this.root.innerHTML = "";
        this.root.appendChild(this.buildHeader());

        const body = document.createElement("div");
        if (this.status === "loading") {
            body.appendChild(this.stateEl("spinner", this.s("loading"), ""));
        } else if (this.status === "error") {
            body.appendChild(this.stateEl("alert", this.s("loadError"), ""));
        } else if (this.cards.length === 0) {
            body.appendChild(this.stateEl("wallet", this.s("emptyTitle"), this.s("emptyBody")));
        } else {
            const grid = document.createElement("div");
            grid.className = "pp-grid";
            this.cards.forEach((c, i) => grid.appendChild(this.buildCard(c, i)));
            body.appendChild(grid);
        }
        this.root.appendChild(body);
    }

    private buildHeader(): HTMLElement {
        const head = document.createElement("div");
        head.className = "pp-head";

        const count = this.cards.length;
        const noun = count === 1 ? this.s("cardOne") : this.s("cardsSuffix");
        head.innerHTML =
            '<div class="pp-head-titles">' +
                '<div class="pp-title"><span class="pp-logo">P</span>' + this.esc(this.s("title")) + "</div>" +
                '<div class="pp-sub">' + this.esc(this.s("subtitle")) +
                    (this.status === "ready" && count ? ' &middot; <span class="pp-count">' + count + " " + this.esc(noun) + "</span>" : "") +
                "</div>" +
            "</div>";

        const actions = document.createElement("div");
        actions.className = "pp-actions";

        const manual = document.createElement("button");
        manual.className = "pp-btn pp-btn-primary";
        manual.type = "button";
        manual.innerHTML = this.icon("pencil") + "<span>" + this.esc(this.s("addManual")) + "</span>";
        manual.addEventListener("click", (ev) => { ev.stopPropagation(); void this.doManual(); });

        const ss = document.createElement("button");
        ss.className = "pp-btn pp-btn-ghost";
        ss.type = "button";
        ss.innerHTML = this.icon("send") + "<span>" + this.esc(this.s("selfService")) + "</span>" + this.caret();
        ss.addEventListener("click", (ev) => { ev.stopPropagation(); this.toggleMenu(); });

        const menu = this.buildMenu();

        actions.appendChild(manual);
        actions.appendChild(ss);
        actions.appendChild(menu);
        head.appendChild(actions);
        return head;
    }

    private buildMenu(): HTMLElement {
        const menu = document.createElement("div");
        menu.className = "pp-menu" + (this.menuOpen ? " pp-open" : "");
        const channels: [string, string, string][] = [
            ["email", "chEmail", "email"],
            ["sms", "chSms", "sms"],
            ["whatsapp", "chWhatsapp", "whatsapp"]
        ];
        channels.forEach(([icon, labelKey, ch]) => {
            const item = document.createElement("button");
            item.className = "pp-menu-item";
            item.type = "button";
            item.innerHTML = this.icon(icon) + "<span>" + this.esc(this.s(labelKey)) + "</span>";
            item.addEventListener("click", (ev) => { ev.stopPropagation(); this.closeMenu(); void this.doSelfService(ch); });
            menu.appendChild(item);
        });
        return menu;
    }

    private buildCard(c: WalletCard, index: number): HTMLElement {
        const cell = document.createElement("div");
        cell.className = "pp-cell";

        const gradient = "pp-g" + (this.gradientFor(c, index));
        const card = document.createElement("div");
        card.className = "pp-card " + (c.isActive ? "" : "pp-inactive");
        card.setAttribute("role", "button");
        card.setAttribute("tabindex", "0");
        card.setAttribute("aria-label", this.s("flipHint"));

        const badges: string[] = [];
        if (c.isDefault) badges.push('<span class="pp-badge pp-badge-default">' + this.icon("star") + this.esc(this.s("badgeDefault")) + "</span>");
        badges.push(c.isActive
            ? '<span class="pp-badge pp-badge-active" role="button" tabindex="0" data-act="deactivate" title="' + this.esc(this.s("deactivateHint")) + '">' + this.esc(this.s("badgeActive")) + "</span>"
            : '<span class="pp-badge pp-badge-inactive" role="button" tabindex="0" data-act="reactivate" title="' + this.esc(this.s("reactivateHint")) + '">' + this.esc(this.s("badgeInactive")) + "</span>");
        badges.push('<span class="pp-badge pp-badge-details" role="button" tabindex="0" data-details="1" title="' + this.esc(this.s("detailsHint")) + '">' + this.icon("receipt") + this.esc(this.s("detailsBtn")) + "</span>");

        const last4 = c.last4 || "----";
        const exp = c.expMonth && c.expYear ? c.expMonth + "/" + c.expYear : this.s("dash");
        const holder = c.holder ? this.esc(c.holder) : this.s("dash");

        const front =
            '<div class="pp-face pp-front ' + gradient + '">' +
                '<div class="pp-card-top">' +
                    '<span class="pp-brandmark">PayPlus</span>' +
                    '<span class="pp-badges">' + badges.join("") + "</span>" +
                "</div>" +
                '<div class="pp-chip" aria-hidden="true"></div>' +
                '<div class="pp-number"><span class="pp-dots">&bull;&bull;&bull;&bull; &bull;&bull;&bull;&bull; &bull;&bull;&bull;&bull;</span>' + this.esc(last4) + "</div>" +
                '<div class="pp-card-bottom">' +
                    '<div class="pp-field pp-holder"><span class="pp-k">' + this.esc(this.s("lblCardholder")) + '</span><span class="pp-v">' + holder + "</span></div>" +
                    '<div class="pp-field pp-exp"><span class="pp-k">' + this.esc(this.s("lblExpires")) + '</span><span class="pp-v">' + this.esc(exp) + "</span></div>" +
                "</div>" +
                '<span class="pp-flip-hint">' + this.icon("flip") + "</span>" +
            "</div>";

        card.innerHTML = front + this.buildBack(c, gradient);

        const flip = (): void => { card.classList.toggle("pp-flipped"); };
        card.addEventListener("click", flip);
        card.addEventListener("keydown", (ev: KeyboardEvent) => {
            if (ev.key === "Enter" || ev.key === " ") { ev.preventDefault(); flip(); }
        });

        // The status badge doubles as an activate / deactivate button.
        const actBtn = card.querySelector("[data-act]") as HTMLElement | null;
        if (actBtn) {
            const run = (): void => {
                if (actBtn.getAttribute("data-act") === "deactivate") { void this.deactivateCard(c); }
                else { void this.reactivateCard(c); }
            };
            actBtn.addEventListener("click", (ev: Event) => {
                ev.stopPropagation();
                run();
            });
            actBtn.addEventListener("keydown", (ev: KeyboardEvent) => {
                if (ev.key === "Enter" || ev.key === " ") {
                    ev.preventDefault();
                    ev.stopPropagation();
                    run();
                }
            });
        }

        // The "Details" badge opens the receipts side pane without flipping the card.
        const detailsBtn = card.querySelector("[data-details]") as HTMLElement | null;
        if (detailsBtn) {
            detailsBtn.addEventListener("click", (ev: Event) => { ev.stopPropagation(); this.openPane(c); });
            detailsBtn.addEventListener("keydown", (ev: KeyboardEvent) => {
                if (ev.key === "Enter" || ev.key === " ") { ev.preventDefault(); ev.stopPropagation(); this.openPane(c); }
            });
        }

        cell.appendChild(card);
        cell.appendChild(this.buildMeta(c));
        return cell;
    }

    private buildBack(c: WalletCard, gradient: string): string {
        const dash = this.s("dash");
        const exp = c.expMonth && c.expYear ? c.expMonth + "/" + c.expYear : dash;
        const isSelfService = c.channelValue === 100000001 || c.channelValue === 100000002 || c.channelValue === 100000003;
        const who = isSelfService ? this.s("srcCustomer") : (c.modifiedByName || this.s("srcAgent"));
        const status = c.isActive ? this.s("badgeActive") : this.s("badgeInactive");
        const channel = c.channelLabel || dash;

        const row = (label: string, value: string): string =>
            '<div class="pp-brow"><span class="pp-bk">' + this.esc(label) + '</span>' +
            '<span class="pp-bv">' + this.esc(value || dash) + "</span></div>";

        return (
            '<div class="pp-face pp-back ' + gradient + '">' +
                '<div class="pp-back-head">' + this.icon("wallet") + "<span>" + this.esc(this.s("backTitle")) + "</span></div>" +
                '<div class="pp-back-rows">' +
                    row(this.s("lblCardholder"), c.holder) +
                    row(this.s("lblExpires"), exp) +
                    row(this.s("lblStatus"), status) +
                    row(this.s("lblChannel"), channel) +
                    row(this.s("lblBy"), who) +
                    row(this.s("lblUpdated"), c.modifiedOn) +
                "</div>" +
                '<span class="pp-flip-hint">' + this.icon("flip") + "</span>" +
            "</div>"
        );
    }

    private async deactivateCard(c: WalletCard): Promise<void> {
        if (!c.isActive) return;
        const res = await this.context.navigation.openConfirmDialog({
            title: this.s("deactivateTitle"),
            text: this.s("deactivateText"),
            confirmButtonLabel: this.s("deactivateConfirm"),
            cancelButtonLabel: this.s("cancel")
        });
        if (!res || !res.confirmed) return;
        try {
            await this.context.webAPI.updateRecord("alex_creditcard", c.id, {
                alex_isactive: false,
                alex_isdefault: false
            });
            await this.load();
        } catch (err) {
            void this.context.navigation.openErrorDialog({
                message: err instanceof Error ? err.message : String(err)
            });
        }
    }

    private async reactivateCard(c: WalletCard): Promise<void> {
        if (c.isActive) return;
        const res = await this.context.navigation.openConfirmDialog({
            title: this.s("reactivateTitle"),
            text: this.s("reactivateText"),
            confirmButtonLabel: this.s("reactivateConfirm"),
            cancelButtonLabel: this.s("cancel")
        });
        if (!res || !res.confirmed) return;
        try {
            await this.context.webAPI.updateRecord("alex_creditcard", c.id, {
                alex_isactive: true
            });
            await this.load();
        } catch (err) {
            void this.context.navigation.openErrorDialog({
                message: err instanceof Error ? err.message : String(err)
            });
        }
    }

    private buildMeta(c: WalletCard): HTMLElement {
        const meta = document.createElement("div");
        meta.className = "pp-meta";

        const parts: string[] = [];
        // channel
        if (c.channelLabel) {
            const chIcon = c.channelValue === 100000001 ? "email"
                : c.channelValue === 100000002 ? "sms"
                : c.channelValue === 100000003 ? "whatsapp"
                : "pencil";
            parts.push('<span class="pp-tag">' + this.icon(chIcon) + this.esc(c.channelLabel) + "</span>");
        }
        // who updated — real user name for agent/manual, "customer" for self-service
        const isSelfService = c.channelValue === 100000001 || c.channelValue === 100000002 || c.channelValue === 100000003;
        const who = isSelfService ? this.s("srcCustomer") : (c.modifiedByName || this.s("srcAgent"));
        parts.push('<span class="pp-tag">' + this.icon(isSelfService ? "person" : "agent") + this.esc(who) + "</span>");
        // updated-on
        if (c.modifiedOn) {
            parts.push('<span class="pp-updated">' + this.icon("clock") + " " + this.esc(this.s("lblUpdated")) + " " + this.esc(c.modifiedOn) + "</span>");
        }
        meta.innerHTML = parts.join("");
        return meta;
    }

    private stateEl(icon: string, title: string, body: string): HTMLElement {
        const el = document.createElement("div");
        el.className = "pp-state";
        const head = icon === "spinner"
            ? '<div class="pp-spinner"></div>'
            : '<span class="pp-state-ic">' + this.icon(icon) + "</span>";
        el.innerHTML = head +
            '<div class="pp-state-title">' + this.esc(title) + "</div>" +
            (body ? '<div class="pp-state-body">' + this.esc(body) + "</div>" : "");
        return el;
    }

    /* --------------------------------------------------------------- actions */

    private getPayPlus(): PayPlusApi | null {
        const wins: (Window | null)[] = [window, window.parent];
        for (const w of wins) {
            try {
                const api = w && (w as unknown as { PayPlus?: PayPlusApi }).PayPlus;
                if (api && typeof api.openCardPane === "function") return api;
            } catch { /* cross-window guard */ }
        }
        return null;
    }

    /* Ensure the global Xrm is reachable on this window, borrowing from the parent if needed. */
    private ensureXrm(): void {
        const w = window as unknown as { Xrm?: unknown };
        if (w.Xrm) return;
        try {
            const p = window.parent as unknown as { Xrm?: unknown };
            if (p && p.Xrm) w.Xrm = p.Xrm;
        } catch { /* cross-window guard */ }
    }

    /* Load the shared PayPlus ribbon web resource so its globals become available. */
    private loadPayPlusScript(): Promise<void> {
        if (this.ppScriptPromise) return this.ppScriptPromise;
        this.ppScriptPromise = new Promise<void>((resolve, reject) => {
            const existing = document.querySelector('script[data-payplus-lib="1"]');
            if (existing) { resolve(); return; }
            let base = "";
            try {
                const xrm = (window as unknown as {
                    Xrm?: { Utility?: { getGlobalContext?: () => { getClientUrl?: () => string } } };
                }).Xrm;
                base = xrm?.Utility?.getGlobalContext?.().getClientUrl?.() || "";
            } catch { /* ignore */ }
            const s = document.createElement("script");
            // eslint-disable-next-line @microsoft/power-apps/use-cached-webresource
            s.src = base + "/WebResources/alex_payplus_opencardpane.js";
            s.async = true;
            s.setAttribute("data-payplus-lib", "1");
            s.onload = (): void => resolve();
            s.onerror = (): void => reject(new Error("payplus script load failed"));
            document.head.appendChild(s);
        });
        return this.ppScriptPromise;
    }

    private async ensurePayPlus(): Promise<PayPlusApi | null> {
        this.ensureXrm();
        let pp = this.getPayPlus();
        if (pp) return pp;
        try { await this.loadPayPlusScript(); } catch { return null; }
        pp = this.getPayPlus();
        return pp;
    }

    private primaryControlShim(): unknown {
        const id = this.parentId;
        const etn = this.parentType;
        return {
            data: { entity: { getId: () => id, getEntityName: () => etn, attributes: { get: () => null } } },
            ui: { refreshRibbon: () => { /* no-op */ } }
        };
    }

    private scheduleReload(): void {
        [2000, 6000].forEach((ms) => {
            this.reloadTimers.push(window.setTimeout(() => void this.load(), ms));
        });
    }

    private async doManual(): Promise<void> {
        const pp = await this.ensurePayPlus();
        if (!pp) { this.notifyMissing(); return; }
        pp.openCardPane(this.primaryControlShim());
        this.scheduleReload();
    }

    private async doSelfService(channel: string): Promise<void> {
        const pp = await this.ensurePayPlus();
        if (!pp) { this.notifyMissing(); return; }
        pp.sendSelfService(this.primaryControlShim(), channel);
        this.scheduleReload();
    }

    private notifyMissing(): void {
        void this.context.navigation.openAlertDialog({
            text: this.isRtl
                ? "\u05E4\u05E2\u05D5\u05DC\u05D5\u05EA \u05D4\u05DB\u05E8\u05D8\u05D9\u05E1 \u05D0\u05D9\u05E0\u05DF \u05D6\u05DE\u05D9\u05E0\u05D5\u05EA \u05D1\u05D8\u05D5\u05E4\u05E1 \u05D6\u05D4."
                : "Card actions are unavailable on this form. Use the Credit Cards command-bar button."
        });
    }

    /* ----------------------------------------------------------------- menu */

    private toggleMenu(): void { this.menuOpen = !this.menuOpen; this.render(); }
    private closeMenu(): void { if (this.menuOpen) { this.menuOpen = false; this.render(); } }
    private onOutsideClick(e: MouseEvent): void {
        if (!this.menuOpen) return;
        if (!this.root.contains(e.target as Node)) this.closeMenu();
    }

    /* ------------------------------------------------------ receipts pane */

    private openPane(c: WalletCard): void {
        this.paneCardId = c.id;
        this.paneStatus = "loading";
        this.paneDocs = [];
        this.paneView = "list";
        this.paneDetailDoc = null;
        this.buildPaneShell(c);
        void this.loadReceipts(c);
    }

    private async loadReceipts(c: WalletCard): Promise<void> {
        if (!c.id) { this.paneStatus = "ready"; this.renderPaneBody(); return; }
        try {
            // Step 1 — payment lines charged to this card that produced a receipt document.
            const lq =
                "?$select=_alex_receiptdocumentid_value" +
                "&$filter=_alex_creditcardid_value eq " + c.id + " and _alex_receiptdocumentid_value ne null" +
                "&$orderby=createdon desc";
            const lines = await this.context.webAPI.retrieveMultipleRecords("alex_paypluspaymentline", lq);
            const ids: string[] = [];
            lines.entities.forEach((e) => {
                const v = ((e["_alex_receiptdocumentid_value"] as string) || "").replace(/[{}]/g, "").toLowerCase();
                if (v && ids.indexOf(v) < 0) ids.push(v);
            });
            if (this.paneCardId !== c.id) return; // pane switched/closed while loading
            if (!ids.length) { this.paneDocs = []; this.paneStatus = "ready"; this.renderPaneBody(); return; }

            // Step 2 — load the receipt / tax-invoice-receipt documents themselves.
            const filter = ids.map((id) => "alex_payplusdocumentid eq " + id).join(" or ");
            const dq =
                "?$select=alex_payplusdocumentid,alex_name,alex_documentnumber,alex_documenttypecode," +
                "alex_totalamount,alex_paidamount,alex_currencycode,alex_documentdate,alex_issuedon," +
                "alex_pdfurl,alex_documenturl,alex_copypdfurl,alex_businessstatus,createdon" +
                "&$filter=(" + filter + ")";
            const docs = await this.context.webAPI.retrieveMultipleRecords("alex_payplusdocument", dq);
            if (this.paneCardId !== c.id) return;
            this.paneDocs = docs.entities.map((e) => this.parseDoc(e)).sort((a, b) => b.sortKey - a.sortKey);
            this.paneStatus = "ready";
        } catch {
            if (this.paneCardId !== c.id) return;
            this.paneStatus = "error";
        }
        this.renderPaneBody();
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
            name: (e["alex_name"] as string) || "",
            typeCode: code,
            typeLabel: this.docTypeLabel(code),
            amount,
            amountText: fv("alex_totalamount") || this.formatMoney(amount, currency),
            currency,
            dateText: fv("alex_documentdate") || this.formatDate(dateIso),
            statusText: fv("alex_businessstatus"),
            pdfUrl: (e["alex_pdfurl"] as string) || "",
            docUrl: (e["alex_documenturl"] as string) || "",
            copyUrl: (e["alex_copypdfurl"] as string) || "",
            sortKey: dateIso ? new Date(dateIso).getTime() : 0
        };
    }

    private docTypeLabel(code: string): string {
        const map: Record<string, [string, string]> = {
            inv_receipt: ["קבלה", "Receipt"],
            inv_tax_receipt: ["חשבונית מס קבלה", "Tax invoice receipt"],
            inv_tax: ["חשבונית מס", "Tax invoice"],
            inv_refund: ["חשבונית זיכוי", "Credit invoice"],
            inv_proforma: ["חשבונית עסקה", "Proforma invoice"]
        };
        const t = map[code];
        if (t) return this.isRtl ? t[0] : t[1];
        return code || this.s("dash");
    }

    private formatMoney(value: number, currency: string): string {
        try {
            return new Intl.NumberFormat(this.isRtl ? "he-IL" : "en-US", {
                style: "currency", currency: currency || "ILS", minimumFractionDigits: 2, maximumFractionDigits: 2
            }).format(value || 0);
        } catch {
            return (value || 0).toFixed(2) + " " + (currency || "");
        }
    }

    private formatDate(iso: string): string {
        if (!iso) return this.s("dash");
        const d = new Date(iso);
        if (isNaN(d.getTime())) return this.s("dash");
        return d.toLocaleDateString(this.isRtl ? "he-IL" : "en-US", { day: "2-digit", month: "2-digit", year: "numeric" });
    }

    private buildPaneShell(c: WalletCard): void {
        if (!this.paneRoot) {
            this.paneRoot = document.createElement("div");
            this.paneRoot.className = "ppw-pane-root";
            this.paneRoot.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
            document.body.appendChild(this.paneRoot);
            document.addEventListener("keydown", this.paneKeyHandler, true);
        }

        const last4 = c.last4 || "----";
        const holder = c.holder ? this.esc(c.holder) : this.s("dash");
        const exp = c.expMonth && c.expYear ? c.expMonth + "/" + c.expYear : this.s("dash");

        this.paneRoot.innerHTML =
            '<div class="ppw-backdrop"></div>' +
            '<aside class="ppw-drawer" role="dialog" aria-modal="true">' +
                '<header class="ppw-head">' +
                    '<div class="ppw-head-row">' +
                        '<div class="ppw-head-titles">' +
                            '<div class="ppw-title">' + this.icon("receipt") + "<span>" + this.esc(this.s("paneTitle")) + "</span></div>" +
                            '<div class="ppw-sub">' + this.esc(this.s("paneSub")) + "</div>" +
                        "</div>" +
                        '<button class="ppw-close" type="button" aria-label="' + this.esc(this.s("paneClose")) + '">' + this.icon("close") + "</button>" +
                    "</div>" +
                    '<div class="ppw-cardchip">' +
                        '<span class="ppw-cardchip-brand">PayPlus</span>' +
                        '<span class="ppw-cardchip-num">&bull;&bull;&bull;&bull; ' + this.esc(last4) + "</span>" +
                        '<span class="ppw-cardchip-meta">' + holder + " &middot; " + this.esc(exp) + "</span>" +
                    "</div>" +
                "</header>" +
                '<div class="ppw-body"></div>' +
            "</aside>";

        this.paneBodyEl = this.paneRoot.querySelector(".ppw-body") as HTMLDivElement;

        const backdrop = this.paneRoot.querySelector(".ppw-backdrop") as HTMLElement;
        backdrop.addEventListener("click", () => this.closePane());
        const close = this.paneRoot.querySelector(".ppw-close") as HTMLElement;
        close.addEventListener("click", () => this.closePane());

        this.renderPaneBody();
        // trigger the slide-in transition on the next frame
        window.requestAnimationFrame(() => this.paneRoot && this.paneRoot.classList.add("ppw-open"));
    }

    private renderPaneBody(): void {
        const body = this.paneBodyEl;
        if (!body) return;
        body.innerHTML = "";

        if (this.paneStatus === "loading") {
            body.appendChild(this.paneState("spinner", this.s("paneLoading"), ""));
            return;
        }
        if (this.paneStatus === "error") {
            body.appendChild(this.paneState("alert", this.s("paneError"), ""));
            return;
        }
        if (!this.paneDocs.length) {
            body.appendChild(this.paneState("receipt", this.s("paneEmptyTitle"), this.s("paneEmptyBody")));
            return;
        }

        // summary strip: count + total settled
        const total = this.paneDocs.reduce((s, d) => s + (d.amount || 0), 0);
        const cur = this.paneDocs[0]?.currency || "ILS";
        const summary = document.createElement("div");
        summary.className = "ppw-summary";
        summary.innerHTML =
            '<div class="ppw-sum-item"><span class="ppw-sum-k">' + this.esc(this.s("paneCount")) + '</span><span class="ppw-sum-v">' + this.paneDocs.length + "</span></div>" +
            '<div class="ppw-sum-item"><span class="ppw-sum-k">' + this.esc(this.s("paneTotal")) + '</span><span class="ppw-sum-v">' + this.esc(this.formatMoney(total, cur)) + "</span></div>";
        body.appendChild(summary);

        const list = document.createElement("div");
        list.className = "ppw-list";
        this.paneDocs.forEach((d) => list.appendChild(this.buildReceiptRow(d)));
        body.appendChild(list);
    }

    private buildReceiptRow(d: ReceiptDoc): HTMLElement {
        const row = document.createElement("button");
        row.className = "ppw-row";
        row.type = "button";
        const title = d.number ? d.typeLabel + " · " + d.number : d.typeLabel;
        const subParts = [d.dateText, d.statusText].filter(Boolean).join(" · ");
        row.innerHTML =
            '<span class="ppw-row-ic">' + this.icon(d.typeCode === "inv_refund" ? "credit" : "receipt") + "</span>" +
            '<span class="ppw-row-main">' +
                '<span class="ppw-row-title">' + this.esc(title) + "</span>" +
                '<span class="ppw-row-sub">' + this.esc(subParts || this.s("dash")) + "</span>" +
            "</span>" +
            '<span class="ppw-row-amt">' + this.esc(d.amountText) + "</span>" +
            '<span class="ppw-row-chev">' + this.icon("chev") + "</span>";
        row.addEventListener("click", () => this.showReceiptDetail(d));
        return row;
    }

    /* Expand the drawer and render the receipt inline (Apple-style master → detail). */
    private showReceiptDetail(d: ReceiptDoc): void {
        this.paneView = "detail";
        this.paneDetailDoc = d;
        const drawer = this.paneRoot?.querySelector(".ppw-drawer");
        if (drawer) drawer.classList.add("ppw-expanded");
        this.renderPaneDetail(d);
    }

    /* Collapse back to the receipts list. */
    private showReceiptList(): void {
        this.paneView = "list";
        this.paneDetailDoc = null;
        const drawer = this.paneRoot?.querySelector(".ppw-drawer");
        if (drawer) drawer.classList.remove("ppw-expanded");
        this.renderPaneBody();
    }

    private renderPaneDetail(d: ReceiptDoc): void {
        const body = this.paneBodyEl;
        if (!body) return;
        // Only http(s) URLs are embeddable; guard against javascript:/data: etc.
        const raw = d.pdfUrl || d.docUrl;
        const url = /^https?:\/\//i.test(raw) ? raw : "";
        const title = d.number ? d.typeLabel + " · " + d.number : d.typeLabel;

        const wrap = document.createElement("div");
        wrap.className = "ppw-detail";
        wrap.innerHTML =
            '<div class="ppw-detail-bar">' +
                '<button class="ppw-back" type="button">' + this.icon("back") + "<span>" + this.esc(this.s("paneBack")) + "</span></button>" +
                '<div class="ppw-detail-title">' + this.esc(title) + "</div>" +
                '<div class="ppw-detail-acts">' +
                    '<span class="ppw-send-slot"></span>' +
                    (url ? '<button class="ppw-iconbtn" data-ext type="button" title="' + this.esc(this.s("paneOpenExternal")) + '">' + this.icon("external") + "</button>" : "") +
                "</div>" +
            "</div>" +
            (url
                ? '<div class="ppw-frame-wrap"><iframe class="ppw-frame" src="' + this.esc(url) + '" title="' + this.esc(title) + '"></iframe></div>'
                : '<div class="ppw-detail-empty">' + this.icon("receipt") + "<span>" + this.esc(this.s("paneNoPdf")) + "</span></div>");

        body.innerHTML = "";
        body.appendChild(wrap);

        (wrap.querySelector(".ppw-back") as HTMLElement | null)?.addEventListener("click", () => this.showReceiptList());
        (wrap.querySelector("[data-ext]") as HTMLElement | null)?.addEventListener("click", () => {
            if (url) { try { this.context.navigation.openUrl(url); } catch { /* ignore */ } }
        });

        // Send buttons appear only for channels enabled in the billing config for this doc type.
        void this.renderSendButtons(d, wrap.querySelector(".ppw-send-slot") as HTMLElement | null);
    }

    private async renderSendButtons(d: ReceiptDoc, slot: HTMLElement | null): Promise<void> {
        if (!slot) return;
        const cfg = await this.loadSendConfig(d.typeCode);
        // Guard: the pane may have changed (back/close/other receipt) while awaiting.
        if (this.paneView !== "detail" || this.paneDetailDoc?.id !== d.id || !slot.isConnected) return;

        const channels: SendChannel[] = [];
        if (cfg.email) channels.push("email");
        if (cfg.sms) channels.push("sms");
        if (cfg.whatsapp) channels.push("whatsapp");
        if (!channels.length) return;

        const labelKey: Record<SendChannel, string> = { email: "chEmail", sms: "chSms", whatsapp: "chWhatsapp" };
        slot.innerHTML = channels.map((ch) =>
            '<button class="ppw-sendbtn" type="button" data-send="' + ch + '" title="' + this.esc(this.s("sendLabel")) + '">' +
                this.icon(ch) + "<span>" + this.esc(this.s(labelKey[ch])) + "</span>" +
            "</button>"
        ).join("");

        slot.querySelectorAll("[data-send]").forEach((el) => {
            el.addEventListener("click", () => {
                const ch = (el as HTMLElement).getAttribute("data-send") as SendChannel;
                void this.requestReceiptSend(d, ch, el as HTMLButtonElement);
            });
        });
    }

    /* Billing-policy prefix per document type (mirrors DocumentPreview.invoiceBillingPrefix). */
    private billingPrefixFor(typeCode: string): string {
        switch ((typeCode || "").toLowerCase()) {
            case "inv_tax": return "alex_billing_doc_taxinvoice_";
            case "inv_tax_receipt": return "alex_billing_doc_taxinvoicereceipt_";
            case "inv_proforma": return "alex_billing_doc_paymentdemand_";
            case "inv_pay_request": return "alex_billing_doc_paymentrequest_";
            case "inv_receipt": return "alex_billing_doc_receipt_";
            case "inv_refund": return "alex_billing_doc_credit_";
            default: return "";
        }
    }

    private async loadSendConfig(typeCode: string): Promise<SendConfig> {
        const key = (typeCode || "").toLowerCase();
        if (this.sendConfigCache[key]) return this.sendConfigCache[key];
        const empty: SendConfig = { email: false, sms: false, whatsapp: false };
        const prefix = this.billingPrefixFor(key);
        if (!prefix) { this.sendConfigCache[key] = empty; return empty; }
        try {
            const sel = [
                prefix + "enabled",
                prefix + "send_email_allowed",
                prefix + "send_sms_allowed",
                prefix + "send_whatsapp_allowed"
            ].join(",");
            const res = await this.context.webAPI.retrieveMultipleRecords(
                "alex_payplusconfiguration", "?$select=" + sel + "&$top=1"
            );
            const c = (res.entities && res.entities[0]) || {};
            const enabled = c[prefix + "enabled"] === true;
            const cfg: SendConfig = {
                email: enabled && c[prefix + "send_email_allowed"] === true,
                sms: enabled && c[prefix + "send_sms_allowed"] === true,
                whatsapp: enabled && c[prefix + "send_whatsapp_allowed"] === true
            };
            this.sendConfigCache[key] = cfg;
            return cfg;
        } catch {
            this.sendConfigCache[key] = empty;
            return empty;
        }
    }

    private async requestReceiptSend(d: ReceiptDoc, channel: SendChannel, btn?: HTMLButtonElement): Promise<void> {
        if (!d.id) return;
        if (btn) { btn.disabled = true; btn.classList.add("ppw-sending"); }
        // Prefer the copy link if available (billing-policy default), else the original PDF.
        const linkType = d.copyUrl ? REQUESTED_LINK_TYPE_COPY : REQUESTED_LINK_TYPE_ORIGINAL;
        const link = d.copyUrl || d.pdfUrl || d.docUrl || "";
        const userSettings = this.context.userSettings as unknown as { userId?: string; userName?: string };
        const patch = {
            alex_requestedaction: REQUESTED_ACTION_SEND,
            alex_requestedchannel: REQUESTED_CHANNEL[channel],
            alex_requestedlinktype: linkType,
            alex_requestedactionstatus: REQUESTED_ACTION_STATUS_PENDING,
            alex_businessstatus: DOC_BUSINESS_STATUS_ACTION_REQUESTED,
            alex_requestedactionon: new Date().toISOString(),
            alex_requestedactionby: userSettings.userName || userSettings.userId || "",
            alex_requestedactionmessage: JSON.stringify({ source: "PayPlus.CreditCardWallet", action: "send", channel, linkType: d.copyUrl ? "copy" : "original", link })
        };
        try {
            await this.context.webAPI.updateRecord("alex_payplusdocument", d.id, patch);
            this.showPaneToast(this.s("sendDone"), "ok");
        } catch (err) {
            this.showPaneToast(err instanceof Error ? err.message : String(err), "err");
        } finally {
            if (btn) { btn.disabled = false; btn.classList.remove("ppw-sending"); }
        }
    }

    /* In-drawer toast — the platform's alert/error dialogs render below our body-level
       drawer (lower z-index) and would be hidden, so we show feedback inside the pane. */
    private showPaneToast(message: string, kind: "ok" | "err"): void {
        const root = this.paneRoot;
        if (!root) return;
        root.querySelector(".ppw-toast")?.remove();
        const toast = document.createElement("div");
        toast.className = "ppw-toast ppw-toast-" + kind;
        toast.setAttribute("role", "status");
        toast.innerHTML = '<span class="ppw-toast-ic">' + this.icon(kind === "ok" ? "send" : "alert") + "</span>" +
            "<span>" + this.esc(message) + "</span>";
        root.appendChild(toast);
        requestAnimationFrame(() => toast.classList.add("ppw-toast-in"));
        window.setTimeout(() => {
            toast.classList.remove("ppw-toast-in");
            window.setTimeout(() => toast.remove(), 260);
        }, 3200);
    }

    private openReceipt(d: ReceiptDoc): void {
        // Preferred: open the existing DocumentPreview custom page (preview + quick actions).
        const xrm = this.getXrm();
        const nav = xrm?.Navigation;
        if (nav && typeof nav.navigateTo === "function" && d.id) {
            const title = d.number || d.name || d.typeLabel;
            try {
                const res = nav.navigateTo(
                    { pageType: "custom", name: PREVIEW_CUSTOM_PAGE_NAME, entityName: "alex_payplusdocument", recordId: d.id },
                    { target: 2, position: 1, width: { value: 82, unit: "%" }, height: { value: 86, unit: "%" }, title }
                ) as { catch?: (cb: (e?: unknown) => void) => void } | undefined;
                if (res && typeof res.catch === "function") res.catch(() => this.openReceiptFallback(d));
                return;
            } catch {
                this.openReceiptFallback(d);
                return;
            }
        }
        this.openReceiptFallback(d);
    }

    private openReceiptFallback(d: ReceiptDoc): void {
        const url = d.pdfUrl || d.docUrl;
        if (url) { try { this.context.navigation.openUrl(url); return; } catch { /* ignore */ } }
        const xrm = this.getXrm();
        const nav = xrm?.Navigation;
        if (nav && typeof nav.navigateTo === "function" && d.id) {
            try {
                nav.navigateTo(
                    { pageType: "entityrecord", entityName: "alex_payplusdocument", entityId: d.id },
                    { target: 2, position: 1, width: { value: 82, unit: "%" }, height: { value: 86, unit: "%" } }
                );
            } catch { /* nothing else to do */ }
        }
    }

    private getXrm(): XrmNavLike | null {
        for (const candidate of [window, window.parent] as (Window | null)[]) {
            try {
                const xrm = (candidate as unknown as { Xrm?: XrmNavLike }).Xrm;
                if (xrm) return xrm;
            } catch { /* cross-origin guard */ }
        }
        return null;
    }

    private paneState(icon: string, title: string, body: string): HTMLElement {
        const el = document.createElement("div");
        el.className = "ppw-state";
        const head = icon === "spinner"
            ? '<div class="ppw-spinner"></div>'
            : '<span class="ppw-state-ic">' + this.icon(icon) + "</span>";
        el.innerHTML = head +
            '<div class="ppw-state-title">' + this.esc(title) + "</div>" +
            (body ? '<div class="ppw-state-body">' + this.esc(body) + "</div>" : "");
        return el;
    }

    private closePane(): void {
        if (!this.paneRoot) return;
        const el = this.paneRoot;
        el.classList.remove("ppw-open");
        document.removeEventListener("keydown", this.paneKeyHandler, true);
        this.paneRoot = null;
        this.paneBodyEl = null;
        this.paneCardId = "";
        this.paneView = "list";
        this.paneDetailDoc = null;
        window.setTimeout(() => el.remove(), 280);
    }

    /* --------------------------------------------------------------- helpers */

    private gradientFor(c: WalletCard, index: number): number {
        const key = c.id || String(index);
        let h = 0;
        for (let i = 0; i < key.length; i++) {
            h = (Math.imul(h, 31) + key.charCodeAt(i)) >>> 0;
        }
        return h % 8;
    }

    private caret(): string {
        return '<svg class="pp-caret" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M3 4.5 6 7.5 9 4.5"/></svg>';
    }

    private icon(name: string): string {
        const p: Record<string, string> = {
            pencil: '<path d="M14.06 4.94 19 9.88 8.88 20H4v-4.88L14.06 4.94Z" fill="currentColor"/>',
            send: '<path d="M3 11l18-8-8 18-2.5-7L3 11Z" fill="currentColor"/>',
            email: '<path d="M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Zm0 3.2V18h16V8.2l-8 5-8-5Z" fill="currentColor"/>',
            sms: '<path d="M4 3h16a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H8l-5 4V4a1 1 0 0 1 1-1Zm3 6h2v2H7V9Zm4 0h2v2h-2V9Zm4 0h2v2h-2V9Z" fill="currentColor"/>',
            whatsapp: '<path d="M12 2a10 10 0 0 0-8.6 15l-1.3 4.7L7 20.4A10 10 0 1 0 12 2Zm5.3 13.7c-.2.6-1.3 1.2-1.8 1.2-.5.1-1 .1-1.7-.1a11 11 0 0 1-5.3-4.6c-.4-.6-.9-1.5-.9-2.3 0-.8.4-1.2.6-1.4a.7.7 0 0 1 .5-.2h.4c.2 0 .3 0 .5.4l.7 1.6c0 .2.1.3 0 .5l-.3.4-.3.3c-.1.2-.3.3-.1.6.2.3.8 1.3 1.7 2 1.1.9 2 1.2 2.3 1.3.2.1.4.1.5-.1l.6-.8c.2-.2.3-.2.6-.1l1.6.7c.3.2.4.2.5.4.1.2.1.5 0 1.1Z" fill="currentColor"/>',
            star: '<path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 17.9 6.8 19.6l1-5.8L3.5 9.7l5.9-.9L12 3.5Z" fill="currentColor"/>',
            agent: '<path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm0 2c-3.3 0-8 1.7-8 5v1h16v-1c0-3.3-4.7-5-8-5Zm7-9a1 1 0 0 1 1 1v2a1 1 0 0 1-2 0V6a1 1 0 0 1 1-1Z" fill="currentColor"/>',
            person: '<path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm0 2c-3.3 0-8 1.7-8 5v1h16v-1c0-3.3-4.7-5-8-5Z" fill="currentColor"/>',
            clock: '<path d="M12 3a9 9 0 1 0 9 9 9 9 0 0 0-9-9Zm1 9V7h-2v6h5v-2h-3Z" fill="currentColor"/>',
            wallet: '<path d="M4 6h14a2 2 0 0 1 2 2v1h-3a3 3 0 0 0 0 6h3v1a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Zm13 5a1.5 1.5 0 1 0 0 3h4v-3h-4Z" fill="currentColor"/>',
            flip: '<path d="M12 5V2L8 6l4 4V7a5 5 0 0 1 5 5h2a7 7 0 0 0-7-7Zm0 14v3l4-4-4-4v3a5 5 0 0 1-5-5H5a7 7 0 0 0 7 7Z" fill="currentColor"/>',
            alert: '<path d="M12 2 1 21h22L12 2Zm1 14h-2v2h2v-2Zm0-6h-2v4h2v-4Z" fill="currentColor"/>',
            receipt: '<path d="M6 2h12a1 1 0 0 1 1 1v18l-2.5-1.5L14 21l-2-1.5L10 21l-2.5-1.5L5 21V3a1 1 0 0 1 1-1Zm2 5v2h8V7H8Zm0 4v2h8v-2H8Zm0 4v2h5v-2H8Z" fill="currentColor"/>',
            credit: '<path d="M6 2h12a1 1 0 0 1 1 1v18l-2.5-1.5L14 21l-2-1.5L10 21l-2.5-1.5L5 21V3a1 1 0 0 1 1-1Zm2 8v2h8v-2H8Z" fill="currentColor"/>',
            close: '<path d="M6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12 19 6.4 17.6 5 12 10.6 6.4 5Z" fill="currentColor"/>',
            chev: '<path d="M9 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
            back: '<path d="M15 6l-6 6 6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
            external: '<path d="M14 4h6v6h-2V7.4l-8.3 8.3-1.4-1.4L16.6 6H14V4ZM5 5h5v2H6v11h11v-4h2v6H4V6a1 1 0 0 1 1-1Z" fill="currentColor"/>',
            expand: '<path d="M4 4h7v2H6v5H4V4Zm16 0v7h-2V6h-5V4h7ZM4 13h2v5h5v2H4v-7Zm16 0v7h-7v-2h5v-5h2Z" fill="currentColor"/>'
        };
        const path = p[name] || "";
        return '<svg class="pp-ic" viewBox="0 0 24 24" width="16" height="16" fill="none" xmlns="http://www.w3.org/2000/svg">' + path + "</svg>";
    }
}
