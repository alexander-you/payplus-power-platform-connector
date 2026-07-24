import { IInputs, IOutputs } from "./generated/ManifestTypes";

interface ContextInfo {
    entityId?: string;
    entityTypeName?: string;
}

interface PayPlusDocument {
    alex_name?: string;
    alex_uniqueidentifier?: string;
    alex_sourceentitylogicalname?: string;
    alex_sourceentityid?: string;
    _alex_quoteid_value?: string;
    alex_payplusdocumentuuid?: string;
    alex_documentnumber?: string;
    alex_series?: string;
    alex_documenttypecode?: string;
    alex_documentstatus?: string;
    alex_lastoperation?: string;
    alex_lastsyncstatus?: number;
    alex_payplusresultstatus?: string;
    alex_payplusresultdescription?: string;
    alex_customername?: string;
    alex_totalamount?: number;
    alex_currencycode?: string;
    alex_documenturl?: string;
    alex_pdfurl?: string;
    alex_copypdfurl?: string;
    alex_rawdocumentjson?: string;
    alex_moreinfo?: string;
}

interface ResendConfig {
    loaded: boolean;
    email: boolean;
    sms: boolean;
    whatsapp: boolean;
    originalAllowed: boolean;
    copyAllowed: boolean;
    defaultLinkType: LinkType;
}

type LoadState = "loading" | "ready" | "waiting" | "error";
type LinkType = "original" | "copy";
type SendChannel = "email" | "sms" | "whatsapp";
type DocumentAction = "cancel" | "close";

const SELECT_FIELDS = [
    "alex_name",
    "alex_uniqueidentifier",
    "alex_sourceentitylogicalname",
    "alex_sourceentityid",
    "_alex_quoteid_value",
    "alex_payplusdocumentuuid",
    "alex_documentnumber",
    "alex_series",
    "alex_documenttypecode",
    "alex_documentstatus",
    "alex_lastoperation",
    "alex_lastsyncstatus",
    "alex_payplusresultstatus",
    "alex_payplusresultdescription",
    "alex_customername",
    "alex_totalamount",
    "alex_currencycode",
    "alex_documenturl",
    "alex_pdfurl",
    "alex_copypdfurl",
    "alex_rawdocumentjson",
    "alex_moreinfo"
].join(",");

const REQUESTED_ACTION = {
    send: 100000000,
    cancel: 100000001,
    close: 100000002
};

const REQUESTED_CHANNEL: Record<SendChannel, number> = {
    email: 100000000,
    sms: 100000001,
    whatsapp: 100000002
};

const REQUESTED_LINK_TYPE: Record<LinkType, number> = {
    original: 100000000,
    copy: 100000001
};

const REQUESTED_ACTION_STATUS = {
    pending: 100000000
};

export class DocumentPreview implements ComponentFramework.StandardControl<IInputs, IOutputs> {
    private context!: ComponentFramework.Context<IInputs>;
    private root!: HTMLDivElement;
    private recordId = "";
    private hostValue = "";
    private documentIdInput = "";
    private isRtl = false;
    private state: LoadState = "loading";
    private errorText = "";
    private document: PayPlusDocument | null = null;
    private pollHandle = 0;
    private loadToken = 0;
    private activateQuoteAfterIssuePending = false;
    private activateQuoteDialogOpen = false;
    private selectedViewLinkType: LinkType = "copy";
    private selectedSendLinkType: LinkType = "copy";
    private selectedSendChannel: SendChannel = "email";
    private selectedDocumentAction: DocumentAction = "cancel";
    private resendConfig: ResendConfig = { loaded: false, email: false, sms: false, whatsapp: false, originalAllowed: true, copyAllowed: true, defaultLinkType: "copy" };
    private resendConfigKey = "";

    public init(
        context: ComponentFramework.Context<IInputs>,
        _notifyOutputChanged: () => void,
        _state: ComponentFramework.Dictionary,
        container: HTMLDivElement
    ): void {
        this.context = context;
        this.hostValue = context.parameters.hostValue.raw || "";
        this.documentIdInput = context.parameters.documentId.raw || "";
        this.isRtl = this.detectRtl(context);
        context.mode.trackContainerResize(true);

        this.root = document.createElement("div");
        this.root.className = "ppdp";
        this.root.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
        container.appendChild(this.root);

        this.resolveRecordId();
        this.render();
        void this.loadDocument(true);
    }

    public updateView(context: ComponentFramework.Context<IInputs>): void {
        this.context = context;
        this.hostValue = context.parameters.hostValue.raw || this.hostValue;
        this.documentIdInput = context.parameters.documentId.raw || "";
        const nextIsRtl = this.detectRtl(context);
        if (nextIsRtl !== this.isRtl) {
            this.isRtl = nextIsRtl;
            this.root.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
            this.render();
        }
        const previous = this.recordId;
        this.resolveRecordId();
        if (this.recordId !== previous) {
            this.clearPoll();
            this.activateQuoteAfterIssuePending = false;
            this.activateQuoteDialogOpen = false;
            this.resendConfig = this.emptyResendConfig(false);
            this.resendConfigKey = "";
            void this.loadDocument(true);
        }
    }

    public getOutputs(): IOutputs {
        return { hostValue: this.hostValue };
    }

    public destroy(): void {
        this.clearPoll();
        this.root.replaceChildren();
    }

    private resolveRecordId(): void {
        const modeInfo = (this.context.mode as unknown as { contextInfo?: ContextInfo }).contextInfo;
        const pageInfo = (this.context as unknown as { page?: ContextInfo }).page;
        this.recordId = (this.documentIdInput || modeInfo?.entityId || pageInfo?.entityId || "").replace(/[{}]/g, "").toLowerCase();
    }

    private detectRtl(context: ComponentFramework.Context<IInputs>): boolean {
        const userSettings = context.userSettings as unknown as { languageId?: number; isRTL?: boolean; isRtl?: boolean };
        if (userSettings.languageId === 1037 || userSettings.isRTL === true || userSettings.isRtl === true) return true;

        const hostLanguageId = this.hostLanguageId();
        if (hostLanguageId === 1037) return true;

        const lang = (document.documentElement.lang || "").toLowerCase();
        const dir = (document.documentElement.dir || document.body.dir || "").toLowerCase();
        const href = window.location.href.toLowerCase();
        const referrer = document.referrer.toLowerCase();
        if (dir === "rtl" || lang.startsWith("he") || href.indexOf("locale=he") >= 0 || referrer.indexOf("locale=he") >= 0) return true;

        return (navigator.languages || [navigator.language]).some((language) => (language || "").toLowerCase().startsWith("he"));
    }

    private hostLanguageId(): number | null {
        const candidates: (Window | null)[] = [window, window.parent];
        for (const candidate of candidates) {
            try {
                const xrm = (candidate as unknown as { Xrm?: { Utility?: { getGlobalContext?: () => { userSettings?: { languageId?: number } } } } }).Xrm;
                const languageId = xrm?.Utility?.getGlobalContext?.().userSettings?.languageId;
                if (typeof languageId === "number") return languageId;
            } catch {
                // Cross-origin frames are expected in custom pages.
            }
        }
        return null;
    }

    private async loadDocument(showLoading: boolean): Promise<void> {
        if (!this.recordId) {
            this.state = "waiting";
            this.document = null;
            this.render();
            return;
        }

        const token = ++this.loadToken;
        if (showLoading) {
            this.state = "loading";
            this.errorText = "";
            this.render();
        }

        try {
            if (!this.context.webAPI?.retrieveRecord) {
                throw new Error(this.t("webApiUnavailable"));
            }
            const row = await this.context.webAPI.retrieveRecord("alex_payplusdocument", this.recordId, `?$select=${SELECT_FIELDS}`) as PayPlusDocument;
            if (token !== this.loadToken) return;
            this.document = row;
            await this.loadResendConfig(row);
            this.normalizeSelections(row);
            this.errorText = "";
            this.state = this.previewUrl(row) || this.previewHtml(row) || this.isFailed(row) ? "ready" : "waiting";
            if (this.activateQuoteAfterIssuePending && this.isFailed(row)) this.activateQuoteAfterIssuePending = false;
            const shouldAskActivation = this.shouldAskActivateQuoteAfterIssue(row);
            this.render();
            this.schedulePollIfNeeded();
            if (shouldAskActivation) void this.askActivateQuoteAfterIssue(row);
        } catch (error) {
            if (token !== this.loadToken) return;
            this.document = null;
            this.state = "error";
            this.errorText = error instanceof Error ? error.message : String(error);
            this.render();
        }
    }

    private schedulePollIfNeeded(): void {
        this.clearPoll();
        if (!this.document || this.state !== "waiting") return;
        this.pollHandle = window.setTimeout(() => {
            void this.loadDocument(false);
        }, 4000);
    }

    private clearPoll(): void {
        if (this.pollHandle) {
            window.clearTimeout(this.pollHandle);
            this.pollHandle = 0;
        }
    }

    private emptyResendConfig(loaded: boolean): ResendConfig {
        return { loaded: loaded, email: false, sms: false, whatsapp: false, originalAllowed: true, copyAllowed: true, defaultLinkType: "copy" };
    }

    private resendConfigDocumentKey(row: PayPlusDocument): "quote" | "invoice" | "salesorder" | "" {
        const docType = (row.alex_documenttypecode || "").toLowerCase();
        const sourceEntity = (row.alex_sourceentitylogicalname || "").toLowerCase();
        if (docType === "dc_quote" || sourceEntity === "quote") return "quote";
        if (docType === "purchase" || sourceEntity === "salesorder") return "salesorder";
        if (docType.indexOf("inv_") === 0 || sourceEntity === "invoice") return "invoice";
        return "";
    }

    private invoiceBillingPrefix(row: PayPlusDocument): string {
        const docType = (row.alex_documenttypecode || "").toLowerCase();
        if (docType === "inv_tax") return "alex_billing_doc_taxinvoice_";
        if (docType === "inv_tax_receipt") return "alex_billing_doc_taxinvoicereceipt_";
        if (docType === "inv_proforma") return "alex_billing_doc_paymentdemand_";
        if (docType === "inv_pay_request") return "alex_billing_doc_paymentrequest_";
        if (docType === "inv_receipt") return "alex_billing_doc_receipt_";
        if (docType === "inv_refund") return "alex_billing_doc_credit_";
        return "";
    }

    private boolValue(configuration: Record<string, boolean | number | undefined>, fieldName: string): boolean {
        return configuration[fieldName] === true;
    }

    private isQuoteDocument(row: PayPlusDocument | null): boolean {
        if (!row) return false;
        return this.resendConfigDocumentKey(row) === "quote";
    }

    private issueTextForDocument(row: PayPlusDocument | null): string {
        if (!row) return this.t("issueText");
        const docType = (row.alex_documenttypecode || "").toLowerCase();
        const documentKey = this.resendConfigDocumentKey(row);
        if (this.isRtl) {
            if (documentKey === "salesorder") return "המסמך יופק ב-PayPlus על בסיס נתוני ההזמנה השמורים. האם לאשר הפקה?";
            if (documentKey === "invoice") {
                if (docType === "inv_tax") return "חשבונית המס תופק ב-PayPlus על בסיס נתוני החשבונית השמורים ב-Dynamics 365. האם לאשר הפקה?";
                if (docType === "inv_proforma") return "חשבונית העסקה תופק ב-PayPlus על בסיס נתוני החשבונית השמורים ב-Dynamics 365. האם לאשר הפקה?";
                if (docType === "inv_pay_request") return "בקשת התשלום תופק ב-PayPlus על בסיס נתוני החשבונית השמורים ב-Dynamics 365. האם לאשר הפקה?";
                return "המסמך יופק ב-PayPlus על בסיס נתוני החשבונית השמורים ב-Dynamics 365. האם לאשר הפקה?";
            }
        } else {
            if (documentKey === "salesorder") return "The document will be issued in PayPlus using the saved Sales Order data. Continue?";
            if (documentKey === "invoice") {
                if (docType === "inv_tax") return "The tax invoice will be issued in PayPlus using the saved Dynamics 365 invoice data. Continue?";
                if (docType === "inv_proforma") return "The proforma invoice will be issued in PayPlus using the saved Dynamics 365 invoice data. Continue?";
                if (docType === "inv_pay_request") return "The payment request will be issued in PayPlus using the saved Dynamics 365 invoice data. Continue?";
                return "The document will be issued in PayPlus using the saved Dynamics 365 invoice data. Continue?";
            }
        }
        return this.t("issueText");
    }

    private async loadResendConfig(row: PayPlusDocument): Promise<void> {
        const documentKey = this.resendConfigDocumentKey(row);
        const billingPrefix = this.invoiceBillingPrefix(row);
        const configKey = `${documentKey}:${billingPrefix}`;
        if (this.resendConfig.loaded && this.resendConfigKey === configKey) return;
        if (!documentKey) {
            this.resendConfig = this.emptyResendConfig(true);
            this.resendConfigKey = configKey;
            return;
        }

        const useBillingPolicy = documentKey === "invoice" && !!billingPrefix;
        const documentPrefix = `alex_doc_${documentKey}_resend_`;

        // Select only the configuration fields that actually exist for this document type.
        // Invoice documents are governed by the billing policy fields (alex_billing_doc_*);
        // quotes and sales orders use their own resend fields (alex_doc_<key>_resend_*).
        const selectFields: string[] = [];
        if (useBillingPolicy) {
            selectFields.push(
                `${billingPrefix}enabled`,
                `${billingPrefix}send_email_allowed`,
                `${billingPrefix}send_sms_allowed`,
                `${billingPrefix}send_whatsapp_allowed`
            );
        } else if (documentKey === "quote" || documentKey === "salesorder") {
            selectFields.push(
                `${documentPrefix}email_allowed`,
                `${documentPrefix}sms_allowed`,
                `${documentPrefix}whatsapp_allowed`,
                `${documentPrefix}default_linktype`,
                `${documentPrefix}original_allowed`,
                `${documentPrefix}copy_allowed`
            );
        } else {
            // Invoice type with no billing policy mapping (e.g. credit invoice) — no send config.
            this.resendConfig = this.emptyResendConfig(true);
            this.resendConfigKey = configKey;
            return;
        }

        try {
            const result = await this.context.webAPI.retrieveMultipleRecords(
                "alex_payplusconfiguration",
                `?$select=${selectFields.join(",")}&$top=1`
            ) as unknown as { entities?: Record<string, boolean | number>[] };
            const configuration = result.entities && result.entities[0] || {};
            if (useBillingPolicy) {
                const billingEnabled = configuration[`${billingPrefix}enabled`] === true;
                this.resendConfig = {
                    loaded: true,
                    email: billingEnabled && this.boolValue(configuration, `${billingPrefix}send_email_allowed`),
                    sms: billingEnabled && this.boolValue(configuration, `${billingPrefix}send_sms_allowed`),
                    whatsapp: billingEnabled && this.boolValue(configuration, `${billingPrefix}send_whatsapp_allowed`),
                    originalAllowed: true,
                    copyAllowed: true,
                    defaultLinkType: "copy"
                };
            } else {
                this.resendConfig = {
                    loaded: true,
                    email: this.boolValue(configuration, `${documentPrefix}email_allowed`),
                    sms: this.boolValue(configuration, `${documentPrefix}sms_allowed`),
                    whatsapp: this.boolValue(configuration, `${documentPrefix}whatsapp_allowed`),
                    originalAllowed: configuration[`${documentPrefix}original_allowed`] !== false,
                    copyAllowed: configuration[`${documentPrefix}copy_allowed`] !== false,
                    defaultLinkType: configuration[`${documentPrefix}default_linktype`] === 100000000 ? "original" : "copy"
                };
            }
            this.resendConfigKey = configKey;
        } catch {
            this.resendConfig = this.emptyResendConfig(true);
            this.resendConfigKey = configKey;
        }
    }

    private isGenerated(row: PayPlusDocument | null): boolean {
        if (!row) return false;
        const lastOperation = (row.alex_lastoperation || "").toLowerCase();
        const resultStatus = (row.alex_payplusresultstatus || "").toLowerCase();
        return lastOperation === "generate" && (row.alex_lastsyncstatus === 100000001 || resultStatus === "success");
    }

    private normalizeSelections(row: PayPlusDocument): void {
        if (!row.alex_copypdfurl && this.selectedViewLinkType === "copy") this.selectedViewLinkType = "original";
        if (!row.alex_pdfurl && this.selectedViewLinkType === "original" && row.alex_copypdfurl) this.selectedViewLinkType = "copy";
        const sendLinkTypes = this.allowedSendLinkTypes(row);
        if (sendLinkTypes.indexOf(this.selectedSendLinkType) < 0 && sendLinkTypes.length) {
            this.selectedSendLinkType = sendLinkTypes.indexOf(this.resendConfig.defaultLinkType) >= 0 ? this.resendConfig.defaultLinkType : sendLinkTypes[0];
        }

        const channels = this.allowedSendChannels();
        if (channels.indexOf(this.selectedSendChannel) < 0 && channels.length) this.selectedSendChannel = channels[0];
    }

    private allowedSendChannels(): SendChannel[] {
        const channels: SendChannel[] = [];
        if (this.resendConfig.email) channels.push("email");
        if (this.resendConfig.sms) channels.push("sms");
        if (this.resendConfig.whatsapp) channels.push("whatsapp");
        return channels;
    }

    private allowedSendLinkTypes(row: PayPlusDocument): LinkType[] {
        const types: LinkType[] = [];
        if (this.resendConfig.copyAllowed && row.alex_copypdfurl) types.push("copy");
        if (this.resendConfig.originalAllowed && row.alex_pdfurl) types.push("original");
        return types;
    }

    private linkFor(row: PayPlusDocument | null, linkType: LinkType): string {
        if (!row) return "";
        if (linkType === "copy") return (row.alex_copypdfurl || "").trim();
        return (row.alex_pdfurl || "").trim();
    }

    private previewUrl(row: PayPlusDocument | null): string {
        if (!row) return "";
        if (this.isGenerated(row)) {
            return this.linkFor(row, this.selectedViewLinkType) || this.linkFor(row, "copy") || this.linkFor(row, "original") || (row.alex_documenturl || "").trim();
        }
        return (row.alex_pdfurl || row.alex_documenturl || "").trim();
    }

    private previewHtml(row: PayPlusDocument | null): string {
        const raw = row?.alex_rawdocumentjson || "";
        if (!raw) return "";
        try {
            const data = JSON.parse(raw) as Record<string, unknown>;
            const html = data.preview_html || data.previewHtml || data.html || data.document_html;
            return typeof html === "string" ? html : "";
        } catch {
            return "";
        }
    }

    private isFailed(row: PayPlusDocument | null): boolean {
        if (!row) return false;
        return row.alex_lastsyncstatus === 100000002 || (row.alex_payplusresultstatus || "").toLowerCase() === "failure";
    }

    private t(key: string): string {
        const he: Record<string, string> = {
            title: "\u05EA\u05E6\u05D5\u05D2\u05D4 \u05DE\u05E7\u05D3\u05D9\u05DE\u05D4 \u05E9\u05DC \u05DE\u05E1\u05DE\u05DA PayPlus",
            loading: "\u05D8\u05D5\u05E2\u05DF \u05E0\u05EA\u05D5\u05E0\u05D9 \u05DE\u05E1\u05DE\u05DA...",
            waiting: "\u05D9\u05D5\u05E6\u05E8 \u05D0\u05D5 \u05DE\u05E8\u05E2\u05E0\u05DF \u05D0\u05EA \u05D4\u05DE\u05E1\u05DE\u05DA \u05D1-PayPlus...",
            waitingSub: "\u05D4\u05D7\u05DC\u05D5\u05DF \u05D9\u05EA\u05E2\u05D3\u05DB\u05DF \u05D0\u05D5\u05D8\u05D5\u05DE\u05D8\u05D9\u05EA \u05DB\u05E9\u05D9\u05EA\u05E7\u05D1\u05DC \u05E7\u05D9\u05E9\u05D5\u05E8 \u05DC\u05EA\u05E6\u05D5\u05D2\u05D4.",
            noRecord: "\u05D0\u05D9\u05DF \u05E8\u05E9\u05D5\u05DE\u05EA \u05DE\u05E1\u05DE\u05DA \u05DC\u05D4\u05E6\u05D2\u05D4.",
            open: "\u05E4\u05EA\u05D7 \u05D1-PayPlus",
            original: "\u05DE\u05E7\u05D5\u05E8",
            copyDocument: "\u05E2\u05D5\u05EA\u05E7",
            issue: "\u05D4\u05E4\u05E7 \u05D1-PayPlus",
            issueTitle: "\u05D4\u05E4\u05E7\u05EA \u05DE\u05E1\u05DE\u05DA \u05D1-PayPlus",
            issueText: "\u05D4\u05DE\u05E1\u05DE\u05DA \u05D9\u05D5\u05E4\u05E7 \u05D1-PayPlus \u05E2\u05DC \u05D1\u05E1\u05D9\u05E1 \u05E0\u05EA\u05D5\u05E0\u05D9 \u05D4\u05E6\u05E2\u05EA \u05D4\u05DE\u05D7\u05D9\u05E8 \u05D4\u05E9\u05DE\u05D5\u05E8\u05D9\u05DD \u05D1-Dynamics 365. \u05D4\u05D0\u05DD \u05DC\u05D0\u05E9\u05E8 \u05D4\u05E4\u05E7\u05D4?",
            issueConfirm: "\u05D0\u05E9\u05E8 \u05D4\u05E4\u05E7\u05D4",
            cancel: "\u05D1\u05D9\u05D8\u05D5\u05DC",
            notNow: "\u05DC\u05D0 \u05E2\u05DB\u05E9\u05D9\u05D5",
            activateTitle: "\u05D4\u05E4\u05E2\u05DC\u05EA \u05D4\u05E6\u05E2\u05EA \u05DE\u05D7\u05D9\u05E8",
            activateText: "\u05D4\u05D0\u05DD \u05DC\u05D4\u05E4\u05E2\u05D9\u05DC \u05D0\u05EA \u05D4\u05E6\u05E2\u05EA \u05D4\u05DE\u05D7\u05D9\u05E8 \u05D1-Dynamics 365?",
            activateConfirm: "\u05D4\u05E4\u05E2\u05DC \u05D4\u05E6\u05E2\u05EA \u05DE\u05D7\u05D9\u05E8",
            activated: "\u05D4\u05E6\u05E2\u05EA \u05D4\u05DE\u05D7\u05D9\u05E8 \u05D4\u05D5\u05E4\u05E2\u05DC\u05D4 \u05D1\u05D4\u05E6\u05DC\u05D7\u05D4.",
            activateFailed: "\u05D4\u05E4\u05E2\u05DC\u05EA \u05D4\u05E6\u05E2\u05EA \u05D4\u05DE\u05D7\u05D9\u05E8 \u05E0\u05DB\u05E9\u05DC\u05D4: ",
            copy: "\u05D4\u05E2\u05EA\u05E7 \u05E7\u05D9\u05E9\u05D5\u05E8",
            refresh: "\u05E8\u05E2\u05E0\u05DF",
            copied: "\u05D4\u05E7\u05D9\u05E9\u05D5\u05E8 \u05D4\u05D5\u05E2\u05EA\u05E7",
            send: "\u05E9\u05DC\u05D9\u05D7\u05D4",
            sendRequest: "\u05D1\u05E7\u05E9 \u05E9\u05DC\u05D9\u05D7\u05D4",
            sendRequested: "\u05D1\u05E7\u05E9\u05EA \u05D4\u05E9\u05DC\u05D9\u05D7\u05D4 \u05E0\u05E8\u05E9\u05DE\u05D4.",
            email: "\u05D3\u05D5\u05D0\u0022\u05DC",
            sms: "SMS",
            whatsapp: "WhatsApp",
            documentAction: "\u05E4\u05E2\u05D5\u05DC\u05EA \u05DE\u05E1\u05DE\u05DA",
            cancelDocument: "\u05D1\u05D9\u05D8\u05D5\u05DC \u05DE\u05E1\u05DE\u05DA",
            closeDocument: "\u05E1\u05D2\u05D9\u05E8\u05EA \u05DE\u05E1\u05DE\u05DA",
            actionRequest: "\u05D1\u05E7\u05E9 \u05E4\u05E2\u05D5\u05DC\u05D4",
            actionRequested: "\u05D1\u05E7\u05E9\u05EA \u05D4\u05E4\u05E2\u05D5\u05DC\u05D4 \u05E0\u05E8\u05E9\u05DE\u05D4.",
            missingLink: "\u05DC\u05D0 \u05E0\u05DE\u05E6\u05D0 \u05E7\u05D9\u05E9\u05D5\u05E8 \u05DE\u05EA\u05D0\u05D9\u05DD \u05DC\u05E4\u05E2\u05D5\u05DC\u05D4.",
            failed: "\u05D9\u05E6\u05D9\u05E8\u05EA \u05D4\u05DE\u05E1\u05DE\u05DA \u05E0\u05DB\u05E9\u05DC\u05D4",
            status: "\u05E1\u05D8\u05D8\u05D5\u05E1",
            docNumber: "\u05DE\u05E1\u05E4\u05E8 \u05DE\u05E1\u05DE\u05DA",
            docType: "\u05E1\u05D5\u05D2",
            customer: "\u05DC\u05E7\u05D5\u05D7",
            amount: "\u05E1\u05DB\u05D5\u05DD",
            uuid: "PayPlus UUID",
            moreInfo: "\u05DE\u05D9\u05D3\u05E2 \u05E0\u05D5\u05E1\u05E3",
            error: "\u05E9\u05D2\u05D9\u05D0\u05D4",
            statusIssued: "\u05D4\u05D5\u05E4\u05E7",
            statusProcessing: "\u05D1\u05E2\u05D9\u05D1\u05D5\u05D3",
            statusFailed: "\u05E0\u05DB\u05E9\u05DC",
            webApiUnavailable: "\u05D4\u05E4\u05E7\u05D3 \u05D9\u05E4\u05E2\u05DC \u05DC\u05D0\u05D7\u05E8 \u05E4\u05E8\u05E1\u05D5\u05DD \u05D4\u05D3\u05E3 \u05D1\u05EA\u05D5\u05DA \u05D0\u05E4\u05DC\u05D9\u05E7\u05E6\u05D9\u05D9\u05EA model-driven. Web API \u05D0\u05D9\u05E0\u05D5 \u05D6\u05DE\u05D9\u05DF \u05D1\u05DE\u05E6\u05D1 \u05E2\u05E8\u05D9\u05DB\u05D4."
        };
        const en: Record<string, string> = {
            title: "PayPlus Document Preview",
            loading: "Loading document data...",
            waiting: "Creating or refreshing the PayPlus document...",
            waitingSub: "This window will update automatically when a preview link is available.",
            noRecord: "No document record is available for preview.",
            open: "Open in PayPlus",
            original: "Original",
            copyDocument: "Copy",
            issue: "Issue in PayPlus",
            issueTitle: "Issue document in PayPlus",
            issueText: "This will issue the document in PayPlus using the saved Dynamics 365 quote data. Do you want to continue?",
            issueConfirm: "Issue document",
            cancel: "Cancel",
            notNow: "Not now",
            activateTitle: "Activate quote",
            activateText: "Do you want to activate the quote in Dynamics 365?",
            activateConfirm: "Activate quote",
            activated: "The quote was activated successfully.",
            activateFailed: "Quote activation failed: ",
            copy: "Copy link",
            refresh: "Refresh",
            copied: "Link copied",
            send: "Send",
            sendRequest: "Request send",
            sendRequested: "Send request was recorded.",
            email: "Email",
            sms: "SMS",
            whatsapp: "WhatsApp",
            documentAction: "Document action",
            cancelDocument: "Cancel document",
            closeDocument: "Close document",
            actionRequest: "Request action",
            actionRequested: "Action request was recorded.",
            missingLink: "No matching document link is available for this action.",
            failed: "Document creation failed",
            status: "Status",
            docNumber: "Document no.",
            docType: "Type",
            customer: "Customer",
            amount: "Amount",
            uuid: "PayPlus UUID",
            moreInfo: "More info",
            error: "Error",
            statusIssued: "Issued",
            statusProcessing: "Processing",
            statusFailed: "Failed",
            webApiUnavailable: "This control will work after the custom page is published inside the model-driven app. Web API is not available in authoring mode."
        };
        return (this.isRtl ? he : en)[key] || key;
    }

    private render(): void {
        const row = this.document;
        const url = this.previewUrl(row);
        const html = this.previewHtml(row);
        const failed = this.isFailed(row);
        const generated = this.isGenerated(row);
        const canIssue = !!row && !failed && this.state === "ready" && !generated;

        this.root.innerHTML = `
            <div class="ppdp-shell">
                <div class="ppdp-header">
                    <div class="ppdp-identity">
                        <div class="ppdp-doc-title">${this.escape(this.headerTitle(row))}</div>
                        <div class="ppdp-doc-meta">${this.renderMeta(row, generated, failed)}</div>
                    </div>
                    <div class="ppdp-actions">
                        ${canIssue ? `<button type="button" class="ppdp-btn ppdp-primary" data-action="issue" aria-label="${this.escapeAttribute(this.t("issue"))}">${this.t("issue")}</button>` : ""}
                        ${generated ? this.renderSendControls(row) : ""}
                        ${generated ? this.renderDocumentActionControls(row) : ""}
                        ${generated ? this.renderViewSelector(row) : ""}
                        ${generated && url ? `<button type="button" class="ppdp-btn" data-action="open" aria-label="${this.escapeAttribute(this.t("open"))}">${this.iconOpen()}<span>${this.t("open")}</span></button><button type="button" class="ppdp-btn ppdp-icon" data-action="copy" title="${this.escapeAttribute(this.t("copy"))}" aria-label="${this.escapeAttribute(this.t("copy"))}">${this.iconCopy()}</button>` : ""}
                        <button type="button" class="ppdp-btn ppdp-icon" data-action="refresh" title="${this.escapeAttribute(this.t("refresh"))}" aria-label="${this.escapeAttribute(this.t("refresh"))}">${this.iconRefresh()}</button>
                    </div>
                </div>
                <div class="ppdp-stage">${this.renderBody(url, html, failed)}</div>
            </div>`;

        this.root.querySelector('[data-action="refresh"]')?.addEventListener("click", () => {
            void this.loadDocument(true);
        });
        this.root.querySelector('[data-action="issue"]')?.addEventListener("click", () => void this.issueInPayPlus());
        this.root.querySelector('[data-action="copy"]')?.addEventListener("click", () => void this.copyLink(url));
        this.root.querySelector('[data-action="open"]')?.addEventListener("click", () => this.openUrl(url));
        this.root.querySelector('[data-action="view-link"]')?.addEventListener("change", (event) => {
            this.selectedViewLinkType = (event.target as HTMLSelectElement).value as LinkType;
            this.render();
        });
        this.root.querySelector('[data-action="send-channel"]')?.addEventListener("change", (event) => {
            this.selectedSendChannel = (event.target as HTMLSelectElement).value as SendChannel;
        });
        this.root.querySelector('[data-action="send-link"]')?.addEventListener("change", (event) => {
            this.selectedSendLinkType = (event.target as HTMLSelectElement).value as LinkType;
        });
        this.root.querySelector('[data-action="request-send"]')?.addEventListener("click", () => void this.requestSend());
        this.root.querySelector('[data-action="document-action"]')?.addEventListener("change", (event) => {
            this.selectedDocumentAction = (event.target as HTMLSelectElement).value as DocumentAction;
        });
        this.root.querySelector('[data-action="request-document-action"]')?.addEventListener("click", () => void this.requestDocumentAction());
    }

    private renderViewSelector(row: PayPlusDocument | null): string {
        if (!row || (!row.alex_pdfurl && !row.alex_copypdfurl)) return "";
        return `<label class="ppdp-field"><span>${this.t("open")}</span><select data-action="view-link" aria-label="${this.escapeAttribute(this.t("open"))}">${this.renderLinkOptions(row, this.selectedViewLinkType)}</select></label>`;
    }

    private renderSendControls(row: PayPlusDocument | null): string {
        if (!row) return "";
        const channels = this.allowedSendChannels();
        if (!channels.length) return "";
        const channelOptions = channels.map((channel) => `<option value="${channel}"${channel === this.selectedSendChannel ? " selected" : ""}>${this.t(channel)}</option>`).join("");
        const linkOptions = this.renderLinkOptions(row, this.selectedSendLinkType, true);
        if (!linkOptions) return "";
        return `<div class="ppdp-group" role="group" aria-label="${this.escapeAttribute(this.t("send"))}"><select data-action="send-channel" aria-label="${this.escapeAttribute(this.t("send"))}">${channelOptions}</select><select data-action="send-link" aria-label="${this.escapeAttribute(this.t("documentAction"))}">${linkOptions}</select><button type="button" class="ppdp-btn ppdp-accent" data-action="request-send">${this.iconSend()}<span>${this.t("sendRequest")}</span></button></div>`;
    }

    private renderDocumentActionControls(row: PayPlusDocument | null): string {
        if (!this.canRequestDocumentLifecycleAction(row)) return "";
        return `<div class="ppdp-group" role="group" aria-label="${this.escapeAttribute(this.t("documentAction"))}"><select data-action="document-action" aria-label="${this.escapeAttribute(this.t("documentAction"))}"><option value="cancel"${this.selectedDocumentAction === "cancel" ? " selected" : ""}>${this.t("cancelDocument")}</option><option value="close"${this.selectedDocumentAction === "close" ? " selected" : ""}>${this.t("closeDocument")}</option></select><button type="button" class="ppdp-btn ppdp-danger" data-action="request-document-action">${this.t("actionRequest")}</button></div>`;
    }

    private canRequestDocumentLifecycleAction(row: PayPlusDocument | null): boolean {
        const docType = (row?.alex_documenttypecode || "").toLowerCase();
        return docType === "inv_tax" || docType === "inv_receipt" || docType === "inv_tax_receipt";
    }

    private renderLinkOptions(row: PayPlusDocument, selected: LinkType, forSend = false): string {
        const options: string[] = [];
        const allowCopy = !forSend || this.resendConfig.copyAllowed;
        const allowOriginal = !forSend || this.resendConfig.originalAllowed;
        if (allowCopy && row.alex_copypdfurl) options.push(`<option value="copy"${selected === "copy" ? " selected" : ""}>${this.t("copyDocument")}</option>`);
        if (allowOriginal && row.alex_pdfurl) options.push(`<option value="original"${selected === "original" ? " selected" : ""}>${this.t("original")}</option>`);
        return options.join("");
    }

    private renderBody(url: string, html: string, failed: boolean): string {
        if (this.state === "loading") return this.spinner(this.t("loading"), "");
        if (this.state === "error") return `<div class="ppdp-error"><b>${this.t("error")}</b><span>${this.escape(this.errorText)}</span></div>`;
        if (!this.recordId) return this.spinner(this.t("noRecord"), "");
        if (failed) {
            const detail = this.document?.alex_payplusresultdescription || this.document?.alex_payplusresultstatus || "";
            return `<div class="ppdp-error"><b>${this.t("failed")}</b><span>${this.escape(detail)}</span></div>`;
        }
        if (html) return `<div class="ppdp-paper"><iframe class="ppdp-frame" title="${this.t("title")}" srcdoc="${this.escapeAttribute(html)}"></iframe></div>`;
        if (url) return `<div class="ppdp-paper"><iframe class="ppdp-frame" title="${this.t("title")}" src="${this.escapeAttribute(this.pdfViewerUrl(url))}"></iframe></div>`;
        return this.spinner(this.t("waiting"), this.t("waitingSub"));
    }

    // Hide the browser's native PDF chrome for a clean, on-brand preview.
    private pdfViewerUrl(url: string): string {
        if (!url) return url;
        const hashless = url.split("#")[0];
        const isPdf = /\.pdf(\b|$|\?)/i.test(hashless);
        if (!isPdf) return url;
        if (url.indexOf("#") >= 0) return url;
        return `${url}#toolbar=0&navpanes=0&scrollbar=0&statusbar=0&view=FitH`;
    }

    private headerTitle(row: PayPlusDocument | null): string {
        return (row?.alex_documentnumber || row?.alex_name || this.t("title")).toString();
    }

    private renderMeta(row: PayPlusDocument | null, generated: boolean, failed: boolean): string {
        if (!row) return "";
        const parts: string[] = [];
        const type = this.typeInfo(row);
        if (type.label) parts.push(`<span class="ppdp-pill ppdp-pill-type ${type.cls}">${this.escape(type.label)}</span>`);
        const status = this.statusInfo(generated, failed);
        parts.push(`<span class="ppdp-pill ppdp-pill-status ${status.cls}">${this.escape(status.label)}</span>`);
        const amount = this.formatAmount(row);
        if (amount) parts.push(`<span class="ppdp-amount">${this.escape(amount)}</span>`);
        if (row.alex_customername) parts.push(`<span class="ppdp-customer">${this.escape(row.alex_customername)}</span>`);
        return parts.join("");
    }

    private typeInfo(row: PayPlusDocument | null): { label: string; cls: string } {
        const code = (row?.alex_documenttypecode || "").toLowerCase();
        const map: Record<string, { he: string; en: string; cls: string }> = {
            inv_tax: { he: "\u05D7\u05E9\u05D1\u05D5\u05E0\u05D9\u05EA \u05DE\u05E1", en: "Tax invoice", cls: "" },
            inv_tax_receipt: { he: "\u05D7\u05E9\u05D1\u05D5\u05E0\u05D9\u05EA \u05DE\u05E1 \u05E7\u05D1\u05DC\u05D4", en: "Tax invoice / receipt", cls: "ppdp-t-receipt" },
            inv_receipt: { he: "\u05E7\u05D1\u05DC\u05D4", en: "Receipt", cls: "ppdp-t-receipt" },
            inv_refund: { he: "\u05D7\u05E9\u05D1\u05D5\u05E0\u05D9\u05EA \u05D6\u05D9\u05DB\u05D5\u05D9", en: "Credit invoice", cls: "ppdp-t-refund" },
            inv_proforma: { he: "\u05D7\u05E9\u05D1\u05D5\u05E0\u05D9\u05EA \u05E2\u05E1\u05E7\u05D4", en: "Proforma", cls: "ppdp-t-info" },
            inv_pay_request: { he: "\u05D1\u05E7\u05E9\u05EA \u05EA\u05E9\u05DC\u05D5\u05DD", en: "Payment request", cls: "ppdp-t-info" },
            dc_quote: { he: "\u05D4\u05E6\u05E2\u05EA \u05DE\u05D7\u05D9\u05E8", en: "Quote", cls: "ppdp-t-info" },
            purchase: { he: "\u05DE\u05E1\u05DE\u05DA \u05E8\u05DB\u05E9", en: "Purchase", cls: "ppdp-t-info" }
        };
        const entry = map[code];
        if (!entry) return { label: "", cls: "" };
        return { label: this.isRtl ? entry.he : entry.en, cls: entry.cls };
    }

    private statusInfo(generated: boolean, failed: boolean): { label: string; cls: string } {
        if (failed) return { label: this.t("statusFailed"), cls: "ppdp-s-failed" };
        if (generated) return { label: this.t("statusIssued"), cls: "ppdp-s-issued" };
        return { label: this.t("statusProcessing"), cls: "ppdp-s-pending" };
    }

    private iconOpen(): string {
        return `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 4h6v6M20 4l-9 9M18 13v5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h5"/></svg>`;
    }

    private iconCopy(): string {
        return `<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/></svg>`;
    }

    private iconRefresh(): string {
        return `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12a9 9 0 1 1-2.64-6.36M21 4v5h-5"/></svg>`;
    }

    private iconSend(): string {
        return `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z"/></svg>`;
    }

    private spinner(title: string, subtitle: string): string {
        return `<div class="ppdp-wait"><div class="ppdp-spinner"></div><b>${this.escape(title)}</b>${subtitle ? `<span>${this.escape(subtitle)}</span>` : ""}</div>`;
    }

    private formatAmount(row: PayPlusDocument): string {
        if (row.alex_totalamount == null) return "";
        return `${row.alex_totalamount.toLocaleString()} ${row.alex_currencycode || ""}`.trim();
    }

    private async copyLink(url: string): Promise<void> {
        if (!url) return;
        try {
            await navigator.clipboard.writeText(url);
            await this.context.navigation.openAlertDialog({ text: this.t("copied") });
        } catch {
            window.prompt(this.t("copy"), url);
        }
    }

    private openUrl(url: string): void {
        if (!url) return;
        const navigation = this.context.navigation as unknown as { openUrl?: (url: string) => void };
        if (navigation.openUrl) navigation.openUrl(url);
        else window.open(url, "_blank", "noopener");
    }

    private async requestSend(): Promise<void> {
        if (!this.recordId || !this.document) return;
        const link = this.linkFor(this.document, this.selectedSendLinkType);
        if (!link) {
            await this.context.navigation.openAlertDialog({ text: this.t("missingLink") });
            return;
        }

        await this.updateRequestedAction({
            action: REQUESTED_ACTION.send,
            channel: REQUESTED_CHANNEL[this.selectedSendChannel],
            linkType: REQUESTED_LINK_TYPE[this.selectedSendLinkType],
            message: {
                source: "pcf",
                action: "send",
                channel: this.selectedSendChannel,
                linkType: this.selectedSendLinkType,
                link: link
            }
        });
        await this.context.navigation.openAlertDialog({ text: this.t("sendRequested") });
        await this.loadDocument(false);
    }

    private async requestDocumentAction(): Promise<void> {
        if (!this.recordId || !this.document) return;
        const actionValue = this.selectedDocumentAction === "close" ? REQUESTED_ACTION.close : REQUESTED_ACTION.cancel;
        await this.updateRequestedAction({
            action: actionValue,
            channel: null,
            linkType: null,
            message: {
                source: "pcf",
                action: this.selectedDocumentAction,
                documentUuid: this.document.alex_payplusdocumentuuid || ""
            }
        });
        await this.context.navigation.openAlertDialog({ text: this.t("actionRequested") });
        await this.loadDocument(false);
    }

    private async updateRequestedAction(input: { action: number; channel: number | null; linkType: number | null; message: Record<string, string | number | null> }): Promise<void> {
        const userSettings = this.context.userSettings as unknown as { userId?: string; userName?: string };
        const request = {
            alex_requestedaction: input.action,
            alex_requestedchannel: input.channel,
            alex_requestedlinktype: input.linkType,
            alex_requestedactionstatus: REQUESTED_ACTION_STATUS.pending,
            alex_businessstatus: 100000004,
            alex_requestedactionon: new Date().toISOString(),
            alex_requestedactionby: userSettings.userName || userSettings.userId || "",
            alex_requestedactionmessage: JSON.stringify(input.message)
        };
        await this.context.webAPI.updateRecord("alex_payplusdocument", this.recordId, request);
    }

    private async issueInPayPlus(): Promise<void> {
        if (!this.recordId || !this.document) return;
        const result = await this.context.navigation.openConfirmDialog({
            title: this.t("issueTitle"),
            text: this.issueTextForDocument(this.document),
            confirmButtonLabel: this.t("issueConfirm"),
            cancelButtonLabel: this.t("cancel")
        });
        if (!result.confirmed) return;

        const request: Record<string, string | number | null> = {
            alex_lastoperation: "Generate",
            alex_lastsyncstatus: 100000000,
            alex_businessstatus: 100000002,
            alex_payplusresultstatus: null,
            alex_payplusresultdescription: null,
            alex_payplusdocumentuuid: null,
            alex_documentnumber: null,
            alex_series: null,
            alex_documentstatus: null,
            alex_documenturl: null,
            alex_pdfurl: null,
            alex_copypdfurl: null,
            alex_requestedaction: null,
            alex_requestedchannel: null,
            alex_requestedlinktype: null,
            alex_requestedactionstatus: null,
            alex_requestedactionon: null,
            alex_requestedactionby: null,
            alex_requestedactionmessage: null,
            alex_rawresponse: null,
            alex_rawdocumentjson: null
        };
        if (this.document.alex_sourceentityid) request.alex_sourceentityid = this.document.alex_sourceentityid;
        if (this.document.alex_uniqueidentifier) request.alex_uniqueidentifier = this.document.alex_uniqueidentifier;

        await this.context.webAPI.updateRecord("alex_payplusdocument", this.recordId, request);
        this.activateQuoteAfterIssuePending = true;
        this.document = {
            ...this.document,
            alex_lastoperation: "Generate",
            alex_lastsyncstatus: 100000000,
            alex_payplusresultstatus: "",
            alex_payplusresultdescription: "",
            alex_payplusdocumentuuid: "",
            alex_documentnumber: "",
            alex_series: "",
            alex_documentstatus: "",
            alex_documenturl: "",
            alex_pdfurl: "",
            alex_copypdfurl: "",
            alex_rawdocumentjson: ""
        };
        this.state = "waiting";
        this.render();
        this.schedulePollIfNeeded();
    }

    private shouldAskActivateQuoteAfterIssue(row: PayPlusDocument): boolean {
        if (!this.isQuoteDocument(row)) return false;
        if (!this.activateQuoteAfterIssuePending || this.activateQuoteDialogOpen) return false;
        if ((row.alex_lastoperation || "").toLowerCase() !== "generate") return false;
        if (this.isFailed(row)) return false;
        return row.alex_lastsyncstatus === 100000001 || (row.alex_payplusresultstatus || "").toLowerCase() === "success";
    }

    private async askActivateQuoteAfterIssue(row: PayPlusDocument): Promise<void> {
        const quoteId = this.quoteId(row);
        this.activateQuoteDialogOpen = true;
        this.activateQuoteAfterIssuePending = false;

        try {
            if (!quoteId) return;
            const quote = await this.context.webAPI.retrieveRecord("quote", quoteId, "?$select=statecode,statuscode") as { statecode?: number; statuscode?: number };
            if (quote.statecode === 1) return;

            const result = await this.context.navigation.openConfirmDialog({
                title: this.t("activateTitle"),
                text: this.t("activateText"),
                confirmButtonLabel: this.t("activateConfirm"),
                cancelButtonLabel: this.t("notNow")
            });
            if (!result.confirmed) return;

            await this.context.webAPI.updateRecord("quote", quoteId, { statecode: 1, statuscode: 2 });
            this.refreshHostQuote();
            await this.context.navigation.openAlertDialog({ text: this.t("activated") });
        } catch (error) {
            const message = error instanceof Error ? error.message : String(error);
            await this.context.navigation.openAlertDialog({ text: `${this.t("activateFailed")}${message}` });
        } finally {
            this.activateQuoteDialogOpen = false;
        }
    }

    private quoteId(row: PayPlusDocument): string {
        return (row._alex_quoteid_value || row.alex_sourceentityid || "").replace(/[{}]/g, "").toLowerCase();
    }

    private refreshHostQuote(): void {
        const candidates: (Window | null)[] = [window.parent];
        for (const candidate of candidates) {
            try {
                const xrm = (candidate as unknown as { Xrm?: { Page?: { data?: { refresh?: (save?: boolean) => void } } } }).Xrm;
                xrm?.Page?.data?.refresh?.(false);
            } catch {
                // Parent form access can be blocked depending on the custom page host.
            }
        }
    }

    private escape(value: string): string {
        return value.replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[char] || char));
    }

    private escapeAttribute(value: string): string {
        return this.escape(value).replace(/`/g, "&#96;");
    }
}
