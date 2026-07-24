import { IInputs, IOutputs } from "./generated/ManifestTypes";
import "./vendor/payplus-hosted-fields.min.js";

type StatusKind = "info" | "success" | "error";
type PayMode = "full" | "partial";
type ExecState = "idle" | "running" | "success" | "error";

const PAYMENT_STATUS = {
    draft: 100000000,
    pendingExecution: 100000001,
    cleared: 100000002,
    cancelled: 100000003,
    failed: 100000004,
    processing: 100000005,
    approved: 100000006,
    declined: 100000007,
    pendingVerification: 100000008,
    verified: 100000009,
    unknown: 100000010,
    returned: 100000011
} as const;

const ALLOCATION_STATUS = {
    draft: 100000000,
    active: 100000001,
    reversed: 100000002,
    proposed: 100000003,
    failed: 100000004,
    cancelled: 100000005,
    returned: 100000006
} as const;

interface ContextInfo { entityId?: string; entityTypeName?: string }
interface BillingCase {
    alex_payplusbillingcaseid?: string;
    alex_name?: string;
    alex_defaultflow?: number;
    alex_sourceentitylogicalname?: string;
    alex_sourceentityid?: string;
    alex_sourcedisplayname?: string;
    alex_customername?: string;
    alex_totalamount?: number;
    alex_paidamount?: number;
    alex_openbalance?: number;
    alex_currencycode?: string;
    _alex_accountid_value?: string;
    _alex_contactid_value?: string;
}
interface InvoiceRow {
    invoiceid?: string;
    invoicenumber?: string;
    name?: string;
    totalamount?: number;
    totaltax?: number;
    totaldiscountamount?: number;
    discountamount?: number;
    ispricelocked?: boolean;
    _customerid_value?: string;
    _pricelevelid_value?: string;
    _transactioncurrencyid_value?: string;
    [key: string]: unknown;
}
interface InvoiceLine {
    invoicedetailid?: string;
    productname?: string;
    productdescription?: string;
    quantity?: number;
    priceperunit?: number;
    extendedamount?: number;
    _productid_value?: string;
    _uomid_value?: string;
    isproductoverridden?: boolean;
}
interface PaymentLine {
    alex_paypluspaymentlineid?: string;
    alex_name?: string;
    alex_sequence?: number;
    alex_chargemode?: number;
    alex_paymentmethod?: number;
    alex_status?: number;
    alex_amount?: number;
    alex_currencycode?: string;
    alex_reference?: string;
    alex_cardlast4?: string;
    alex_cardbrand?: string;
    alex_approvalnumber?: string;
    alex_externaltransactionid?: string;
    alex_resultdescription?: string;
    alex_failurereason?: string;
    _alex_receiptdocumentid_value?: string;
    [key: string]: unknown;
}
interface AllocationDraft {
    line: InvoiceLine;
    amount: number;
    remainingAfter: number;
}
interface HfSession {
    alex_pp_hfsessionid?: string;
    alex_status?: string;
    alex_hostedfieldsuid?: string;
    alex_pagerequestuid?: string;
    alex_message?: string;
}
interface SavedCard {
    alex_creditcardid?: string;
    alex_name?: string;
    alex_last4?: string;
    alex_brand?: number;
    alex_cardholdername?: string;
    alex_isdefault?: boolean;
    alex_isactive?: boolean;
    alex_expirymonth?: string;
    alex_expiryyear?: string;
    [key: string]: unknown;
}
interface BankRef {
    alex_bankid?: string;
    alex_bankcode?: number;
    alex_name?: string;
}
interface BranchRef {
    alex_bankbranchid?: string;
    alex_branchcode?: number;
    alex_name?: string;
}
interface CustomerBankAccount {
    alex_customerbankaccountid?: string;
    alex_name?: string;
    alex_accountholdername?: string;
    alex_accountnumber?: string;
    alex_isdefault?: boolean;
    alex_isactive?: boolean;
    alex_BankId?: BankRef;
    alex_BranchId?: BranchRef;
    [key: string]: unknown;
}
type PayMethod = "card" | "saved" | "bank" | "check";
type TransferMode = "existing" | "new";
type CheckSeriesMode = "single" | "series";
interface CheckRow {
    number: string;
    date: string;
    amount: number;
}
interface HostedFieldsDom {
    SetMainFields(fields: Record<string, { elmSelector: string; wrapperElmSelector: string }>): HostedFieldsDom;
    AddField(name: string, selector: string, wrapperSelector: string): HostedFieldsDom;
    SetRecaptcha(selector: string): HostedFieldsDom;
    CreatePaymentPage(options: { hosted_fields_uuid: string; page_request_uid: string; origin: string }): Promise<unknown>;
    InitPaymentPage: Promise<unknown>;
    Upon(eventName: string, handler: (event: { detail: unknown }) => void): void;
    SubmitPayment(): unknown;
}

const MONEY_FORMAT = { minimumFractionDigits: 2, maximumFractionDigits: 2 };
const POLL_MS = 1800;
const POLL_MAX = 36;
const FINALIZATION_POLL_MAX = 60;

export class PaymentWizard implements ComponentFramework.StandardControl<IInputs, IOutputs> {
    private context!: ComponentFramework.Context<IInputs>;
    private root!: HTMLDivElement;
    private isRtl = false;
    private sourceEntity = "";
    private sourceId = "";
    private billingCase: BillingCase | null = null;
    private invoice: InvoiceRow | null = null;
    private lines: InvoiceLine[] = [];
    private paymentLines: PaymentLine[] = [];
    private allocations: Record<string, unknown>[] = [];
    private selectedLineIds = new Set<string>();
    private allocationAmounts = new Map<string, number>();
    private amount = 0;
    private loading = true;
    private loadError = "";
    private configEnvironment = 100000001;
    private allowDocOverride = false;
    private hasTaxInvoice = false;
    private requestedDocFlow = 100000000;

    private step = 1;
    private payMode: PayMode = "full";
    private splitRemainder = false;
    private splitOutcome = "";
    private execState: ExecState = "idle";
    private execTitle = "";
    private execDetail = "";
    private receiptDocId = "";
    private receiptLabel = "";
    private invoiceClosed = false;
    private sentChannels = new Set<number>();

    private payMethod: PayMethod = "card";
    private savedCards: SavedCard[] = [];
    private selectedSavedCardId = "";
    private saveCardChecked = false;
    private pendingHolderName = "";
    private cardSaved = false;
    private customerContactId = "";
    private customerAccountId = "";

    private customerBankAccounts: CustomerBankAccount[] = [];
    private selectedBankAccountId = "";
    private banks: BankRef[] = [];
    private branches: BranchRef[] = [];
    private transferMode: TransferMode = "new";
    private tfBankId = "";
    private tfBranchId = "";
    private tfAccountNumber = "";
    private tfHolderName = "";
    private tfReference = "";
    private tfDate = "";
    private saveBankAccountChecked = false;
    private branchesLoading = false;

    private checkSeriesMode: CheckSeriesMode = "single";
    private checkCount = 3;
    private checkStartNumber = "";
    private checkFirstDate = "";
    private checks: CheckRow[] = [];
    private checksInitialized = false;

    private statusText = "";
    private statusKind: StatusKind = "info";
    private busy = false;
    private paneAnimateStep = -1;

    private hfRequestId = "";
    private hfSessionId = "";
    private hfHostedUid = "";
    private hfPageRequestUid = "";
    private hfSessionAmount = -1;
    private hfWarming = false;
    private hfWarmError = "";
    private hf: HostedFieldsDom | null = null;
    private hostedSubmitting = false;
    private hostedSubmitTimeout = 0;
    private hfMountId = 0;
    private cardReady = false;

    public init(context: ComponentFramework.Context<IInputs>, _notifyOutputChanged: () => void, _state: ComponentFramework.Dictionary, container: HTMLDivElement): void {
        this.context = context;
        this.isRtl = this.detectRtl(context);
        context.mode.trackContainerResize(true);
        this.root = document.createElement("div");
        this.root.className = "ppw";
        this.root.dir = this.isRtl ? "rtl" : "ltr";
        container.appendChild(this.root);
        this.resolveContext();
        this.render();
        void this.load();
    }

    public updateView(context: ComponentFramework.Context<IInputs>): void {
        this.context = context;
        const oldKey = `${this.sourceEntity}:${this.sourceId}`;
        this.resolveContext();
        const newRtl = this.detectRtl(context);
        if (newRtl !== this.isRtl) {
            this.isRtl = newRtl;
            this.root.dir = this.isRtl ? "rtl" : "ltr";
        }
        if (`${this.sourceEntity}:${this.sourceId}` !== oldKey) void this.load();
    }

    public getOutputs(): IOutputs { return { hostValue: this.context.parameters.hostValue.raw || "" }; }
    public destroy(): void { this.clearHostedSubmitWatchdog(); this.root.replaceChildren(); }

    private resolveContext(): void {
        const modeInfo = (this.context.mode as unknown as { contextInfo?: ContextInfo }).contextInfo;
        const pageInfo = (this.context as unknown as { page?: ContextInfo }).page;
        this.sourceEntity = (this.context.parameters.sourceEntity.raw || modeInfo?.entityTypeName || pageInfo?.entityTypeName || "").toLowerCase();
        this.sourceId = (this.context.parameters.sourceId.raw || modeInfo?.entityId || pageInfo?.entityId || "").replace(/[{}]/g, "").toLowerCase();
    }

    private detectRtl(context: ComponentFramework.Context<IInputs>): boolean {
        const settings = context.userSettings as unknown as { languageId?: number; isRTL?: boolean; isRtl?: boolean };
        if (settings.languageId === 1037 || settings.isRTL === true || settings.isRtl === true) return true;
        return (document.documentElement.dir || document.body.dir || "").toLowerCase() === "rtl";
    }

    private t(he: string, en: string): string { return this.isRtl ? he : en; }
    private api(): ComponentFramework.WebApi { return this.context.webAPI; }

    private async load(): Promise<void> {
        this.loading = true;
        this.loadError = "";
        this.statusText = "";
        this.render();
        try {
            if (!this.api()?.retrieveRecord) throw new Error(this.t("Web API אינו זמין בפקד.", "Web API is not available."));
            await this.loadConfigEnvironment();
            await this.loadBillingContext();
            // Pre-select the "tax invoice receipt" document when the billing case is set to that flow
            // (e.g. opened from the "חשבונית מס קבלה" ribbon button).
            if (Number(this.billingCase?.alex_defaultflow) === 100000003) this.requestedDocFlow = 100000002;
            await Promise.all([this.loadInvoiceLines(), this.loadPaymentLines(), this.loadAllocations(), this.loadExistingTaxInvoice()]);
            await this.syncCaseSummariesFromLoadedRows();
            await this.loadSavedCards();
            await this.loadCustomerBankAccounts();
            await this.loadBanks();
            this.amount = this.openBalance();
            this.selectedLineIds = new Set(this.lines.map((line) => line.invoicedetailid || "").filter(Boolean));
            this.allocationAmounts.clear();
            this.loading = false;
            this.render();
            void this.warmHostedFields();
        } catch (error) {
            this.loading = false;
            this.loadError = error instanceof Error ? error.message : String(error);
            this.render();
        }
    }

    private async loadConfigEnvironment(): Promise<void> {
        const result = await this.api().retrieveMultipleRecords("alex_payplusconfiguration", "?$select=alex_environment,alex_billing_allow_user_override&$top=1");
        const row = result.entities[0] as { alex_environment?: number; alex_billing_allow_user_override?: boolean } | undefined;
        this.configEnvironment = row?.alex_environment || 100000001;
        this.allowDocOverride = !!row?.alex_billing_allow_user_override;
    }

    private async loadExistingTaxInvoice(): Promise<void> {
        this.hasTaxInvoice = false;
        const billingCaseId = this.billingCase?.alex_payplusbillingcaseid;
        const invoiceId = this.invoice?.invoiceid || (this.billingCase?.alex_sourceentitylogicalname === "invoice" ? this.billingCase.alex_sourceentityid : "");
        const scope: string[] = [];
        if (billingCaseId) scope.push(`_alex_billingcaseid_value eq ${billingCaseId}`);
        if (invoiceId) scope.push(`_alex_invoiceid_value eq ${invoiceId}`);
        if (!scope.length) return;
        try {
            const query = `?$select=alex_payplusdocumentid&$filter=alex_documenttypecode eq 'inv_tax' and alex_payplusdocumentuuid ne null and (${scope.join(" or ")})&$top=1`;
            const result = await this.api().retrieveMultipleRecords("alex_payplusdocuments", query);
            this.hasTaxInvoice = result.entities.length > 0;
        } catch { this.hasTaxInvoice = false; }
    }

    private async loadBillingContext(): Promise<void> {
        if (this.sourceEntity === "alex_payplusbillingcase") {
            this.billingCase = await this.api().retrieveRecord("alex_payplusbillingcase", this.sourceId, "?$select=alex_payplusbillingcaseid,alex_name,alex_defaultflow,alex_sourceentitylogicalname,alex_sourceentityid,alex_sourcedisplayname,alex_customername,alex_totalamount,alex_paidamount,alex_openbalance,alex_currencycode,_alex_accountid_value,_alex_contactid_value") as BillingCase;
        } else if (this.sourceEntity === "invoice") {
            this.invoice = await this.api().retrieveRecord("invoice", this.sourceId, "?$select=invoiceid,invoicenumber,name,totalamount,totaltax,totaldiscountamount,discountamount,ispricelocked,_customerid_value,_pricelevelid_value,_transactioncurrencyid_value") as InvoiceRow;
            const caseResult = await this.api().retrieveMultipleRecords("alex_payplusbillingcase", `?$select=alex_payplusbillingcaseid,alex_name,alex_defaultflow,alex_sourceentitylogicalname,alex_sourceentityid,alex_sourcedisplayname,alex_customername,alex_totalamount,alex_paidamount,alex_openbalance,alex_currencycode,_alex_accountid_value,_alex_contactid_value&$filter=alex_sourceentitylogicalname eq 'invoice' and alex_sourceentityid eq '${this.sourceId.replace(/'/g, "''")}'&$orderby=modifiedon desc&$top=1`);
            this.billingCase = caseResult.entities[0] as BillingCase | undefined || null;
        }
        if (this.billingCase?.alex_sourceentitylogicalname === "invoice" && this.billingCase.alex_sourceentityid && !this.invoice) {
            this.invoice = await this.api().retrieveRecord("invoice", this.billingCase.alex_sourceentityid, "?$select=invoiceid,invoicenumber,name,totalamount,totaltax,totaldiscountamount,discountamount,ispricelocked,_customerid_value,_pricelevelid_value,_transactioncurrencyid_value") as InvoiceRow;
        }
        if (!this.billingCase && this.invoice) {
            this.billingCase = {
                alex_sourceentitylogicalname: "invoice",
                alex_sourceentityid: this.invoice.invoiceid || this.sourceId,
                alex_sourcedisplayname: this.invoice.invoicenumber || this.invoice.name,
                alex_customername: this.invoice["_customerid_value@OData.Community.Display.V1.FormattedValue" as keyof InvoiceRow] as string || "",
                alex_totalamount: this.invoice.totalamount || 0,
                alex_paidamount: 0,
                alex_openbalance: this.invoice.totalamount || 0,
                alex_currencycode: "ILS"
            };
        }
        if (!this.billingCase) throw new Error(this.t("לא נמצא תיק גבייה למקור שנבחר.", "No billing case was found for the selected source."));
        this.resolveCustomerLinks();
    }

    private resolveCustomerLinks(): void {
        // Prefer explicit lookups on the billing case; fall back to the source invoice customer.
        this.customerContactId = this.billingCase?._alex_contactid_value || "";
        this.customerAccountId = this.billingCase?._alex_accountid_value || "";
        if (this.customerContactId || this.customerAccountId) return;
        const customerId = this.invoice?._customerid_value;
        if (!customerId) return;
        const logicalName = String(this.invoice?.["_customerid_value@Microsoft.Dynamics.CRM.lookuplogicalname"] || "").toLowerCase();
        if (logicalName === "account") this.customerAccountId = customerId;
        else if (logicalName === "contact") this.customerContactId = customerId;
    }

    private async loadInvoiceLines(): Promise<void> {
        const invoiceId = this.invoice?.invoiceid || (this.billingCase?.alex_sourceentitylogicalname === "invoice" ? this.billingCase.alex_sourceentityid : "");
        if (!invoiceId) { this.lines = []; return; }
        const result = await this.api().retrieveMultipleRecords("invoicedetail", `?$select=invoicedetailid,productname,productdescription,quantity,priceperunit,extendedamount,_productid_value,_uomid_value,isproductoverridden&$filter=_invoiceid_value eq ${invoiceId}&$orderby=createdon asc`);
        this.lines = this.normalizeInvoiceLines(result.entities as InvoiceLine[]);
    }

    private normalizeInvoiceLines(lines: InvoiceLine[]): InvoiceLine[] {
        const invoiceTotal = this.roundMoney(Math.max(0, Number(this.invoice?.totalamount || this.billingCase?.alex_totalamount || 0)));
        const lineTotal = this.roundMoney(lines.reduce((sum, line) => sum + Math.max(0, Number(line.extendedamount || 0)), 0));
        if (!invoiceTotal || !lineTotal || Math.abs(lineTotal - invoiceTotal) <= 0.005) return lines;
        const ratio = invoiceTotal / lineTotal;
        let allocated = 0;
        return lines.map((line, index) => {
            const sourceAmount = Math.max(0, Number(line.extendedamount || 0));
            const amount = index === lines.length - 1 ? this.roundMoney(Math.max(0, invoiceTotal - allocated)) : this.roundMoney(sourceAmount * ratio);
            allocated = this.roundMoney(allocated + amount);
            const quantity = Math.abs(Number(line.quantity || 0));
            return { ...line, extendedamount: amount, priceperunit: this.roundMoney(quantity ? amount / quantity : amount) };
        });
    }

    private async loadPaymentLines(): Promise<void> {
        const billingCaseId = this.billingCase?.alex_payplusbillingcaseid;
        if (!billingCaseId) { this.paymentLines = []; return; }
        const query = `?$select=alex_paypluspaymentlineid,alex_name,alex_sequence,alex_chargemode,alex_paymentmethod,alex_status,alex_amount,alex_currencycode,alex_reference,alex_cardlast4,alex_cardbrand,alex_approvalnumber,alex_externaltransactionid,alex_resultdescription,alex_failurereason,_alex_receiptdocumentid_value&$filter=_alex_billingcaseid_value eq ${billingCaseId}&$orderby=createdon asc`;
        const result = await this.api().retrieveMultipleRecords("alex_paypluspaymentline", query);
        this.paymentLines = result.entities as PaymentLine[];
    }

    private async loadAllocations(): Promise<void> {
        const billingCaseId = this.billingCase?.alex_payplusbillingcaseid;
        if (!billingCaseId) { this.allocations = []; return; }
        const query = `?$select=alex_payplusreceiptallocationid,alex_status,alex_allocatedamount,alex_actualallocatedamount&$filter=_alex_billingcaseid_value eq ${billingCaseId}&$orderby=createdon asc`;
        const result = await this.api().retrieveMultipleRecords("alex_payplusreceiptallocation", query);
        this.allocations = result.entities as Record<string, unknown>[];
    }

    private async loadSavedCards(): Promise<void> {
        this.savedCards = [];
        const contactId = this.customerContactId;
        const accountId = this.customerAccountId;
        const filters: string[] = [];
        if (contactId) filters.push(`_alex_contact_value eq ${contactId}`);
        if (accountId) filters.push(`_alex_account_value eq ${accountId}`);
        if (!filters.length) return;
        // Only cards that hold a real PayPlus token can be charged via saved-card (Direction B).
        // Tokenless records (legacy/import placeholders) are excluded so they cannot be selected or charged.
        const query = `?$select=alex_creditcardid,alex_name,alex_last4,alex_brand,alex_cardholdername,alex_isdefault,alex_isactive,alex_expirymonth,alex_expiryyear&$filter=(${filters.join(" or ")}) and alex_isactive eq true and alex_token ne null and alex_token ne ''&$orderby=alex_isdefault desc,createdon desc`;
        try {
            const result = await this.api().retrieveMultipleRecords("alex_creditcard", query);
            this.savedCards = result.entities as SavedCard[];
            if (!this.savedCards.some((card) => card.alex_creditcardid === this.selectedSavedCardId)) {
                const preferred = this.savedCards.find((card) => card.alex_isdefault) || this.savedCards[0];
                this.selectedSavedCardId = preferred?.alex_creditcardid || "";
            }
        } catch { this.savedCards = []; }
    }

    private async loadCustomerBankAccounts(): Promise<void> {
        this.customerBankAccounts = [];
        const filters: string[] = [];
        if (this.customerContactId) filters.push(`_alex_contactid_value eq ${this.customerContactId}`);
        if (this.customerAccountId) filters.push(`_alex_accountid_value eq ${this.customerAccountId}`);
        if (!filters.length) return;
        const query = `?$select=alex_customerbankaccountid,alex_name,alex_accountholdername,alex_accountnumber,alex_isdefault,alex_isactive&$expand=alex_BankId($select=alex_bankid,alex_bankcode,alex_name),alex_BranchId($select=alex_bankbranchid,alex_branchcode,alex_name)&$filter=(${filters.join(" or ")}) and alex_isactive eq true&$orderby=alex_isdefault desc,createdon desc`;
        try {
            const result = await this.api().retrieveMultipleRecords("alex_customerbankaccount", query);
            this.customerBankAccounts = result.entities as CustomerBankAccount[];
            if (!this.customerBankAccounts.some((account) => account.alex_customerbankaccountid === this.selectedBankAccountId)) {
                const preferred = this.customerBankAccounts.find((account) => account.alex_isdefault) || this.customerBankAccounts[0];
                this.selectedBankAccountId = preferred?.alex_customerbankaccountid || "";
            }
        } catch { this.customerBankAccounts = []; }
    }

    private async loadBanks(): Promise<void> {
        if (this.banks.length) return;
        try {
            const result = await this.api().retrieveMultipleRecords("alex_bank", "?$select=alex_bankid,alex_bankcode,alex_name&$orderby=alex_bankcode asc");
            this.banks = result.entities as BankRef[];
        } catch { this.banks = []; }
    }

    private async loadBranchesForBank(bankId: string): Promise<void> {
        this.branches = [];
        if (!bankId) return;
        try {
            const result = await this.api().retrieveMultipleRecords("alex_bankbranch", `?$select=alex_bankbranchid,alex_branchcode,alex_name&$filter=_alex_bankid_value eq ${bankId}&$orderby=alex_branchcode asc`);
            this.branches = result.entities as BranchRef[];
        } catch { this.branches = []; }
    }

    private async syncCaseSummariesFromLoadedRows(): Promise<void> {
        if (!this.billingCase?.alex_payplusbillingcaseid) return;
        const totals = this.paymentTotals();
        const allocated = this.roundMoney(this.allocations.filter((allocation) => Number(allocation.alex_status) === ALLOCATION_STATUS.active).reduce((sum, allocation) => sum + Number(allocation.alex_actualallocatedamount ?? allocation.alex_allocatedamount ?? 0), 0));
        const patch: Record<string, unknown> = {
            alex_paidamount: totals.received,
            alex_receivedamount: totals.received,
            alex_openbalance: totals.currentBalance,
            alex_amountdue: totals.currentBalance,
            alex_processingamount: totals.processing,
            alex_pendingverificationamount: totals.pendingVerification,
            alex_allocatedamount: allocated,
            alex_unallocatedamount: Math.max(0, totals.received - allocated),
            alex_failedamount: totals.failed,
            alex_nextexpecteddocument: this.documentOutcomeLabel(),
            alex_documentstatussummary: this.documentStatusSummary(totals.received, totals.pendingVerification, totals.processing),
            alex_status: totals.currentBalance <= 0 ? 100000005 : totals.received > 0 ? 100000004 : 100000001
        };
        if (this.patchDiffers(this.billingCase, patch)) {
            await this.api().updateRecord("alex_payplusbillingcase", this.billingCase.alex_payplusbillingcaseid, patch);
            Object.assign(this.billingCase, patch);
        }
    }

    private openBalance(): number {
        const value = this.billingCase?.alex_openbalance ?? this.invoice?.totalamount ?? 0;
        return Number.isFinite(Number(value)) ? this.roundMoney(Number(value)) : 0;
    }

    private paymentTotals(): { total: number; processing: number; received: number; pendingVerification: number; failed: number; currentBalance: number } {
        const total = this.roundMoney(Number(this.billingCase?.alex_totalamount || this.invoice?.totalamount || 0));
        const received = this.sumPaymentLines((line) => this.isReceivedPayment(line));
        const processing = this.sumPaymentLines((line) => Number(line.alex_status) === PAYMENT_STATUS.processing);
        const pendingVerification = this.sumPaymentLines((line) => Number(line.alex_status) === PAYMENT_STATUS.pendingVerification);
        const failed = this.sumPaymentLines((line) => [PAYMENT_STATUS.failed, PAYMENT_STATUS.declined, PAYMENT_STATUS.returned].includes(Number(line.alex_status || 0) as 100000004 | 100000007 | 100000011));
        return { total, processing, received, pendingVerification, failed, currentBalance: this.roundMoney(Math.max(0, total - received)) };
    }

    private sumPaymentLines(predicate: (line: PaymentLine) => boolean): number {
        return this.roundMoney(this.paymentLines.filter(predicate).reduce((sum, line) => sum + Number(line.alex_amount || 0), 0));
    }

    private isReceivedPayment(line: PaymentLine): boolean {
        return [PAYMENT_STATUS.cleared, PAYMENT_STATUS.approved, PAYMENT_STATUS.verified].includes(Number(line.alex_status || 0) as 100000002 | 100000006 | 100000009);
    }

    private patchDiffers(source: unknown, patch: Record<string, unknown>): boolean {
        const sourceRecord = source as Record<string, unknown>;
        return Object.keys(patch).some((key) => {
            const oldValue = sourceRecord[key];
            const newValue = patch[key];
            if (typeof oldValue === "number" || typeof newValue === "number") return Math.abs(Number(oldValue || 0) - Number(newValue || 0)) > 0.005;
            return String(oldValue || "") !== String(newValue || "");
        });
    }

    private documentStatusSummary(received: number, pendingVerification: number, processing: number): string {
        if (processing > 0) return this.t("יש תשלומים בעיבוד. אין להפעיל חיוב חוזר.", "Payments are processing. Do not submit a duplicate charge.");
        if (pendingVerification > 0) return this.t("קיים תשלום שממתין לאימות לפני הפקת קבלה.", "A payment is waiting for verification before receipt issuance.");
        if (received > 0) return this.t("נדרש/צפוי מסמך קבלה לפי מדיניות הגבייה.", "A receipt document is expected according to the billing policy.");
        return this.t("עדיין לא התקבל תשלום ולכן אין מסמך קבלה להפקה.", "No payment has been received yet, so no receipt is ready to issue.");
    }

    private documentOutcomeLabel(): string {
        const flow = Number(this.billingCase?.alex_defaultflow || 100000004);
        if (flow === 100000003) return this.t("חשבונית מס קבלה", "Tax invoice receipt");
        if (flow === 100000002) return this.t("קבלה על הסכום שיתקבל", "Receipt for the received amount");
        if (flow === 100000001) return this.t("קבלה לאחר בקשת תשלום", "Receipt after payment request");
        if (flow === 100000000) return this.t("קבלה לאחר חשבונית עסקה", "Receipt after proforma invoice");
        return this.t("קבלה או המשך טיפול לפי בחירה", "Receipt or follow-up by user choice");
    }

    private effectiveDocType(): "inv_receipt" | "inv_tax_receipt" {
        if (this.hasTaxInvoice) return "inv_receipt";
        if (this.requestedDocFlow === 100000002) return "inv_tax_receipt";
        if (this.requestedDocFlow === 100000001) return "inv_receipt";
        if (Number(this.billingCase?.alex_defaultflow || 100000004) === 100000003) return "inv_tax_receipt";
        return "inv_receipt";
    }

    private effectiveDocLabel(): string {
        return this.effectiveDocType() === "inv_tax_receipt" ? this.t("חשבונית מס קבלה", "Tax invoice receipt") : this.t("קבלה", "Receipt");
    }

    private docChoiceHtml(): string {
        // Legal guard: once a tax invoice exists for this invoice, only a receipt may be issued.
        if (this.hasTaxInvoice) {
            return `<div class="ppw-doc-choice"><div class="ppw-doc-title">${this.e(this.t("מסמך חשבונאי", "Accounting document"))}</div><div class="ppw-note">${this.e(this.t("קיימת כבר חשבונית מס לחשבונית זו, ולכן תופק קבלה בלבד.", "A tax invoice already exists for this invoice, so only a receipt will be issued."))}</div></div>`;
        }
        if (!this.allowDocOverride) {
            return `<div class="ppw-doc-choice"><div class="ppw-doc-title">${this.e(this.t("מסמך חשבונאי", "Accounting document"))}</div><div class="ppw-summary-line"><span>${this.e(this.t("יופק לפי הגדרות הגבייה", "Issued per billing configuration"))}</span><span class="sv">${this.e(this.effectiveDocLabel())}</span></div></div>`;
        }
        const options = [
            { value: 100000000, label: this.t("ברירת מחדל מההגדרות", "Configuration default"), sub: this.effectiveDocLabelForFlow(100000000) },
            { value: 100000001, label: this.t("קבלה", "Receipt"), sub: this.t("מסמך קבלה בלבד", "Receipt document only") },
            { value: 100000002, label: this.t("חשבונית מס קבלה", "Tax invoice receipt"), sub: this.t("חשבונית מס וקבלה במסמך אחד", "Tax invoice and receipt in one document") }
        ];
        const cards = options.map((option) => {
            const on = this.requestedDocFlow === option.value;
            return `<div class="ppw-choice ${on ? "sel" : ""}" data-docflow="${option.value}">
                <div class="ct"><span class="radio"></span>${this.e(option.label)}</div>
                <div class="cs">${this.e(option.sub)}</div>
            </div>`;
        }).join("");
        return `<div class="ppw-doc-choice">
            <div class="ppw-doc-title">${this.e(this.t("איזה מסמך חשבונאי להפיק", "Which accounting document to issue"))}</div>
            <div class="ppw-choices ppw-choices-3">${cards}</div>
        </div>`;
    }

    private effectiveDocLabelForFlow(requested: number): string {
        const previous = this.requestedDocFlow;
        this.requestedDocFlow = requested;
        const label = this.effectiveDocLabel();
        this.requestedDocFlow = previous;
        return this.t(`ייגזר: ${label}`, `Resolves to: ${label}`);
    }


    private allocationDrafts(): AllocationDraft[] {
        const selected = this.lines.filter((line) => this.selectedLineIds.has(line.invoicedetailid || ""));
        const source = selected.length ? selected : this.lines;
        if (!source.length) return [];
        const manualTotal = this.roundMoney(Array.from(this.allocationAmounts.values()).reduce((sum, value) => sum + Math.max(0, Number(value || 0)), 0));
        if (this.payMode === "partial" && manualTotal > 0) {
            return source.map((line) => {
                const amount = this.roundMoney(Math.min(Math.max(0, Number(this.allocationAmounts.get(line.invoicedetailid || "") || 0)), Number(line.extendedamount || 0)));
                return { line, amount, remainingAfter: this.roundMoney(Math.max(0, Number(line.extendedamount || 0) - amount)) };
            }).filter((draft) => draft.amount > 0);
        }
        let remaining = Math.max(0, Number(this.amount || 0));
        const drafts: AllocationDraft[] = [];
        for (const line of source) {
            if (remaining <= 0) break;
            const open = Math.max(0, Number(line.extendedamount || 0));
            const amount = this.roundMoney(Math.min(open, remaining));
            remaining = this.roundMoney(Math.max(0, remaining - amount));
            if (amount > 0) drafts.push({ line, amount, remainingAfter: this.roundMoney(Math.max(0, open - amount)) });
        }
        return drafts;
    }

    private validateAllocationDrafts(drafts: AllocationDraft[]): void {
        if (!this.lines.length) return;
        const allocated = drafts.reduce((sum, draft) => sum + draft.amount, 0);
        if (allocated <= 0) throw new Error(this.t("יש לשייך את התשלום לפריט אחד לפחות.", "Allocate the payment to at least one item."));
        if (allocated - this.amount > 0.005) throw new Error(this.t("סכום השיוך גדול מסכום התשלום.", "Allocated amount is greater than the payment amount."));
    }

    private allocatedTotal(): number {
        return this.roundMoney(this.allocationDrafts().reduce((sum, draft) => sum + draft.amount, 0));
    }

    private async createHostedPaymentLine(rawPayment: unknown): Promise<string> {
        if (!this.billingCase?.alex_payplusbillingcaseid) throw new Error(this.t("לא נמצא תיק גבייה לשמירת התשלום.", "No billing case was found for saving the payment."));
        this.amount = this.roundMoney(this.amount);
        if (!this.amount || this.amount <= 0) throw new Error(this.t("יש להזין סכום חיובי.", "Enter a positive amount."));
        const drafts = this.allocationDrafts();
        this.validateAllocationDrafts(drafts);
        const transaction = this.extractHostedTransaction(rawPayment);
        const body: Record<string, unknown> = {
            alex_name: `${this.t("תשלום", "Payment")} ${this.formatMoney(this.amount)}`,
            alex_sequence: this.paymentLines.length + 1,
            alex_chargemode: 100000001,
            alex_paymentmethod: 100000002,
            alex_status: PAYMENT_STATUS.pendingVerification,
            alex_amount: this.amount,
            alex_currencycode: this.billingCase.alex_currencycode || "ILS",
            alex_paymentdate: new Date().toISOString().substring(0, 10),
            alex_notes: JSON.stringify({ createdBy: "PayPlus.PaymentWizard", method: "hosted", selectedInvoiceLineIds: drafts.map((draft) => draft.line.invoicedetailid || "").filter(Boolean) }),
            alex_requesteddocflow: this.requestedDocFlow,
            "alex_billingcaseid@odata.bind": `/alex_payplusbillingcases(${this.billingCase.alex_payplusbillingcaseid})`
        };
        if (this.hfRequestId) body.alex_reference = this.hfRequestId;
        if (transaction.uid) body.alex_externaltransactionid = transaction.uid;
        if (transaction.last4) body.alex_cardlast4 = transaction.last4;
        if (transaction.brand) body.alex_cardbrand = transaction.brand;
        if (transaction.approval) body.alex_approvalnumber = transaction.approval;
        if (rawPayment) body.alex_rawpaymentjson = JSON.stringify(rawPayment).substring(0, 1000000);
        const created = await this.api().createRecord("alex_paypluspaymentline", body);
        const paymentLineId = created.id.replace(/[{}]/g, "").toLowerCase();
        await this.createAllocationRows(paymentLineId, drafts, ALLOCATION_STATUS.proposed);
        return paymentLineId;
    }

    private async createAllocationRows(paymentLineId: string, drafts: AllocationDraft[], status: number): Promise<void> {
        if (!this.billingCase?.alex_payplusbillingcaseid) return;
        const now = new Date().toISOString();
        for (let index = 0; index < drafts.length; index++) {
            const draft = drafts[index];
            const sourceLineId = draft.line.invoicedetailid || "";
            const sourceName = draft.line.productname || draft.line.productdescription || this.t("פריט", "Item");
            const body: Record<string, unknown> = {
                alex_name: `${sourceName} - ${this.formatMoney(draft.amount)}`,
                alex_allocatedamount: draft.amount,
                alex_proposedamount: draft.amount,
                alex_actualallocatedamount: 0,
                alex_currencycode: this.billingCase.alex_currencycode || "ILS",
                alex_status: status,
                alex_sourceentitylogicalname: this.invoice?.invoiceid ? "invoice" : this.billingCase.alex_sourceentitylogicalname || "",
                alex_sourcerecordid: this.invoice?.invoiceid || this.billingCase.alex_sourceentityid || "",
                alex_sourcelineid: sourceLineId,
                alex_sourceitemname: sourceName,
                alex_sourcedocumentnumber: this.invoice?.invoicenumber || this.billingCase.alex_sourcedisplayname || "",
                alex_sourcelinenumber: String(index + 1),
                alex_originalamount: Number(draft.line.extendedamount || 0),
                alex_openamountsnapshot: Number(draft.line.extendedamount || 0),
                alex_snapshotcurrencycode: this.billingCase.alex_currencycode || "ILS",
                alex_remainingafterallocation: draft.remainingAfter,
                alex_allocationtype: 100000001,
                alex_snapshottimestamp: now,
                "alex_billingcaseid@odata.bind": `/alex_payplusbillingcases(${this.billingCase.alex_payplusbillingcaseid})`,
                "alex_paymentlineid@odata.bind": `/alex_paypluspaymentlines(${paymentLineId})`
            };
            if (this.invoice?.invoiceid) body["alex_invoiceid@odata.bind"] = `/invoices(${this.invoice.invoiceid})`;
            if (sourceLineId) body["alex_invoicedetailid@odata.bind"] = `/invoicedetails(${sourceLineId})`;
            await this.api().createRecord("alex_payplusreceiptallocation", body);
        }
    }

    private extractHostedTransaction(rawPayment: unknown): { uid: string; last4: string; brand: string; approval: string; token: string; expiryMonth: string; expiryYear: string; customerUid: string } {
        const data = rawPayment as Record<string, unknown> | undefined;
        const nested = data?.data as Record<string, unknown> | undefined;
        const transaction = (nested?.transaction || data?.transaction || nested || data || {}) as Record<string, unknown>;
        const card = (transaction.card_information || nested?.card_information || {}) as Record<string, unknown>;
        return {
            uid: String(transaction.uid || transaction.uuid || transaction.transaction_uid || transaction.transaction_uuid || nested?.page_request_uid || ""),
            last4: String(card.four_digits || card.last_four_digits || transaction.four_digits || transaction.last_four_digits || nested?.four_digits || "").substring(0, 4),
            brand: String(card.brand_name || card.brand || card.brand_id || transaction.brand_name || transaction.brand || ""),
            approval: String(transaction.approval_number || transaction.approval || transaction.voucher_number || ""),
            token: String(transaction.token || transaction.token_uid || card.token || nested?.token || nested?.token_uid || data?.token || ""),
            expiryMonth: String(card.expiry_month || transaction.expiry_month || nested?.expiry_month || "").substring(0, 2),
            expiryYear: String(card.expiry_year || transaction.expiry_year || nested?.expiry_year || "").substring(0, 4),
            customerUid: String(transaction.customer_uid || nested?.customer_uid || (nested?.customer as Record<string, unknown> | undefined)?.customer_uid || "")
        };
    }

    private async retrievePaymentLine(paymentLineId: string): Promise<PaymentLine> {
        const query = "?$select=alex_paypluspaymentlineid,alex_status,alex_resultdescription,alex_failurereason,alex_externaltransactionid,alex_approvalnumber,_alex_receiptdocumentid_value";
        return await this.api().retrieveRecord("alex_paypluspaymentline", paymentLineId, query) as PaymentLine;
    }

    private async waitForReceiptFinalization(paymentLineId: string): Promise<PaymentLine> {
        for (let attempt = 0; attempt <= FINALIZATION_POLL_MAX; attempt++) {
            const line = await this.retrievePaymentLine(paymentLineId);
            const status = Number(line.alex_status || 0);
            if (status === PAYMENT_STATUS.cleared && line._alex_receiptdocumentid_value) return line;
            if (status === PAYMENT_STATUS.cleared && String(line.alex_resultdescription || "").toLowerCase().includes("receipt creation failed")) {
                throw new Error(line.alex_resultdescription || this.t("התשלום אושר אך הפקת הקבלה נכשלה.", "Payment was approved but receipt issuance failed."));
            }
            if (status === PAYMENT_STATUS.failed || status === PAYMENT_STATUS.declined || status === PAYMENT_STATUS.returned || status === PAYMENT_STATUS.cancelled) {
                throw new Error(line.alex_failurereason || line.alex_resultdescription || this.t("התשלום לא אושר ב-PayPlus.", "The payment was not approved by PayPlus."));
            }
            this.execDetail = status === PAYMENT_STATUS.cleared
                ? this.t("התשלום אושר. מפיק קבלה ומקשר למסמך…", "Payment approved. Issuing receipt and linking the document…")
                : this.t("ממתין לאישור סופי מ-PayPlus ולהפקת קבלה…", "Waiting for final PayPlus approval and receipt issuance…");
            this.updateExecDetail();
            await new Promise((resolve) => window.setTimeout(resolve, POLL_MS));
        }
        throw new Error(this.t("התשלום נקלט, אבל לא התקבל אישור קבלה בזמן. ניתן לרענן ולבדוק שוב.", "The payment was captured, but receipt confirmation did not arrive in time. Refresh and check again."));
    }

    /* -------------------- Hosted Fields -------------------- */

    private async warmHostedFields(): Promise<void> {
        if (!this.billingCase?.alex_payplusbillingcaseid || this.hfWarming) return;
        this.hfWarming = true;
        this.hfWarmError = "";
        try {
            this.hfSessionAmount = this.amount;
            await this.startHostedFieldsSession();
            this.hfWarming = false;
            if (this.step === 2) void this.ensureHostedMounted();
        } catch (error) {
            this.hfWarming = false;
            this.hfWarmError = error instanceof Error ? error.message : String(error);
            if (this.step === 2) this.showCardError(this.hfWarmError);
        }
    }

    private async startHostedFieldsSession(): Promise<void> {
        if (!this.billingCase?.alex_payplusbillingcaseid) throw new Error(this.t("לא נמצא תיק גבייה.", "No billing case was found."));
        const requestId = this.newGuid();
        this.hfRequestId = requestId;
        const body: Record<string, unknown> = { alex_name: requestId, alex_requestid: requestId, alex_status: "Pending" };
        const accountId = this.customerAccountId;
        const contactId = this.customerContactId;
        if (accountId) body["alex_Account@odata.bind"] = `/accounts(${accountId})`;
        if (contactId) body["alex_Contact@odata.bind"] = `/contacts(${contactId})`;
        const session = await this.api().createRecord("alex_pp_hfsession", body);
        this.hfSessionId = session.id.replace(/[{}]/g, "").toLowerCase();
        await this.executeCustomAction("alex_CreateHfSession", { request_id: requestId, amount: String(this.amount || this.openBalance()), origin: window.location.origin });
        const ready = await this.pollHostedSession(this.hfSessionId, 0);
        this.hfHostedUid = ready.alex_hostedfieldsuid || "";
        this.hfPageRequestUid = ready.alex_pagerequestuid || "";
    }

    private async pollHostedSession(id: string, attempt: number): Promise<HfSession> {
        if (attempt > POLL_MAX) throw new Error(this.t("תם הזמן בהמתנה לשדות המאובטחים.", "Timed out waiting for hosted fields."));
        const row = await this.api().retrieveRecord("alex_pp_hfsession", id, "?$select=alex_status,alex_hostedfieldsuid,alex_pagerequestuid,alex_message") as HfSession;
        if (row.alex_status === "Ready" && row.alex_hostedfieldsuid && row.alex_pagerequestuid) return row;
        if (row.alex_status === "Error") throw new Error(row.alex_message || "Hosted fields session failed.");
        await new Promise((resolve) => window.setTimeout(resolve, POLL_MS));
        return this.pollHostedSession(id, attempt + 1);
    }

    private async executeCustomAction(name: string, parameters: Record<string, string>): Promise<void> {
        const clientUrl = (this.context as unknown as { page?: { getClientUrl?: () => string } }).page?.getClientUrl?.() || (window.parent as unknown as { Xrm?: { Utility?: { getGlobalContext?: () => { getClientUrl: () => string } } } }).Xrm?.Utility?.getGlobalContext?.().getClientUrl() || "";
        const response = await fetch(`${clientUrl}/api/data/v9.2/${name}`, {
            method: "POST",
            credentials: "same-origin",
            headers: { "Content-Type": "application/json", Accept: "application/json", "OData-Version": "4.0", "OData-MaxVersion": "4.0" },
            body: JSON.stringify(parameters)
        });
        if (!response.ok) throw new Error(await response.text());
    }

    private async ensureHostedMounted(): Promise<void> {
        if (this.step !== 2 || this.hf) return;
        if (this.hfWarming) { this.showCardLoading(this.t("מכין תשלום מאובטח…", "Preparing secure payment…")); return; }
        if (!this.hfHostedUid || !this.hfPageRequestUid || this.hfSessionAmount !== this.amount) {
            await this.rewarmAndMount();
            return;
        }
        this.showCardLoading(this.t("טוען שדות כרטיס מאובטחים…", "Loading secure card fields…"));
        try {
            await this.mountHostedFields();
            this.markCardReady();
        } catch (error) {
            this.showCardError(error instanceof Error ? error.message : String(error));
        }
    }

    private async rewarmAndMount(): Promise<void> {
        this.showCardLoading(this.t("מכין תשלום מאובטח…", "Preparing secure payment…"));
        try {
            this.hfSessionAmount = this.amount;
            await this.startHostedFieldsSession();
            if (this.step !== 2) return;
            await this.mountHostedFields();
            this.markCardReady();
        } catch (error) {
            this.showCardError(error instanceof Error ? error.message : String(error));
        }
    }

    private async ensureHostedScript(): Promise<void> {
        const maybeWindow = window as unknown as { PayPlusHostedFieldsDom?: new () => HostedFieldsDom };
        if (maybeWindow.PayPlusHostedFieldsDom) return;
        throw new Error(this.t("ספריית Hosted Fields לא נטענה כחלק מהפקד.", "Hosted Fields library was not bundled with the control."));
    }

    private async mountHostedFields(): Promise<void> {
        if (!this.hfHostedUid || !this.hfPageRequestUid) return;
        await this.ensureHostedScript();
        const maybeWindow = window as unknown as { PayPlusHostedFieldsDom?: new () => HostedFieldsDom };
        if (!maybeWindow.PayPlusHostedFieldsDom) throw new Error(this.t("ספריית Hosted Fields אינה זמינה.", "Hosted Fields library is unavailable."));
        this.hf = new maybeWindow.PayPlusHostedFieldsDom();
        const mountId = ++this.hfMountId;
        const isCurrentMount = (): boolean => { return mountId === this.hfMountId; };
        this.hf.SetMainFields({
            cc: { elmSelector: "#ppw-cc", wrapperElmSelector: "#ppw-cc-wrapper" },
            expiry: { elmSelector: "#ppw-expiry", wrapperElmSelector: "#ppw-expiry-wrapper" },
            expirym: { elmSelector: "#ppw-expirym", wrapperElmSelector: "#ppw-expirym-wrapper" },
            expiryy: { elmSelector: "#ppw-expiryy", wrapperElmSelector: "#ppw-expiryy-wrapper" },
            cvv: { elmSelector: "#ppw-cvv", wrapperElmSelector: "#ppw-cvv-wrapper" }
        }).AddField("card_holder_name", "#ppw-card-holder", "#ppw-card-holder").SetRecaptcha("#ppw-recaptcha");
        this.hf.Upon("pp_responseFromServer", (event) => { if (isCurrentMount()) void this.handleHostedResponse(event.detail); });
        this.hf.Upon("pp_pageExpired", () => { if (isCurrentMount()) this.resetHostedSession(this.t("פג תוקף השדות המאובטחים. השדות נטענים מחדש.", "Secure card fields expired. Fields are reloading.")); });
        this.hf.Upon("pp_paymentPageKilled", () => { if (isCurrentMount()) this.resetHostedSession(this.t("טופס הכרטיס המאובטח נסגר. השדות נטענים מחדש.", "The secure card form was closed. Fields are reloading.")); });
        await this.hf.CreatePaymentPage({ hosted_fields_uuid: this.hfHostedUid, page_request_uid: this.hfPageRequestUid, origin: this.payPlusOrigin() });
        await this.hf.InitPaymentPage;
        this.scheduleHostedExpiryTidy();
    }

    private scheduleHostedExpiryTidy(): void {
        [0, 200, 800, 1500].forEach((delay) => window.setTimeout(() => this.tidyHostedExpiry(), delay));
    }

    private tidyHostedExpiry(): void {
        const singleHas = !!this.root.querySelector("#fld-expiry, #ppw-expiry iframe, #ppw-expiry-wrapper iframe");
        const splitHas = !!this.root.querySelector("#fld-expirym, #fld-expiryy, #ppw-expirym iframe, #ppw-expiryy iframe, #ppw-expirym-wrapper iframe, #ppw-expiryy-wrapper iframe");
        const single = this.root.querySelector<HTMLElement>("#ppw-expiry-wrapper");
        const split = this.root.querySelector<HTMLElement>("#ppw-split-expiry");
        if (splitHas) {
            if (single) single.style.display = "none";
            if (split) split.style.display = "grid";
        } else if (singleHas) {
            if (split) split.style.display = "none";
            if (single) single.style.display = "block";
        }
    }

    private payPlusOrigin(): string {
        return this.configEnvironment === 100000000 ? "https://restapi.payplus.co.il" : "https://restapidev.payplus.co.il";
    }

    private submitHostedFields(): void {
        if (this.busy) return;
        if (!this.hf || !this.cardReady) {
            this.showCardError(this.t("שדות הכרטיס עדיין נטענים. נא להמתין רגע ולנסות שוב.", "The card fields are still loading. Please wait a moment and try again."));
            return;
        }
        this.busy = true;
        this.hostedSubmitting = true;
        this.pendingHolderName = this.root.querySelector<HTMLInputElement>("#ppw-card-holder")?.value?.trim() || "";
        this.showHostedSubmitting();
        this.updateFooter();
        this.startHostedSubmitWatchdog();
        try {
            this.hf.SubmitPayment();
        } catch (error) {
            void this.reloadHostedFieldsAfterFailure(error instanceof Error ? error.message : String(error));
        }
    }

    private friendlyCardError(raw: string): string {
        const key = (raw || "").toLowerCase();
        const fallback = this.t("החיוב נדחה על ידי PayPlus. ניתן לתקן פרטים ולנסות שוב.", "The charge was rejected by PayPlus. Correct the details and try again.");
        if (!key) return fallback;
        const map: { match: RegExp; he: string; en: string }[] = [
            { match: /credit-?card-?number|card-?number|invalid-?card|luhn/, he: "מספר הכרטיס שגוי. ודא שהזנת 16 ספרות נכונות.", en: "The card number is invalid. Make sure you entered all 16 digits correctly." },
            { match: /cvv|security-?code|cvc/, he: "קוד האבטחה (CVV) שגוי. הזן את 3 הספרות שבגב הכרטיס.", en: "The security code (CVV) is invalid. Enter the 3 digits from the back of the card." },
            { match: /expir|expiry|valid-?until|month|year/, he: "תאריך התוקף שגוי. בדוק את החודש והשנה על הכרטיס.", en: "The expiry date is invalid. Check the month and year on the card." },
            { match: /holder|owner|name/, he: "שם בעל הכרטיס חסר או שגוי.", en: "The cardholder name is missing or invalid." },
            { match: /declin|refus|reject|not-?approved|insufficient/, he: "החיוב נדחה על ידי חברת האשראי. נסה כרטיס אחר.", en: "The charge was declined by the card issuer. Try a different card." },
            { match: /recaptcha|captcha/, he: "אימות האבטחה נכשל. נסה שוב.", en: "Security verification failed. Please try again." }
        ];
        const hit = map.find((entry) => entry.match.test(key));
        if (hit) return this.t(hit.he, hit.en);
        return raw.length <= 120 ? raw : fallback;
    }

    private async handleHostedResponse(detail: unknown): Promise<void> {
        const data = detail as { results?: { status?: string; description?: string }; status?: string; message?: string; success?: unknown; errors?: unknown[] };
        const status = String(data.results?.status || data.status || "").toLowerCase();
        const errors = Array.isArray(data.errors) ? data.errors.map((error) => String((error as { message?: unknown }).message || "")).filter(Boolean) : [];
        const successFlag = String(data.success ?? "").toLowerCase();
        if ((status && status !== "success") || successFlag === "false" || successFlag === "0" || errors.length) {
            const rawMessage = errors.join(" | ") || String(data.message || data.results?.description || "");
            const message = this.friendlyCardError(rawMessage);
            this.clearHostedSubmitWatchdog();
            this.busy = false;
            this.hostedSubmitting = false;
            this.clearHostedSubmittingVisual();
            this.showCardError(message);
            this.updateFooter();
            return;
        }
        try {
            this.clearHostedSubmitWatchdog();
            this.hostedSubmitting = false;
            this.hfMountId++;
            this.hf = null;
            this.cardReady = false;
            this.step = 3;
            this.execState = "running";
            this.execTitle = this.t("מבצע חיוב מאובטח מול PayPlus…", "Running a secure charge with PayPlus…");
            this.execDetail = this.t("התשלום נקלט. ממתין לאימות סופי ולהפקת קבלה…", "Payment captured. Waiting for final verification and receipt issuance…");
            this.render();
            const paymentLineId = await this.createHostedPaymentLine(detail);
            const finalized = await this.waitForReceiptFinalization(paymentLineId);
            this.receiptDocId = String(finalized._alex_receiptdocumentid_value || "");
            this.receiptLabel = String(finalized["_alex_receiptdocumentid_value@OData.Community.Display.V1.FormattedValue" as keyof PaymentLine] || "");
            await this.maybeSaveCard(detail);
            await this.load2();
            await this.maybeCloseInvoice();
            this.execState = "success";
            this.busy = false;
            this.render();
        } catch (error) {
            this.busy = false;
            this.execState = "error";
            this.execTitle = this.t("החיוב לא הושלם", "The charge did not complete");
            this.execDetail = error instanceof Error ? error.message : String(error);
            this.render();
        }
    }

    private async load2(): Promise<void> {
        try {
            await this.loadPaymentLines();
            await this.loadAllocations();
            await this.syncCaseSummariesFromLoadedRows();
        } catch { /* keep result view even if refresh fails */ }
    }

    private async maybeCloseInvoice(): Promise<void> {
        this.invoiceClosed = false;
        await this.applyInvoiceSplit();
        if (this.paymentTotals().currentBalance > 0) return;
        const invoiceId = this.invoice?.invoiceid || (this.billingCase?.alex_sourceentitylogicalname === "invoice" ? this.billingCase.alex_sourceentityid : "");
        if (!invoiceId) return;
        try {
            await this.api().updateRecord("invoice", invoiceId, { statecode: 2, statuscode: 100001 });
            this.invoiceClosed = true;
        } catch { /* keep the receipt result even if closing the invoice fails */ }
    }

    private netUnitPrice(line: InvoiceLine): number {
        const quantity = Math.abs(Number(line.quantity || 0)) || 1;
        return this.roundMoney(Math.max(0, Number(line.extendedamount || 0)) / quantity);
    }

    private buildSplitDetail(invoiceId: string, line: InvoiceLine): Record<string, unknown> {
        const detail: Record<string, unknown> = {
            "invoiceid@odata.bind": `/invoices(${invoiceId})`,
            quantity: Math.abs(Number(line.quantity || 0)) || 1,
            ispriceoverridden: true,
            priceperunit: this.netUnitPrice(line)
        };
        const productId = String(line._productid_value || "");
        if (productId && !line.isproductoverridden) {
            detail["productid@odata.bind"] = `/products(${productId})`;
            detail.isproductoverridden = false;
            const uomId = String(line._uomid_value || "");
            if (uomId) detail["uomid@odata.bind"] = `/uoms(${uomId})`;
        } else {
            // Write-in product line: no product lookup, carry the description instead.
            detail.isproductoverridden = true;
            detail.productdescription = line.productname || line.productdescription || this.t("פריט", "Item");
        }
        return detail;
    }

    /**
     * Phase 4 — when the user opts in, move the unselected (unpaid) items to a brand-new
     * open D365 invoice, and reduce the original to only the paid items so it closes as "Paid".
     * Uses the already net-scaled line amounts so a discounted source invoice splits correctly.
     * Guarded to run only in partial mode with at least one paid and one unpaid item.
     */
    private async applyInvoiceSplit(): Promise<void> {
        if (!this.splitRemainder || this.payMode !== "partial") return;
        const invoiceId = this.invoice?.invoiceid || (this.billingCase?.alex_sourceentitylogicalname === "invoice" ? this.billingCase.alex_sourceentityid : "");
        if (!invoiceId || !this.lines.length) return;
        const selected = this.lines.filter((line) => this.selectedLineIds.has(line.invoicedetailid || ""));
        const unpaid = this.lines.filter((line) => !this.selectedLineIds.has(line.invoicedetailid || ""));
        if (!selected.length || !unpaid.length) return;
        const paidNet = this.roundMoney(selected.reduce((sum, line) => sum + Math.max(0, Number(line.extendedamount || 0)), 0));
        try {
            // 1) Create the new "balance" invoice for the unpaid items.
            const sourceName = this.invoice?.name || this.invoice?.invoicenumber || this.t("חשבונית", "Invoice");
            const newName = `${sourceName} - ${this.t("יתרה", "Balance")}`;
            const header: Record<string, unknown> = {
                name: newName,
                description: this.t(`יתרה שפוצלה מחשבונית ${this.invoice?.invoicenumber || ""}`, `Balance split from invoice ${this.invoice?.invoicenumber || ""}`)
            };
            if (this.customerContactId) header["customerid_contact@odata.bind"] = `/contacts(${this.customerContactId})`;
            else if (this.customerAccountId) header["customerid_account@odata.bind"] = `/accounts(${this.customerAccountId})`;
            const priceLevelId = String(this.invoice?._pricelevelid_value || "");
            if (priceLevelId) header["pricelevelid@odata.bind"] = `/pricelevels(${priceLevelId})`;
            const currencyId = String(this.invoice?._transactioncurrencyid_value || "");
            if (currencyId) header["transactioncurrencyid@odata.bind"] = `/transactioncurrencies(${currencyId})`;
            const created = await this.api().createRecord("invoice", header);
            const newInvoiceId = created.id;
            // 2) Add the unpaid items to the new invoice at their net amounts.
            for (const line of unpaid) {
                await this.api().createRecord("invoicedetail", this.buildSplitDetail(newInvoiceId, line));
            }
            // 3) Reduce the original invoice to the paid items only (unlock, drop unpaid, net-price the rest, clear discount).
            await this.api().updateRecord("invoice", invoiceId, { ispricelocked: false });
            for (const line of unpaid) {
                if (line.invoicedetailid) { try { await this.api().deleteRecord("invoicedetail", line.invoicedetailid); } catch { /* ignore */ } }
            }
            for (const line of selected) {
                if (line.invoicedetailid) await this.api().updateRecord("invoicedetail", line.invoicedetailid, { ispriceoverridden: true, priceperunit: this.netUnitPrice(line) });
            }
            await this.api().updateRecord("invoice", invoiceId, { discountamount: 0 });
            // 4) Realign the billing case + invoice totals so the original closes as fully paid.
            if (this.billingCase) {
                this.billingCase.alex_totalamount = paidNet;
                this.billingCase.alex_openbalance = 0;
                if (this.billingCase.alex_payplusbillingcaseid) {
                    try { await this.api().updateRecord("alex_payplusbillingcase", this.billingCase.alex_payplusbillingcaseid, { alex_totalamount: paidNet, alex_openbalance: 0, alex_amountdue: 0 }); } catch { /* ignore */ }
                }
            }
            if (this.invoice) this.invoice.totalamount = paidNet;
            this.lines = selected;
            this.splitOutcome = this.t(`הפריטים שלא סומנו הועברו לחשבונית D365 חדשה: ${newName}.`, `The unselected items were moved to a new D365 invoice: ${newName}.`);
        } catch {
            this.splitOutcome = this.t("פיצול היתרה לחשבונית חדשה נכשל. יש לטפל בכך ידנית ב-D365.", "Splitting the balance into a new invoice failed. Handle it manually in D365.");
        }
    }

    private brandCode(name: string): number {
        const value = (name || "").toString().toLowerCase();
        if (/^\d+$/.test(value)) return Number(value);
        if (value.indexOf("visa") >= 0) return 1;
        if (value.indexOf("master") >= 0 || value === "mc") return 2;
        if (value.indexOf("isracard") >= 0 || value === "ic") return 3;
        if (value.indexOf("american") >= 0 || value.indexOf("amex") >= 0) return 4;
        if (value.indexOf("diner") >= 0) return 5;
        if (value.indexOf("jcb") >= 0) return 6;
        if (value.indexOf("union") >= 0) return 7;
        if (value.indexOf("maestro") >= 0) return 8;
        if (value.indexOf("discover") >= 0) return 11;
        return 0;
    }

    private brandLabel(code: number): string {
        return ({ 1: "Visa", 2: "Mastercard", 3: "Isracard", 4: "American Express", 5: "Diners", 6: "JCB", 7: "UnionPay", 8: "Maestro", 11: "Discover" } as Record<number, string>)[code] || this.t("כרטיס אשראי", "Credit card");
    }

    private savedCardTitle(card: SavedCard): string {
        const code = Number(card.alex_brand || 0);
        const brand = code ? this.brandLabel(code) : "";
        const last4 = card.alex_last4 || "";
        if (brand && last4) return `${brand} •••• ${last4}`;
        return card.alex_name || (last4 ? `•••• ${last4}` : this.t("כרטיס שמור", "Saved card"));
    }

    private async maybeSaveCard(detail: unknown): Promise<void> {
        if (!this.saveCardChecked) return;
        const contactId = this.customerContactId;
        const accountId = this.customerAccountId;
        if (!contactId && !accountId) return;
        const tx = this.extractHostedTransaction(detail);
        if (!tx.token) return;
        const brandCode = this.brandCode(tx.brand);
        const display = `${brandCode ? this.brandLabel(brandCode) : this.t("כרטיס אשראי", "Credit card")} •••• ${tx.last4 || "????"}`;
        const card: Record<string, unknown> = {
            alex_name: display,
            alex_token: tx.token.substring(0, 200),
            alex_last4: tx.last4,
            alex_cardholdername: (this.pendingHolderName || "").substring(0, 100),
            alex_isactive: true,
            alex_isdefault: true,
            alex_channel: 100000000
        };
        if (brandCode) card.alex_brand = brandCode;
        if (tx.customerUid) card.alex_paypluscustomeruid = tx.customerUid.substring(0, 50);
        if (tx.expiryMonth) card.alex_expirymonth = tx.expiryMonth;
        if (tx.expiryYear) card.alex_expiryyear = tx.expiryYear;
        if (contactId) card["alex_Contact@odata.bind"] = `/contacts(${contactId})`;
        else if (accountId) card["alex_Account@odata.bind"] = `/accounts(${accountId})`;
        try {
            await this.api().createRecord("alex_creditcard", card);
            this.cardSaved = true;
        } catch { /* saving the card is best-effort and must not fail the receipt result */ }
    }

    private async chargeSavedCard(): Promise<void> {
        if (this.busy) return;
        const card = this.savedCards.find((row) => row.alex_creditcardid === this.selectedSavedCardId);
        if (!card?.alex_creditcardid) {
            this.statusText = this.t("יש לבחור כרטיס שמור לחיוב.", "Select a saved card to charge.");
            this.statusKind = "error";
            this.render();
            return;
        }
        this.busy = true;
        this.step = 3;
        this.execState = "running";
        this.execTitle = this.t("מבצע חיוב בכרטיס השמור מול PayPlus…", "Charging the saved card with PayPlus…");
        this.execDetail = this.t("החיוב נשלח בטוקן מאובטח. ממתין לאישור ולהפקת קבלה…", "The charge was submitted with a secure token. Waiting for approval and receipt issuance…");
        this.render();
        try {
            const paymentLineId = await this.createTokenPaymentLine(card);
            const finalized = await this.waitForReceiptFinalization(paymentLineId);
            this.receiptDocId = String(finalized._alex_receiptdocumentid_value || "");
            this.receiptLabel = String(finalized["_alex_receiptdocumentid_value@OData.Community.Display.V1.FormattedValue" as keyof PaymentLine] || "");
            await this.load2();
            await this.maybeCloseInvoice();
            this.execState = "success";
            this.busy = false;
            this.render();
        } catch (error) {
            this.busy = false;
            this.execState = "error";
            this.execTitle = this.t("החיוב לא הושלם", "The charge did not complete");
            this.execDetail = error instanceof Error ? error.message : String(error);
            this.render();
        }
    }

    private async createTokenPaymentLine(card: SavedCard): Promise<string> {
        if (!this.billingCase?.alex_payplusbillingcaseid) throw new Error(this.t("לא נמצא תיק גבייה לשמירת התשלום.", "No billing case was found for saving the payment."));
        this.amount = this.roundMoney(this.amount);
        if (!this.amount || this.amount <= 0) throw new Error(this.t("יש להזין סכום חיובי.", "Enter a positive amount."));
        const drafts = this.allocationDrafts();
        this.validateAllocationDrafts(drafts);
        const nowIso = new Date().toISOString();
        const userName = String((this.context.userSettings as unknown as { userName?: string }).userName || "PayPlus.PaymentWizard");
        const body: Record<string, unknown> = {
            alex_name: `${this.t("חיוב טוקן", "Token charge")} ${this.formatMoney(this.amount)}`,
            alex_sequence: this.paymentLines.length + 1,
            alex_chargemode: 100000002,
            alex_paymentmethod: 100000002,
            alex_status: PAYMENT_STATUS.draft,
            alex_amount: this.amount,
            alex_currencycode: this.billingCase.alex_currencycode || "ILS",
            alex_paymentdate: nowIso.substring(0, 10),
            alex_tokenchargeconfirmed: true,
            alex_tokenchargeconfirmedon: nowIso,
            alex_tokenchargeconfirmedby: userName.substring(0, 300),
            alex_notes: JSON.stringify({ createdBy: "PayPlus.PaymentWizard", method: "savedToken", creditCardId: card.alex_creditcardid, selectedInvoiceLineIds: drafts.map((draft) => draft.line.invoicedetailid || "").filter(Boolean) }),
            alex_requesteddocflow: this.requestedDocFlow,
            "alex_billingcaseid@odata.bind": `/alex_payplusbillingcases(${this.billingCase.alex_payplusbillingcaseid})`,
            "alex_creditcardid@odata.bind": `/alex_creditcards(${card.alex_creditcardid})`
        };
        if (card.alex_last4) body.alex_cardlast4 = card.alex_last4;
        if (card.alex_brand) body.alex_cardbrand = String(this.brandLabel(Number(card.alex_brand)));
        const created = await this.api().createRecord("alex_paypluspaymentline", body);
        const paymentLineId = created.id.replace(/[{}]/g, "").toLowerCase();
        await this.createAllocationRows(paymentLineId, drafts, ALLOCATION_STATUS.proposed);
        // The backend "Process Workbench Payment" flow triggers on UPDATE of alex_status (not create).
        // Create the line in draft first (with allocations), then flip to pendingExecution to fire the flow.
        await this.api().updateRecord("alex_paypluspaymentline", paymentLineId, { alex_status: PAYMENT_STATUS.pendingExecution });
        return paymentLineId;
    }

    private async recordBankTransfer(): Promise<void> {
        if (this.busy) return;
        if (!this.transferValid()) {
            this.statusText = this.t("יש להשלים את פרטי החשבון.", "Complete the account details.");
            this.statusKind = "error";
            this.render();
            return;
        }
        this.busy = true;
        this.step = 3;
        this.execState = "running";
        this.execTitle = this.t("רושם העברה בנקאית ומפיק קבלה…", "Recording the bank transfer and issuing a receipt…");
        this.execDetail = this.t("התשלום נרשם. ממתין להפקת קבלה מ-PayPlus…", "The payment was recorded. Waiting for PayPlus to issue the receipt…");
        this.render();
        try {
            const paymentLineId = await this.createBankTransferPaymentLine();
            const finalized = await this.waitForReceiptFinalization(paymentLineId);
            this.receiptDocId = String(finalized._alex_receiptdocumentid_value || "");
            this.receiptLabel = String(finalized["_alex_receiptdocumentid_value@OData.Community.Display.V1.FormattedValue" as keyof PaymentLine] || "");
            await this.load2();
            await this.maybeCloseInvoice();
            this.execState = "success";
            this.busy = false;
            this.render();
        } catch (error) {
            this.busy = false;
            this.execState = "error";
            this.execTitle = this.t("רישום ההעברה נכשל", "Recording the transfer failed");
            this.execDetail = error instanceof Error ? error.message : String(error);
            this.render();
        }
    }

    private async createBankTransferPaymentLine(): Promise<string> {
        if (!this.billingCase?.alex_payplusbillingcaseid) throw new Error(this.t("לא נמצא תיק גבייה לשמירת התשלום.", "No billing case was found for saving the payment."));
        this.amount = this.roundMoney(this.amount);
        if (!this.amount || this.amount <= 0) throw new Error(this.t("יש להזין סכום חיובי.", "Enter a positive amount."));
        const drafts = this.allocationDrafts();
        this.validateAllocationDrafts(drafts);
        let bankNumber = "";
        let branchNumber = "";
        let accountNumber = "";
        let bankAccountId = "";
        if (this.transferMode === "existing") {
            const account = this.customerBankAccounts.find((row) => row.alex_customerbankaccountid === this.selectedBankAccountId);
            if (!account) throw new Error(this.t("בחר חשבון בנק.", "Select a bank account."));
            bankAccountId = account.alex_customerbankaccountid || "";
            accountNumber = String(account.alex_accountnumber || "");
            bankNumber = account.alex_BankId?.alex_bankcode != null ? String(account.alex_BankId.alex_bankcode) : "";
            branchNumber = account.alex_BranchId?.alex_branchcode != null ? String(account.alex_BranchId.alex_branchcode) : "";
        } else {
            const bank = this.banks.find((row) => row.alex_bankid === this.tfBankId);
            const branch = this.branches.find((row) => row.alex_bankbranchid === this.tfBranchId);
            accountNumber = this.tfAccountNumber.trim();
            bankNumber = bank?.alex_bankcode != null ? String(bank.alex_bankcode) : "";
            branchNumber = branch?.alex_branchcode != null ? String(branch.alex_branchcode) : "";
            if (this.saveBankAccountChecked && (this.customerContactId || this.customerAccountId)) {
                bankAccountId = await this.createCustomerBankAccount(accountNumber, this.tfHolderName.trim());
            }
        }
        const nowIso = new Date().toISOString();
        const paymentDate = this.tfDate || nowIso.substring(0, 10);
        const reference = this.tfReference.trim();
        const body: Record<string, unknown> = {
            alex_name: `${this.t("העברה בנקאית", "Bank transfer")} ${this.formatMoney(this.amount)}`,
            alex_sequence: this.paymentLines.length + 1,
            alex_chargemode: 100000000,
            alex_paymentmethod: 100000003,
            alex_status: PAYMENT_STATUS.draft,
            alex_amount: this.amount,
            alex_currencycode: this.billingCase.alex_currencycode || "ILS",
            alex_paymentdate: paymentDate,
            alex_notes: JSON.stringify({ createdBy: "PayPlus.PaymentWizard", method: "bankTransfer", bankNumber, branchNumber, accountNumber, savedAccount: !!bankAccountId, selectedInvoiceLineIds: drafts.map((draft) => draft.line.invoicedetailid || "").filter(Boolean) }),
            alex_requesteddocflow: this.requestedDocFlow,
            "alex_billingcaseid@odata.bind": `/alex_payplusbillingcases(${this.billingCase.alex_payplusbillingcaseid})`
        };
        if (bankNumber) body.alex_banknumber = bankNumber.substring(0, 20);
        if (branchNumber) body.alex_branchnumber = branchNumber.substring(0, 20);
        if (accountNumber) body.alex_accountnumber = accountNumber.substring(0, 50);
        if (reference) { body.alex_banktransferreference = reference.substring(0, 200); body.alex_reference = reference.substring(0, 200); }
        if (bankAccountId) body["alex_customerbankaccountid@odata.bind"] = `/alex_customerbankaccounts(${bankAccountId})`;
        const created = await this.api().createRecord("alex_paypluspaymentline", body);
        const paymentLineId = created.id.replace(/[{}]/g, "").toLowerCase();
        await this.createAllocationRows(paymentLineId, drafts, ALLOCATION_STATUS.proposed);
        await this.api().updateRecord("alex_paypluspaymentline", paymentLineId, { alex_status: PAYMENT_STATUS.pendingExecution });
        return paymentLineId;
    }

    private async createCustomerBankAccount(accountNumber: string, holder: string): Promise<string> {
        const label = holder ? `${holder} · ${accountNumber}` : (accountNumber || this.t("חשבון בנק", "Bank account"));
        const body: Record<string, unknown> = {
            alex_name: label.substring(0, 200),
            alex_isactive: true,
            alex_isdefault: false,
            alex_isverified: false
        };
        if (accountNumber) body.alex_accountnumber = accountNumber.substring(0, 50);
        if (holder) body.alex_accountholdername = holder.substring(0, 200);
        if (this.tfBankId) body["alex_BankId@odata.bind"] = `/alex_banks(${this.tfBankId})`;
        if (this.tfBranchId) body["alex_BranchId@odata.bind"] = `/alex_bankbranchs(${this.tfBranchId})`;
        if (this.customerContactId) body["alex_ContactId@odata.bind"] = `/contacts(${this.customerContactId})`;
        if (this.customerAccountId) body["alex_AccountId@odata.bind"] = `/accounts(${this.customerAccountId})`;
        try {
            const created = await this.api().createRecord("alex_customerbankaccount", body);
            return created.id.replace(/[{}]/g, "").toLowerCase();
        } catch { return ""; }
    }

    private showHostedSubmitting(): void {
        const box = this.root.querySelector<HTMLElement>(".ppw-hfbox");
        if (!box) return;
        box.classList.add("submitting");
        let overlay = box.querySelector<HTMLDivElement>(".ppw-hf-overlay");
        if (!overlay) {
            overlay = document.createElement("div");
            overlay.className = "ppw-hf-overlay";
            const spinner = document.createElement("span");
            spinner.className = "ppw-spinner";
            const text = document.createElement("b");
            const sub = document.createElement("small");
            overlay.append(spinner, text, sub);
            box.appendChild(overlay);
        }
        const text = overlay.querySelector("b");
        const sub = overlay.querySelector("small");
        if (text) text.textContent = this.t("מבצע חיוב מאובטח", "Running secure charge");
        if (sub) sub.textContent = this.t("אין לסגור את החלון עד לקבלת תשובה מ-PayPlus.", "Keep this window open until PayPlus responds.");
    }

    private clearHostedSubmittingVisual(): void {
        const box = this.root.querySelector<HTMLElement>(".ppw-hfbox");
        box?.classList.remove("submitting");
        box?.querySelector(".ppw-hf-overlay")?.remove();
    }

    private clearHostedSubmitWatchdog(): void {
        if (!this.hostedSubmitTimeout) return;
        window.clearTimeout(this.hostedSubmitTimeout);
        this.hostedSubmitTimeout = 0;
    }

    private startHostedSubmitWatchdog(): void {
        this.clearHostedSubmitWatchdog();
        this.hostedSubmitTimeout = window.setTimeout(() => {
            if (!this.hostedSubmitting) return;
            void this.reloadHostedFieldsAfterFailure(this.t("לא התקבלה תשובה מ-PayPlus. השדות המאובטחים נטענים מחדש כדי לאפשר ניסיון חוזר.", "No response was received from PayPlus. Secure fields are reloading so you can try again."));
        }, 90000);
    }

    private resetHostedSession(message: string): void {
        this.clearHostedSubmitWatchdog();
        this.hfMountId++;
        this.hf = null;
        this.cardReady = false;
        this.hfHostedUid = "";
        this.hfPageRequestUid = "";
        this.hfSessionAmount = -1;
        this.busy = false;
        this.hostedSubmitting = false;
        if (this.step === 2) {
            this.showCardError(message);
            void this.ensureHostedMounted();
        }
    }

    private async reloadHostedFieldsAfterFailure(message: string): Promise<void> {
        this.clearHostedSubmitWatchdog();
        this.hfMountId++;
        this.hf = null;
        this.cardReady = false;
        this.hfHostedUid = "";
        this.hfPageRequestUid = "";
        this.hfSessionAmount = -1;
        this.hostedSubmitting = false;
        this.busy = false;
        this.clearHostedSubmittingVisual();
        this.showCardError(message);
        this.updateFooter();
        await this.ensureHostedMounted();
    }

    /* -------------------- Wizard navigation -------------------- */

    private goStep(next: number): void {
        if (this.busy) return;
        if (this.step === 2 && next !== 2) {
            this.hfMountId++;
            this.hf = null;
            this.cardReady = false;
            this.hfHostedUid = "";
            this.hfPageRequestUid = "";
            this.hfSessionAmount = -1;
        }
        this.step = next;
        this.statusText = "";
        this.render();
        if (next === 2 && this.payMethod === "card") void this.ensureHostedMounted();
    }

    private setPayMode(mode: PayMode): void {
        this.payMode = mode;
        if (mode === "full") {
            this.splitRemainder = false;
            this.selectedLineIds = new Set(this.lines.map((line) => line.invoicedetailid || "").filter(Boolean));
            this.allocationAmounts.clear();
            this.amount = this.openBalance();
        }
        this.render();
    }

    private setSplitRemainder(checked: boolean): void {
        this.splitRemainder = checked;
        if (checked) {
            // Split mode is whole-item only: each selected line pays its full net amount.
            this.allocationAmounts.clear();
            this.selectedLineIds.forEach((id) => {
                const line = this.lines.find((row) => row.invoicedetailid === id);
                if (line) this.allocationAmounts.set(id, this.roundMoney(Number(line.extendedamount || 0)));
            });
            this.amount = this.allocatedTotal();
        }
        this.render();
    }

    private setRequestedDocFlow(value: number): void {
        if (!this.allowDocOverride || this.hasTaxInvoice) return;
        this.requestedDocFlow = value;
        this.render();
    }

    private setPayMethod(method: PayMethod): void {
        if (this.payMethod === method) return;
        this.payMethod = method;
        this.statusText = "";
        if (method === "bank") this.initTransferDefaults();
        if (method === "check") this.initCheckDefaults();
        this.render();
        if (method === "card") void this.ensureHostedMounted();
    }

    private initTransferDefaults(): void {
        if (!this.tfDate) this.tfDate = new Date().toISOString().substring(0, 10);
        if (!this.tfHolderName) this.tfHolderName = String(this.billingCase?.alex_customername || "");
        this.transferMode = this.customerBankAccounts.length > 0 ? "existing" : "new";
    }

    private setTransferMode(mode: TransferMode): void {
        if (this.transferMode === mode) return;
        this.transferMode = mode;
        this.statusText = "";
        this.render();
    }

    private selectBankAccount(id: string): void {
        if (!id) return;
        this.selectedBankAccountId = id;
        this.statusText = "";
        this.render();
    }

    private async onTransferBankChange(bankId: string): Promise<void> {
        this.tfBankId = bankId;
        this.tfBranchId = "";
        this.branches = [];
        this.branchesLoading = !!bankId;
        this.render();
        if (!bankId) return;
        await this.loadBranchesForBank(bankId);
        this.branchesLoading = false;
        if ((this.payMethod === "bank" || this.payMethod === "check") && this.transferMode === "new") this.render();
    }

    private transferValid(): boolean {
        if (this.transferMode === "existing") {
            if (!this.selectedBankAccountId || this.customerBankAccounts.length === 0) return false;
        } else if (!this.tfBankId || !this.tfBranchId || !this.tfAccountNumber.trim()) {
            return false;
        }
        return this.currentTransferAccountStatus() !== "invalid";
    }

    private currentTransferAccountStatus(): "valid" | "invalid" | "unknown" {
        let bankCode = NaN;
        let branchCode = NaN;
        let accStr = "";
        if (this.transferMode === "existing") {
            const account = this.customerBankAccounts.find((row) => row.alex_customerbankaccountid === this.selectedBankAccountId);
            if (!account) return "unknown";
            if (account.alex_BankId?.alex_bankcode != null) bankCode = account.alex_BankId.alex_bankcode;
            if (account.alex_BranchId?.alex_branchcode != null) branchCode = account.alex_BranchId.alex_branchcode;
            accStr = String(account.alex_accountnumber || "");
        } else {
            const bank = this.banks.find((row) => row.alex_bankid === this.tfBankId);
            const branch = this.branches.find((row) => row.alex_bankbranchid === this.tfBranchId);
            if (bank?.alex_bankcode != null) bankCode = bank.alex_bankcode;
            if (branch?.alex_branchcode != null) branchCode = branch.alex_branchcode;
            accStr = this.tfAccountNumber.trim();
        }
        if (!Number.isFinite(bankCode) || !Number.isFinite(branchCode) || !accStr) return "unknown";
        return this.israeliBankAccountStatus(bankCode, branchCode, accStr);
    }

    // Validates an Israeli bank account number using the per-bank check-digit rules.
    // Returns "invalid" only when the bank is recognised AND the number fails its check,
    // "valid" when it passes, and "unknown" for unsupported/legacy banks (do not block).
    private israeliBankAccountStatus(bankCode: number, branchCodeRaw: number, accountRaw: string): "valid" | "invalid" | "unknown" {
        const accStr = String(accountRaw || "").replace(/\D/g, "");
        if (!Number.isInteger(bankCode) || bankCode < 0) return "unknown";
        if (!Number.isInteger(branchCodeRaw) || branchCodeRaw < 0) return "unknown";
        if (!accStr) return "unknown";
        const account = Number(accStr);
        let branch = branchCodeRaw;
        const LEUMI = 10, IGUD = 13, ARAVEI = 34, YAHAV = 4, MIZRAHI = 20, HAPOALIM = 12,
            DISCOUNT = 11, MERCANTILE = 17, BEINLEUMI = 31, POALEI_AGUDAT = 52,
            POST = 9, CITIBANK = 22, OTSAR = 14, MASAD = 46, JERUSALEM = 54;
        const supported = [LEUMI, IGUD, ARAVEI, YAHAV, MIZRAHI, HAPOALIM, DISCOUNT, MERCANTILE, BEINLEUMI, POALEI_AGUDAT, POST, CITIBANK, OTSAR, MASAD, JERUSALEM];
        if (supported.indexOf(bankCode) === -1) return "unknown";
        if (bankCode === MIZRAHI && branch > 400) branch -= 400;
        const toDigits = (num: number, len: number): number[] => {
            const arr: number[] = [];
            let n = num;
            for (let i = 0; i < len; i++) { arr.push(n % 10); n = Math.floor(n / 10); }
            return arr;
        };
        const dot = (a: number[], b: number[]): number => {
            let p = 0;
            for (let i = 0; i < a.length && i < b.length; i++) p += a[i] * b[i];
            return p;
        };
        const has = (arr: number[], v: number): boolean => arr.indexOf(v) !== -1;
        const acc = toDigits(account, 9);
        const br = toDigits(branch, 3);
        const ok = (passed: boolean): "valid" | "invalid" => (passed ? "valid" : "invalid");
        let sum = 0;
        let rem = 0;
        switch (bankCode) {
            case LEUMI:
            case IGUD:
            case ARAVEI:
                sum = dot(acc.slice(0, 8), [1, 10, 2, 3, 4, 5, 6, 7]);
                sum += dot(br.slice(0, 4), [8, 9, 10]);
                rem = sum % 100;
                return ok(has([90, 72, 70, 60, 20], rem));
            case YAHAV:
            case MIZRAHI:
            case HAPOALIM:
                sum = dot(acc.slice(0, 6), [1, 2, 3, 4, 5, 6]);
                sum += dot(br.slice(0, 4), [7, 8, 9]);
                rem = sum % 11;
                if (bankCode === YAHAV) return ok(has([0, 2], rem));
                if (bankCode === MIZRAHI) return ok(has([0, 2, 4], rem));
                return ok(has([0, 2, 4, 6], rem));
            case DISCOUNT:
            case MERCANTILE:
            case BEINLEUMI:
            case POALEI_AGUDAT:
                sum = dot(acc.slice(0, 9), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
                rem = sum % 11;
                if (bankCode === DISCOUNT || bankCode === MERCANTILE) return ok(has([0, 2, 4], rem));
                if (has([0, 6], rem)) return "valid";
                sum = dot(acc.slice(0, 6), [1, 2, 3, 4, 5, 6]);
                rem = sum % 11;
                return ok(has([0, 6], rem));
            case POST:
                sum = dot(acc.slice(0, 9), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
                rem = sum % 10;
                return ok(rem === 0);
            case JERUSALEM:
                return "valid";
            case CITIBANK:
                sum = dot(acc.slice(1, 9), [2, 3, 4, 5, 6, 7, 2, 3]);
                return ok((11 - (sum % 11)) === acc[0]);
            case OTSAR:
            case MASAD: {
                sum = dot(acc.slice(0, 6), [1, 2, 3, 4, 5, 6]);
                sum += dot(br.slice(0, 4), [7, 8, 9]);
                rem = sum % 11;
                if (rem === 0) return "valid";
                if (bankCode === MASAD) {
                    if (rem === 2 && has([154, 166, 178, 181, 183, 191, 192, 503, 505, 507, 515, 516, 527, 539], branch)) return "valid";
                    sum = dot(acc.slice(0, 9), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
                    rem = sum % 11;
                    if (rem === 0) return "valid";
                    sum = dot(acc.slice(0, 6), [1, 2, 3, 4, 5, 6]);
                    rem = sum % 11;
                    return ok(rem === 0);
                }
                if (has([0, 2], rem) && has([385, 384, 365, 347, 363, 362, 361], branch)) return "valid";
                if (rem === 4 && has([363, 362, 361], branch)) return "valid";
                sum = dot(acc.slice(0, 9), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
                rem = sum % 11;
                if (rem === 0) return "valid";
                sum = dot(acc.slice(0, 6), [1, 2, 3, 4, 5, 6]);
                rem = sum % 11;
                return ok(rem === 0);
            }
            default:
                return "unknown";
        }
    }

    private selectSavedCard(id: string): void {
        if (!id) return;
        this.selectedSavedCardId = id;
        this.statusText = "";
        this.render();
    }

    private onNext(): void {
        if (this.step === 1) {
            if (this.payMode === "partial") this.amount = this.allocatedTotal();
            if (!this.amount || this.amount <= 0) { this.statusText = this.t("יש לבחור סכום לגבייה.", "Choose an amount to collect."); this.statusKind = "error"; this.render(); return; }
            this.goStep(2);
            return;
        }
        if (this.step === 2) {
            if (this.payMethod === "saved") void this.chargeSavedCard();
            else if (this.payMethod === "bank") void this.recordBankTransfer();
            else if (this.payMethod === "check") void this.recordChecks();
            else this.submitHostedFields();
            return;
        }
        if (this.step === 3 && this.execState === "success") {
            this.resetForNewPayment();
        }
    }

    private onBack(): void {
        if (this.step === 2) { this.goStep(1); return; }
        if (this.step === 3 && this.execState === "error") { this.goStep(2); return; }
    }

    private resetForNewPayment(): void {
        this.step = 1;
        this.payMode = "full";
        this.payMethod = "card";
        this.saveCardChecked = false;
        this.cardSaved = false;
        this.transferMode = "new";
        this.selectedBankAccountId = "";
        this.tfBankId = "";
        this.tfBranchId = "";
        this.tfAccountNumber = "";
        this.tfHolderName = "";
        this.tfReference = "";
        this.tfDate = "";
        this.saveBankAccountChecked = false;
        this.branches = [];
        this.branchesLoading = false;
        this.checkSeriesMode = "single";
        this.checkCount = 3;
        this.checkStartNumber = "";
        this.checkFirstDate = "";
        this.checks = [];
        this.checksInitialized = false;
        this.execState = "idle";
        this.execTitle = "";
        this.execDetail = "";
        this.splitRemainder = false;
        this.splitOutcome = "";
        this.receiptDocId = "";
        this.receiptLabel = "";
        this.hfMountId++;
        this.hf = null;
        this.cardReady = false;
        this.hfHostedUid = "";
        this.hfPageRequestUid = "";
        this.hfSessionAmount = -1;
        void this.load();
    }

    private finishWizard(): void {
        const parentXrm = (window.parent as unknown as { Xrm?: { Navigation?: { navigateBack?: () => Promise<unknown> } } }).Xrm;
        const localXrm = (window as unknown as { Xrm?: { Navigation?: { navigateBack?: () => Promise<unknown> } } }).Xrm;
        try { void (parentXrm || localXrm)?.Navigation?.navigateBack?.(); } catch { /* dialog may already be closing */ }
    }

    private sendActionsHtml(): string {
        const channels = [
            { code: 100000000, label: this.t("דוא\"ל", "Email"), icon: this.iconMail() },
            { code: 100000001, label: this.t("SMS", "SMS"), icon: this.iconSms() },
            { code: 100000002, label: "WhatsApp", icon: this.iconWhatsapp() }
        ];
        const buttons = channels.map((channel) => {
            const sent = this.sentChannels.has(channel.code);
            return `<button class="ppw-send-btn ${sent ? "sent" : ""}" data-send-channel="${channel.code}">${sent ? this.checkIcon() : channel.icon}<span>${this.e(sent ? this.t("נשלח", "Sent") : channel.label)}</span></button>`;
        }).join("");
        return `<div class="ppw-send">
            <div class="ppw-send-title">${this.e(this.t("שליחת עותק ללקוח", "Send a copy to the customer"))}</div>
            <div class="ppw-send-row">${buttons}</div>
            <div class="ppw-send-note" data-send-note></div>
        </div>`;
    }

    private channelLabel(channel: number): string {
        if (channel === 100000001) return this.t("SMS", "SMS");
        if (channel === 100000002) return "WhatsApp";
        return this.t("דוא\"ל", "email");
    }

    private async sendReceiptCopy(channel: number): Promise<void> {
        if (!this.receiptDocId) return;
        const note = this.root.querySelector<HTMLElement>("[data-send-note]");
        const label = this.channelLabel(channel);
        if (note) { note.className = "ppw-send-note"; note.textContent = this.t(`שולח עותק ב${label}…`, `Sending a copy via ${label}…`); }
        try {
            await this.api().updateRecord("alex_payplusdocument", this.receiptDocId, {
                alex_requestedaction: 100000000,
                alex_requestedchannel: channel,
                alex_requestedlinktype: 100000001,
                alex_requestedactionstatus: 100000000,
                alex_requestedactionon: new Date().toISOString()
            });
            this.sentChannels.add(channel);
            const button = this.root.querySelector<HTMLButtonElement>(`[data-send-channel='${channel}']`);
            if (button) { button.classList.add("sent"); button.innerHTML = `${this.checkIcon()}<span>${this.e(this.t("נשלח", "Sent"))}</span>`; }
            if (note) { note.className = "ppw-send-note ok"; note.textContent = this.t(`בקשת שליחת עותק ב${label} נשלחה ללקוח.`, `A copy request via ${label} was sent to the customer.`); }
        } catch (error) {
            if (note) { note.className = "ppw-send-note err"; note.textContent = error instanceof Error ? error.message : String(error); }
        }
    }

    /* -------------------- Render -------------------- */

    private render(): void {
        const body = this.root.querySelector<HTMLElement>(".ppw-body");
        const scrollTop = body ? body.scrollTop : 0;
        const prevStep = this.paneAnimateStep;
        this.root.innerHTML = this.html();
        this.bind();
        if (prevStep === this.step && scrollTop) {
            const newBody = this.root.querySelector<HTMLElement>(".ppw-body");
            if (newBody) newBody.scrollTop = scrollTop;
        }
    }

    private bind(): void {
        this.root.querySelector<HTMLButtonElement>("[data-action='retry']")?.addEventListener("click", () => void this.load());
        this.root.querySelectorAll<HTMLElement>("[data-scope]").forEach((element) => element.addEventListener("click", () => this.setPayMode(element.dataset.scope as PayMode)));
        this.root.querySelectorAll<HTMLElement>("[data-docflow]").forEach((element) => element.addEventListener("click", () => this.setRequestedDocFlow(Number(element.dataset.docflow || 0))));
        this.root.querySelectorAll<HTMLElement>("[data-method]").forEach((element) => element.addEventListener("click", () => this.setPayMethod(element.dataset.method as PayMethod)));
        this.root.querySelectorAll<HTMLElement>("[data-saved-card]").forEach((element) => element.addEventListener("click", () => this.selectSavedCard(element.dataset.savedCard || "")));
        this.root.querySelector<HTMLInputElement>("[data-save-card]")?.addEventListener("change", (event) => { this.saveCardChecked = (event.target as HTMLInputElement).checked; });
        this.root.querySelectorAll<HTMLElement>("[data-tfmode]").forEach((element) => element.addEventListener("click", () => this.setTransferMode(element.dataset.tfmode as TransferMode)));
        this.root.querySelectorAll<HTMLElement>("[data-bank-account]").forEach((element) => element.addEventListener("click", () => this.selectBankAccount(element.dataset.bankAccount || "")));
        this.bindCombo("tf-bank", this.tfBankLabel(), (value) => void this.onTransferBankChange(value));
        this.bindCombo("tf-branch", this.tfBranchLabel(), (value) => { this.tfBranchId = value; this.statusText = ""; this.render(); });
        this.root.querySelector<HTMLInputElement>("[data-tf-account]")?.addEventListener("input", (event) => { this.tfAccountNumber = (event.target as HTMLInputElement).value; this.updateFooter(); });
        this.root.querySelector<HTMLInputElement>("[data-tf-holder]")?.addEventListener("input", (event) => { this.tfHolderName = (event.target as HTMLInputElement).value; });
        this.root.querySelector<HTMLInputElement>("[data-tf-reference]")?.addEventListener("input", (event) => { this.tfReference = (event.target as HTMLInputElement).value; });
        this.root.querySelector<HTMLInputElement>("[data-tf-date]")?.addEventListener("input", (event) => { this.tfDate = (event.target as HTMLInputElement).value; });
        this.root.querySelector<HTMLInputElement>("[data-tf-save]")?.addEventListener("change", (event) => { this.saveBankAccountChecked = (event.target as HTMLInputElement).checked; });
        this.root.querySelectorAll<HTMLElement>("[data-check-mode]").forEach((element) => element.addEventListener("click", () => this.setCheckMode(element.dataset.checkMode as CheckSeriesMode)));
        this.root.querySelector<HTMLButtonElement>("[data-check-count-dec]")?.addEventListener("click", () => this.setCheckCount(this.desiredCheckCount() - 1));
        this.root.querySelector<HTMLButtonElement>("[data-check-count-inc]")?.addEventListener("click", () => this.setCheckCount(this.desiredCheckCount() + 1));
        this.root.querySelector<HTMLInputElement>("[data-check-count-input]")?.addEventListener("change", (event) => this.setCheckCount(parseInt((event.target as HTMLInputElement).value, 10) || 1));
        this.root.querySelector<HTMLInputElement>("[data-check-start]")?.addEventListener("input", (event) => { this.checkStartNumber = (event.target as HTMLInputElement).value; });
        this.root.querySelector<HTMLInputElement>("[data-check-firstdate]")?.addEventListener("change", (event) => { this.checkFirstDate = (event.target as HTMLInputElement).value; this.applyDateSequence(); this.redrawChecks(); });
        this.root.querySelector<HTMLButtonElement>("[data-check-fill]")?.addEventListener("click", () => { this.applyStartNumbers(); this.applyDateSequence(); this.redrawChecks(); });
        this.bindCheckRows();
        this.root.querySelector<HTMLButtonElement>("[data-action='next']")?.addEventListener("click", () => this.onNext());
        this.root.querySelector<HTMLButtonElement>("[data-action='back']")?.addEventListener("click", () => this.onBack());
        this.root.querySelector<HTMLButtonElement>("[data-action='finish']")?.addEventListener("click", () => this.finishWizard());
        this.root.querySelectorAll<HTMLElement>("[data-send-channel]").forEach((element) => element.addEventListener("click", () => void this.sendReceiptCopy(Number(element.dataset.sendChannel || 0))));
        this.root.querySelectorAll<HTMLElement>("[data-line-toggle]").forEach((element) => element.addEventListener("click", () => this.toggleLine(element.dataset.lineToggle || "")));
        this.root.querySelector<HTMLElement>("[data-action='toggleAll']")?.addEventListener("click", () => this.toggleAllLines());
        this.root.querySelector<HTMLInputElement>("[data-split-remainder]")?.addEventListener("change", (event) => this.setSplitRemainder((event.target as HTMLInputElement).checked));
        this.root.querySelectorAll<HTMLInputElement>("[data-alloc-line]").forEach((input) => input.addEventListener("change", () => this.onAllocInput(input)));
    }

    private toggleLine(id: string): void {
        if (!id) return;
        if (this.selectedLineIds.has(id)) { this.selectedLineIds.delete(id); this.allocationAmounts.delete(id); }
        else {
            this.selectedLineIds.add(id);
            const line = this.lines.find((row) => row.invoicedetailid === id);
            if (line) this.allocationAmounts.set(id, this.roundMoney(Number(line.extendedamount || 0)));
        }
        this.amount = this.allocatedTotal();
        this.render();
    }

    private toggleAllLines(): void {
        const allSelected = this.lines.every((line) => this.selectedLineIds.has(line.invoicedetailid || ""));
        if (allSelected) { this.selectedLineIds.clear(); this.allocationAmounts.clear(); }
        else {
            this.selectedLineIds = new Set(this.lines.map((line) => line.invoicedetailid || "").filter(Boolean));
            this.allocationAmounts.clear();
            this.lines.forEach((line) => this.allocationAmounts.set(line.invoicedetailid || "", this.roundMoney(Number(line.extendedamount || 0))));
        }
        this.amount = this.allocatedTotal();
        this.render();
    }

    private onAllocInput(input: HTMLInputElement): void {
        if (this.splitRemainder) return;
        const id = input.dataset.allocLine || "";
        const value = Math.max(0, Number(input.value || 0));
        this.allocationAmounts.set(id, value);
        if (value > 0) this.selectedLineIds.add(id); else this.selectedLineIds.delete(id);
        this.amount = this.allocatedTotal();
        this.updatePartialTotals();
        this.updateFooter();
    }

    private updatePartialTotals(): void {
        const total = this.allocatedTotal();
        const count = this.allocationDrafts().length;
        const countEl = this.root.querySelector("[data-alloc-count]");
        const totalEl = this.root.querySelector("[data-alloc-total]");
        if (countEl) countEl.textContent = this.t(`${count} פריטים נבחרו`, `${count} items selected`);
        if (totalEl) totalEl.textContent = this.formatMoney(total);
    }

    private markCardReady(): void {
        this.cardReady = true;
        const box = this.root.querySelector<HTMLElement>("#ppw-hfbox");
        if (box) { box.classList.remove("loading"); box.classList.add("ready"); }
        const note = this.root.querySelector<HTMLElement>("[data-card-note]");
        if (note) {
            note.className = "ppw-note";
            note.textContent = this.t("החיבור המאובטח ל-PayPlus מוכן. ניתן להזין פרטי כרטיס וללחוץ על ״בצע תשלום״.", "The secure PayPlus connection is ready. Enter the card details and select \u201cCharge\u201d.");
        }
        this.updateFooter();
    }

    private showCardLoading(message: string): void {
        const box = this.root.querySelector<HTMLElement>("#ppw-hfbox");
        if (box) { box.classList.remove("ready"); box.classList.add("loading"); }
        const label = this.root.querySelector<HTMLElement>("#ppw-hf-loading span.ppw-hf-loadingtext");
        if (label) label.textContent = message;
        this.updateFooter();
    }

    private showCardError(message: string): void {
        const note = this.root.querySelector<HTMLElement>("[data-card-note]");
        if (note) { note.className = "ppw-note err"; note.textContent = message; }
        const box = this.root.querySelector<HTMLElement>("#ppw-hfbox");
        box?.classList.remove("loading");
    }

    private updateExecDetail(): void {
        const detail = this.root.querySelector("[data-exec-detail]");
        if (detail) detail.textContent = this.execDetail;
    }

    private updateFooter(): void {
        const footer = this.root.querySelector(".ppw-footer");
        if (!footer) return;
        footer.outerHTML = this.footerHtml();
        this.root.querySelector<HTMLButtonElement>("[data-action='next']")?.addEventListener("click", () => this.onNext());
        this.root.querySelector<HTMLButtonElement>("[data-action='back']")?.addEventListener("click", () => this.onBack());
        this.root.querySelector<HTMLButtonElement>("[data-action='finish']")?.addEventListener("click", () => this.finishWizard());
    }

    private updateCheckTotals(): void {
        const total = this.checksTotal();
        const due = this.roundMoney(this.amount);
        const balanced = total === due;
        const foot = this.root.querySelector<HTMLElement>(".ppw-chk-foot");
        if (foot) {
            foot.classList.toggle("warn", !balanced);
            const strong = foot.querySelector("strong");
            if (strong) strong.textContent = balanced ? this.formatMoney(total) : `${this.formatMoney(total)} / ${this.formatMoney(due)}`;
        }
        this.updateFooter();
    }

    private html(): string {
        if (this.loading) return this.shellHtml(`<div class="ppw-center"><span class="ppw-spinner big"></span><div class="ppw-center-t">${this.e(this.t("טוען נתוני גבייה…", "Loading billing data…"))}</div></div>`, false);
        if (this.loadError) return this.shellHtml(`<div class="ppw-center"><div class="ppw-center-t err">${this.e(this.loadError)}</div><button class="ppw-btn ghost" data-action="retry">${this.e(this.t("נסה שוב", "Retry"))}</button></div>`, false);
        const animate = this.paneAnimateStep !== this.step;
        this.paneAnimateStep = this.step;
        return this.shellHtml(this.bodyHtml(), true, animate);
    }

    private shellHtml(inner: string, withChrome: boolean, animate = false): string {
        return `<div class="ppw-win">${withChrome ? this.headerHtml() + this.stepperHtml() : ""}<div class="ppw-body${animate ? " ppw-animate" : ""}">${inner}</div>${withChrome ? this.footerHtml() : ""}</div>`;
    }

    private headerHtml(): string {
        const totals = this.paymentTotals();
        const customer = this.billingCase?.alex_customername || this.billingCase?.alex_sourcedisplayname || this.t("לקוח", "Customer");
        const source = this.invoice?.invoicenumber ? this.t(`חשבונית ${this.invoice.invoicenumber}`, `Invoice ${this.invoice.invoicenumber}`) : (this.billingCase?.alex_sourcedisplayname || "");
        const expected = this.roundMoney(Math.max(0, totals.currentBalance - this.amount));
        return `<header class="ppw-head">
            <div class="ppw-eyebrow">${this.e(this.t("אירוע גבייה", "Collection event"))}</div>
            <h1>${this.e(customer)}${source ? ` <span class="ppw-cust">· ${this.e(source)}</span>` : ""}</h1>
            <div class="ppw-balances">
                <div class="ppw-bal"><div class="k">${this.e(this.t("יתרה לתשלום", "Balance due"))}</div><div class="v">${this.e(this.formatMoney(totals.currentBalance))}</div></div>
                <div class="ppw-bal"><div class="k">${this.e(this.t("מתוכנן לגבייה", "Planned to collect"))}</div><div class="v" data-hdr-planned>${this.e(this.formatMoney(this.amount))}</div></div>
                <div class="ppw-bal green"><div class="k">${this.e(this.t("יתרה צפויה", "Expected balance"))}</div><div class="v" data-hdr-expected>${this.e(this.formatMoney(expected))}</div></div>
            </div>
        </header>`;
    }

    private stepperHtml(): string {
        const steps = [this.t("פריטים לתשלום", "Items"), this.t("אמצעי תשלום", "Payment method"), this.t("ביצוע ותוצאה", "Execute & result")];
        const cells = steps.map((label, index) => {
            const num = index + 1;
            const cls = num === this.step ? "active" : num < this.step ? "done" : "";
            const inner = num < this.step ? "\u2713" : String(num);
            return `<div class="ppw-step ${cls}"><span class="num">${inner}</span><span class="lab">${this.e(label)}</span></div>`;
        }).join('<span class="ppw-step-sep"></span>');
        return `<nav class="ppw-stepper">${cells}</nav>`;
    }

    private bodyHtml(): string {
        if (this.step === 1) return this.step1Html();
        if (this.step === 2) return this.step2Html();
        return this.step3Html();
    }

    private step1Html(): string {
        const status = this.statusText ? `<div class="ppw-note err">${this.e(this.statusText)}</div>` : "";
        const full = this.payMode === "full";
        const drafts = this.allocationDrafts();
        const summary = full
            ? `<div class="ppw-summary-line"><span>${this.e(this.t(`${drafts.length} פריטים בקבלה`, `${drafts.length} receipt items`))}</span><span class="sv">${this.e(this.formatMoney(this.openBalance()))}</span></div>`
            : this.partialTableHtml();
        return `<div class="ppw-pane">
            <div class="ppw-sec-title">${this.e(this.t("על מה הלקוח משלם", "What is the customer paying for"))}</div>
            <div class="ppw-sec-sub">${this.e(this.t("כברירת מחדל נגבית מלוא יתרת החשבונית. פירוט פריטים נדרש רק לתשלום חלקי.", "By default the full invoice balance is collected. Item detail is only needed for a partial payment."))}</div>
            <div class="ppw-choices">
                <div class="ppw-choice ${full ? "sel" : ""}" data-scope="full">
                    <div class="ct"><span class="radio"></span>${this.e(this.t("תשלום מלא", "Full payment"))}</div>
                    <div class="cs">${this.e(this.t(`גביית מלוא היתרה — ${this.formatMoney(this.openBalance())}`, `Collect the full balance — ${this.formatMoney(this.openBalance())}`))}</div>
                </div>
                <div class="ppw-choice ${full ? "" : "sel"}" data-scope="partial">
                    <div class="ct"><span class="radio"></span>${this.e(this.t("תשלום חלקי", "Partial payment"))}</div>
                    <div class="cs">${this.e(this.t("בחירת פריטים וסכומים לקבלה", "Choose items and amounts for the receipt"))}</div>
                </div>
            </div>
            ${summary}
            ${this.docChoiceHtml()}
            ${status}
        </div>`;
    }

    private partialTableHtml(): string {
        if (!this.lines.length) return `<div class="ppw-note">${this.e(this.t("אין פריטי חשבונית להצגה. ייגבה הסכום המלא.", "No invoice items to display. The full amount will be collected."))}</div>`;
        const allSelected = this.lines.every((line) => this.selectedLineIds.has(line.invoicedetailid || ""));
        const someSelected = this.lines.some((line) => this.selectedLineIds.has(line.invoicedetailid || ""));
        const headChk = allSelected ? "on" : someSelected ? "mixed" : "";
        const rows = this.lines.map((line) => {
            const id = line.invoicedetailid || "";
            const on = this.selectedLineIds.has(id);
            const open = this.roundMoney(Number(line.extendedamount || 0));
            const value = this.allocationAmounts.has(id) ? this.moneyInputValue(Number(this.allocationAmounts.get(id) || 0)) : this.moneyInputValue(open);
            const name = line.productname || line.productdescription || this.t("פריט", "Item");
            const sub = line.productdescription && line.productname ? line.productdescription : "";
            return `<div class="ppw-item-row ${on ? "" : "off"}">
                <span class="ppw-chk ${on ? "on" : ""}" data-line-toggle="${this.e(id)}">${this.checkIcon()}</span>
                <div class="nm">${this.e(name)}${sub ? `<small>${this.e(sub)}</small>` : ""}</div>
                <div class="open">${this.e(this.formatMoney(open))}</div>
                <input class="ppw-amt-input" data-alloc-line="${this.e(id)}" value="${this.e(value)}" ${on && !this.splitRemainder ? "" : "disabled"} />
            </div>`;
        }).join("");
        const count = this.allocationDrafts().length;
        const unpaidCount = this.lines.filter((line) => !this.selectedLineIds.has(line.invoicedetailid || "")).length;
        const splitHint = this.splitRemainder
            ? this.t(`${unpaidCount} פריטים שלא סומנו יעברו לחשבונית D365 חדשה ופתוחה. חשבונית זו תיסגר כ״שולם״.`, `${unpaidCount} unselected items will move to a new open D365 invoice. This invoice will close as \u201cPaid\u201d.`)
            : this.t("סמן כדי לפצל את הפריטים שלא שולמו לחשבונית נפרדת במקום להשאיר את החשבונית פתוחה.", "Select to split the unpaid items into a separate invoice instead of leaving this invoice open.");
        const splitOpt = `<label class="ppw-split-opt ${this.splitRemainder ? "on" : ""}">
            <input type="checkbox" data-split-remainder ${this.splitRemainder ? "checked" : ""} />
            <span class="txt"><strong>${this.e(this.t("פצל את היתרה לחשבונית D365 חדשה", "Split the balance into a new D365 invoice"))}</strong><small>${this.e(splitHint)}</small></span>
        </label>`;
        return `<div class="ppw-items">
            <div class="ppw-items-head">
                <span class="ppw-chk ${headChk}" data-action="toggleAll">${this.checkIcon()}</span>
                <span>${this.e(this.t("פריט", "Item"))}</span><span>${this.e(this.t("יתרה פתוחה", "Open balance"))}</span><span>${this.e(this.t("סכום בקבלה", "Receipt amount"))}</span>
            </div>
            ${rows}
            <div class="ppw-items-foot"><span data-alloc-count>${this.e(this.t(`${count} פריטים נבחרו`, `${count} items selected`))}</span><strong data-alloc-total>${this.e(this.formatMoney(this.allocatedTotal()))}</strong></div>
        </div>
        ${splitOpt}`;
    }

    private step2Html(): string {
        const hasCustomer = !!(this.customerContactId || this.customerAccountId);
        const savedOn = this.savedCards.length > 0;
        const methods = [
            { key: "card", label: this.t("כרטיס חדש", "New card"), icon: this.iconCard(), on: true },
            { key: "saved", label: this.t("כרטיס שמור", "Saved card"), icon: this.iconSaved(), on: savedOn },
            { key: "bank", label: this.t("העברה", "Transfer"), icon: this.iconBank(), on: true },
            { key: "check", label: this.t("המחאות", "Checks"), icon: this.iconCheck(), on: true }
        ];
        const tabs = methods.map((method) => {
            const active = method.key === this.payMethod && method.on;
            const attr = method.on ? `data-method="${method.key}"` : `disabled title="${this.e(this.t("בקרוב", "Coming soon"))}"`;
            return `<button class="${active ? "on" : ""}" ${attr}>${method.icon}${this.e(method.label)}</button>`;
        }).join("");
        const panel = this.payMethod === "saved" ? this.savedCardPanelHtml()
            : this.payMethod === "bank" ? this.transferPanelHtml(hasCustomer)
            : this.payMethod === "check" ? this.checkPanelHtml(hasCustomer)
            : this.newCardPanelHtml(hasCustomer);
        return `<div class="ppw-pane">
            <div class="ppw-sec-title">${this.e(this.t("איך משלמים", "How to pay"))}</div>
            <div class="ppw-sec-sub">${this.e(this.t("ניתן לחייב כרטיס אשראי חדש בשדות מאובטחים של PayPlus, או לחייב כרטיס שמור של הלקוח בטוקן.", "Charge a new credit card through PayPlus secure fields, or charge a customer's saved card with a token."))}</div>
            <div class="ppw-method-tabs">${tabs}</div>
            ${panel}
        </div>`;
    }

    private newCardPanelHtml(hasCustomer: boolean): string {
        const saveRow = hasCustomer
            ? `<label class="ppw-savecard"><input type="checkbox" data-save-card ${this.saveCardChecked ? "checked" : ""} /><span>${this.e(this.t("שמור כרטיס זה ללקוח והפוך לכרטיס ברירת המחדל", "Save this card for the customer and make it the default"))}</span></label>`
            : "";
        return `<div class="ppw-card">
            <div class="ppw-card-head">
                <strong>${this.e(this.t("פרטי כרטיס", "Card details"))}</strong>
                <span class="ppw-pci">${this.iconShield()} PCI SAQ-A</span>
            </div>
            ${this.hostedFieldsHtml()}
            ${saveRow}
            <div class="ppw-note" data-card-note>${this.e(this.t("הפרטים מוקלדים בשדות מאובטחים של PayPlus. ב-D365 לא נשמרים מספר כרטיס או קוד אבטחה.", "Details are typed into PayPlus secure fields. The card number and security code are never stored in D365."))}</div>
        </div>`;
    }

    private savedCardPanelHtml(): string {
        if (!this.savedCards.length) {
            return `<div class="ppw-card"><div class="ppw-note">${this.e(this.t("אין כרטיסים שמורים ללקוח זה. ניתן לחייב כרטיס חדש ולסמן ״שמור כרטיס״.", "This customer has no saved cards. Charge a new card and tick \u201csave card\u201d."))}</div></div>`;
        }
        const cards = this.savedCards.map((card) => {
            const id = card.alex_creditcardid || "";
            const on = id === this.selectedSavedCardId;
            const title = this.savedCardTitle(card);
            const exp = card.alex_expirymonth && card.alex_expiryyear ? `${card.alex_expirymonth}/${card.alex_expiryyear}` : "";
            const badge = card.alex_isdefault ? `<span class="ppw-savedcard-def">${this.e(this.t("ברירת מחדל", "Default"))}</span>` : "";
            const meta = [card.alex_cardholdername || "", exp ? this.t(`תוקף ${exp}`, `Exp ${exp}`) : ""].filter(Boolean).join(" · ");
            return `<button class="ppw-savedcard ${on ? "sel" : ""}" data-saved-card="${this.e(id)}">
                <span class="ppw-savedcard-radio"></span>
                <span class="ppw-savedcard-body"><span class="ppw-savedcard-title">${this.iconCard()}${this.e(title)}${badge}</span>${meta ? `<span class="ppw-savedcard-meta">${this.e(meta)}</span>` : ""}</span>
            </button>`;
        }).join("");
        return `<div class="ppw-card">
            <div class="ppw-card-head"><strong>${this.e(this.t("כרטיס שמור לחיוב", "Saved card to charge"))}</strong><span class="ppw-pci">${this.iconShield()} ${this.e(this.t("חיוב טוקן", "Token charge"))}</span></div>
            <div class="ppw-savedcards">${cards}</div>
            <div class="ppw-note">${this.e(this.t("החיוב מתבצע בטוקן מאובטח של PayPlus. מספר הכרטיס המלא אינו נשמר ואינו נחשף.", "The charge uses a secure PayPlus token. The full card number is never stored or exposed."))}</div>
            ${this.statusText ? `<div class="ppw-note err">${this.e(this.statusText)}</div>` : ""}
        </div>`;
    }

    private transferPanelHtml(hasCustomer: boolean): string {
        const hasAccounts = this.customerBankAccounts.length > 0;
        const modeTabs = hasAccounts ? `<div class="ppw-tfmode">
            <button class="${this.transferMode === "existing" ? "on" : ""}" data-tfmode="existing">${this.e(this.t("חשבון שמור", "Saved account"))}</button>
            <button class="${this.transferMode === "new" ? "on" : ""}" data-tfmode="new">${this.e(this.t("חשבון מזדמן", "One-time account"))}</button>
        </div>` : "";
        const body = (this.transferMode === "existing" && hasAccounts) ? this.transferExistingHtml() : this.transferNewHtml(hasCustomer);
        return `<div class="ppw-card">
            <div class="ppw-card-head"><strong>${this.e(this.t("העברה בנקאית", "Bank transfer"))}</strong><span class="ppw-pci">${this.iconBank()} ${this.e(this.t("רישום ידני", "Recorded"))}</span></div>
            ${modeTabs}
            ${body}
            <div class="ppw-tfrow2">
                <div class="ppw-field"><label>${this.e(this.t("אסמכתה / מספר העברה", "Reference / transfer no."))}</label><input type="text" data-tf-reference value="${this.e(this.tfReference)}" placeholder="${this.e(this.t("אופציונלי", "Optional"))}" /></div>
                <div class="ppw-field"><label>${this.e(this.t("תאריך העברה", "Transfer date"))}</label><input type="date" data-tf-date value="${this.e(this.tfDate)}" /></div>
            </div>
            <div class="ppw-note">${this.e(this.t("העברה בנקאית נרשמת כתשלום ומפיקה קבלה. אין חיוב אונליין — יש לוודא שהכספים התקבלו בחשבון.", "A bank transfer is recorded as a payment and issues a receipt. There is no online charge — verify the funds were received."))}</div>
            ${this.currentTransferAccountStatus() === "invalid" ? `<div class="ppw-note err">${this.e(this.t("מספר חשבון הבנק אינו עובר בדיקת תקינות עבור הבנק שנבחר. בדוק את פרטי החשבון — PayPlus ידחה חשבון לא תקין.", "The bank account number fails the validity check for the selected bank. Check the account details — PayPlus will reject an invalid account."))}</div>` : ""}
            ${this.statusText ? `<div class="ppw-note err">${this.e(this.statusText)}</div>` : ""}
        </div>`;
    }

    private transferExistingHtml(): string {
        const rows = this.customerBankAccounts.map((account) => {
            const id = account.alex_customerbankaccountid || "";
            const on = id === this.selectedBankAccountId;
            const title = this.bankAccountTitle(account);
            const bankName = account.alex_BankId?.alex_name || "";
            const branchName = account.alex_BranchId?.alex_name || "";
            const badge = account.alex_isdefault ? `<span class="ppw-savedcard-def">${this.e(this.t("ברירת מחדל", "Default"))}</span>` : "";
            const meta = [account.alex_accountholdername || "", [bankName, branchName].filter(Boolean).join(" · ")].filter(Boolean).join(" · ");
            return `<button class="ppw-savedcard ${on ? "sel" : ""}" data-bank-account="${this.e(id)}">
                <span class="ppw-savedcard-radio"></span>
                <span class="ppw-savedcard-body"><span class="ppw-savedcard-title">${this.iconBank()}${this.e(title)}${badge}</span>${meta ? `<span class="ppw-savedcard-meta">${this.e(meta)}</span>` : ""}</span>
            </button>`;
        }).join("");
        return `<div class="ppw-savedcards">${rows}</div>`;
    }

    private transferNewHtml(hasCustomer: boolean): string {
        const bankLabel = this.tfBankLabel();
        const branchLabel = this.tfBranchLabel();
        const bankOptions = this.banks.map((bank) => ({ value: bank.alex_bankid || "", label: `${bank.alex_bankcode != null ? bank.alex_bankcode + " · " : ""}${bank.alex_name || ""}` }));
        const branchOptions = this.branches.map((branch) => ({ value: branch.alex_bankbranchid || "", label: `${branch.alex_branchcode != null ? branch.alex_branchcode + " · " : ""}${branch.alex_name || ""}` }));
        const branchPlaceholder = this.branchesLoading ? this.t("טוען סניפים…", "Loading branches…") : (this.tfBankId ? this.t("חפש סניף…", "Search branch…") : this.t("בחר בנק תחילה", "Select a bank first"));
        const branchDisabled = !this.tfBankId || this.branchesLoading;
        const saveRow = hasCustomer
            ? `<label class="ppw-savecard"><input type="checkbox" data-tf-save ${this.saveBankAccountChecked ? "checked" : ""} /><span>${this.e(this.t("שמור חשבון זה תחת הלקוח לשימוש עתידי", "Save this account under the customer for future use"))}</span></label>`
            : "";
        return `<div class="ppw-tfgrid">
            <div class="ppw-field full"><label>${this.e(this.t("בנק", "Bank"))}</label>${this.comboHtml("tf-bank", bankLabel, this.t("חפש בנק…", "Search bank…"), bankOptions, false)}</div>
            <div class="ppw-field full"><label>${this.e(this.t("סניף", "Branch"))}</label>${this.comboHtml("tf-branch", branchLabel, branchPlaceholder, branchOptions, branchDisabled)}</div>
            <div class="ppw-tfrow2">
                <div class="ppw-field"><label>${this.e(this.t("מספר חשבון", "Account number"))}</label><input type="text" inputmode="numeric" data-tf-account value="${this.e(this.tfAccountNumber)}" placeholder="${this.e(this.t("מספר חשבון", "Account number"))}" /></div>
                <div class="ppw-field"><label>${this.e(this.t("שם בעל החשבון", "Account holder"))}</label><input type="text" data-tf-holder value="${this.e(this.tfHolderName)}" placeholder="${this.e(this.t("שם מלא", "Full name"))}" /></div>
            </div>
            ${saveRow}
        </div>`;
    }

    private tfBankLabel(): string {
        const bank = this.banks.find((row) => row.alex_bankid === this.tfBankId);
        if (!bank) return "";
        return `${bank.alex_bankcode != null ? bank.alex_bankcode + " · " : ""}${bank.alex_name || ""}`;
    }

    private tfBranchLabel(): string {
        const branch = this.branches.find((row) => row.alex_bankbranchid === this.tfBranchId);
        if (!branch) return "";
        return `${branch.alex_branchcode != null ? branch.alex_branchcode + " · " : ""}${branch.alex_name || ""}`;
    }

    private comboHtml(key: string, value: string, placeholder: string, options: { value: string; label: string }[], disabled: boolean): string {
        const opts = options.map((option) => `<button type="button" class="ppw-combo-opt" data-combo-opt="${this.e(key)}" data-val="${this.e(option.value)}">${this.e(option.label)}</button>`).join("");
        return `<div class="ppw-combo ${disabled ? "disabled" : ""}" data-combo="${this.e(key)}">
            <input type="text" class="ppw-combo-input" data-combo-input="${this.e(key)}" value="${this.e(value)}" placeholder="${this.e(placeholder)}" autocomplete="off" spellcheck="false" ${disabled ? "disabled" : ""} />
            <div class="ppw-combo-menu" data-combo-menu="${this.e(key)}" hidden>${opts}<div class="ppw-combo-empty" hidden>${this.e(this.t("אין תוצאות", "No results"))}</div></div>
        </div>`;
    }

    private bindCombo(key: string, currentLabel: string, onSelect: (value: string) => void): void {
        const wrap = this.root.querySelector<HTMLElement>(`[data-combo="${key}"]`);
        if (!wrap || wrap.classList.contains("disabled")) return;
        const input = wrap.querySelector<HTMLInputElement>(".ppw-combo-input");
        const menu = wrap.querySelector<HTMLElement>(".ppw-combo-menu");
        if (!input || !menu) return;
        const opts = Array.from(menu.querySelectorAll<HTMLElement>(".ppw-combo-opt"));
        const empty = menu.querySelector<HTMLElement>(".ppw-combo-empty");
        const open = (): void => { menu.hidden = false; wrap.classList.add("open"); };
        const close = (): void => { menu.hidden = true; wrap.classList.remove("open"); };
        const filter = (): void => {
            const query = input.value.trim().toLowerCase();
            let shown = 0;
            opts.forEach((option) => {
                const match = !query || (option.textContent || "").toLowerCase().indexOf(query) !== -1;
                option.hidden = !match;
                if (match) shown++;
            });
            if (empty) empty.hidden = shown !== 0;
        };
        input.addEventListener("focus", () => { input.select(); open(); filter(); });
        input.addEventListener("input", () => { open(); filter(); });
        input.addEventListener("keydown", (event) => {
            if (event.key === "Escape") { input.value = currentLabel; close(); input.blur(); }
            else if (event.key === "Enter") { const first = opts.find((option) => !option.hidden); if (first) { event.preventDefault(); onSelect(first.dataset.val || ""); } }
        });
        input.addEventListener("blur", () => { window.setTimeout(() => { input.value = currentLabel; close(); }, 160); });
        opts.forEach((option) => option.addEventListener("mousedown", (event) => { event.preventDefault(); onSelect(option.dataset.val || ""); }));
    }

    private bankAccountTitle(account: CustomerBankAccount): string {
        if (account.alex_name) return String(account.alex_name);
        const number = String(account.alex_accountnumber || "");
        return number ? this.t(`חשבון ${number}`, `Account ${number}`) : this.t("חשבון בנק", "Bank account");
    }

    /* -------------------- Checks -------------------- */

    private initCheckDefaults(): void {
        const today = new Date().toISOString().substring(0, 10);
        if (!this.tfDate) this.tfDate = today;
        if (!this.checkFirstDate) this.checkFirstDate = today;
        if (!this.tfHolderName) this.tfHolderName = String(this.billingCase?.alex_customername || "");
        // Checks always use a one-time account entry — saved bank accounts are confusing here.
        this.transferMode = "new";
        if (!this.checksInitialized) { this.regenerateChecks(); this.checksInitialized = true; }
    }

    private desiredCheckCount(): number {
        return this.checkSeriesMode === "single" ? 1 : Math.max(1, Math.min(24, Math.round(this.checkCount)));
    }

    private splitAmount(total: number, count: number): number[] {
        const cents = Math.round(this.roundMoney(total) * 100);
        const base = Math.floor(cents / count);
        const result: number[] = [];
        for (let i = 0; i < count; i++) result.push(base / 100);
        const remainder = cents - base * count;
        if (count > 0) result[count - 1] = (base + remainder) / 100;
        return result;
    }

    private addMonthsIso(iso: string, months: number): string {
        const base = iso && /^\d{4}-\d{2}-\d{2}$/.test(iso) ? new Date(`${iso}T00:00:00`) : new Date();
        const day = base.getDate();
        const target = new Date(base.getFullYear(), base.getMonth() + months, 1);
        const lastDay = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate();
        target.setDate(Math.min(day, lastDay));
        const y = target.getFullYear();
        const m = String(target.getMonth() + 1).padStart(2, "0");
        const d = String(target.getDate()).padStart(2, "0");
        return `${y}-${m}-${d}`;
    }

    private regenerateChecks(): void {
        const count = this.desiredCheckCount();
        const amounts = this.splitAmount(this.amount, count);
        const firstDate = this.checkFirstDate || new Date().toISOString().substring(0, 10);
        const startNum = parseInt(this.checkStartNumber.trim(), 10);
        const next: CheckRow[] = [];
        for (let i = 0; i < count; i++) {
            const prev = this.checks[i];
            const number = Number.isFinite(startNum) ? String(startNum + i) : (prev?.number || "");
            const date = count === 1 ? firstDate : this.addMonthsIso(firstDate, i);
            next.push({ number, date, amount: amounts[i] });
        }
        this.checks = next;
    }

    private redistributeCheckAmounts(): void {
        const amounts = this.splitAmount(this.amount, this.checks.length || 1);
        this.checks.forEach((row, i) => { row.amount = amounts[i]; });
    }

    private applyStartNumbers(): void {
        const startNum = parseInt(this.checkStartNumber.trim(), 10);
        if (!Number.isFinite(startNum)) return;
        this.checks.forEach((row, i) => { row.number = String(startNum + i); });
    }

    private applyDateSequence(): void {
        const first = this.checkFirstDate || new Date().toISOString().substring(0, 10);
        this.checks.forEach((row, i) => { row.date = this.checks.length === 1 ? first : this.addMonthsIso(first, i); });
    }

    private checksTotal(): number {
        return this.roundMoney(this.checks.reduce((sum, row) => sum + (Number(row.amount) || 0), 0));
    }

    private setCheckMode(mode: CheckSeriesMode): void {
        if (this.checkSeriesMode === mode) return;
        this.checkSeriesMode = mode;
        if (mode === "single") this.checkCount = 1;
        else if (this.checkCount < 2) this.checkCount = 3;
        this.statusText = "";
        this.regenerateChecks();
        this.render();
    }

    private setCheckCount(count: number): void {
        const next = Math.max(1, Math.min(24, Math.round(count)));
        if (next === this.desiredCheckCount()) return;
        const wasSeries = this.checkSeriesMode === "series";
        this.checkCount = next;
        this.checkSeriesMode = next === 1 ? "single" : "series";
        this.regenerateChecks();
        if (this.checkSeriesMode === "series" && wasSeries) this.redrawChecks();
        else this.render();
    }

    private deleteCheck(index: number): void {
        if (this.checks.length <= 1 || index < 0 || index >= this.checks.length) return;
        this.checks.splice(index, 1);
        this.checkCount = this.checks.length;
        this.checkSeriesMode = this.checkCount <= 1 ? "single" : "series";
        this.redistributeCheckAmounts();
        if (this.checkSeriesMode === "single") this.render();
        else this.redrawChecks();
    }

    private redrawChecks(): void {
        const count = this.desiredCheckCount();
        const countInput = this.root.querySelector<HTMLInputElement>("[data-check-count-input]");
        if (countInput) countInput.value = String(count);
        const dec = this.root.querySelector<HTMLButtonElement>("[data-check-count-dec]");
        if (dec) dec.disabled = count <= 2;
        const inc = this.root.querySelector<HTMLButtonElement>("[data-check-count-inc]");
        if (inc) inc.disabled = count >= 24;
        const table = this.root.querySelector<HTMLElement>(".ppw-chktable");
        if (table) table.outerHTML = this.checksTableHtml();
        this.bindCheckRows();
        this.updateCheckTotals();
    }

    private bindCheckRows(): void {
        this.root.querySelectorAll<HTMLInputElement>("[data-check-num]").forEach((input) => input.addEventListener("input", () => { const i = Number(input.dataset.checkNum); if (this.checks[i]) { this.checks[i].number = input.value; this.updateFooter(); } }));
        this.root.querySelectorAll<HTMLInputElement>("[data-check-date]").forEach((input) => input.addEventListener("change", () => { const i = Number(input.dataset.checkDate); if (this.checks[i]) { this.checks[i].date = input.value; this.updateFooter(); } }));
        this.root.querySelectorAll<HTMLInputElement>("[data-check-amt]").forEach((input) => input.addEventListener("input", () => { const i = Number(input.dataset.checkAmt); if (this.checks[i]) { this.checks[i].amount = Math.max(0, Number(input.value) || 0); this.updateCheckTotals(); } }));
        this.root.querySelectorAll<HTMLElement>("[data-check-del]").forEach((element) => element.addEventListener("click", () => this.deleteCheck(Number(element.dataset.checkDel))));
    }

    private checkAccountValid(): boolean {
        if (this.transferMode === "existing") {
            if (!this.selectedBankAccountId || this.customerBankAccounts.length === 0) return false;
        } else if (!this.tfBankId || !this.tfBranchId || !this.tfAccountNumber.trim()) {
            return false;
        }
        return this.currentTransferAccountStatus() !== "invalid";
    }

    private checkValid(): boolean {
        if (!this.checkAccountValid()) return false;
        if (this.checks.length === 0) return false;
        for (const row of this.checks) {
            if (!row.number.trim()) return false;
            if (!row.date) return false;
            if (!(Number(row.amount) > 0)) return false;
        }
        return this.checksTotal() === this.roundMoney(this.amount);
    }

    private checkInvalidReason(): string {
        if (!this.checkAccountValid()) return this.t("השלם את פרטי החשבון", "Complete the account details");
        if (this.checks.some((row) => !row.number.trim())) return this.t("יש למלא מספר לכל המחאה", "Enter a number for every check");
        if (this.checks.some((row) => !row.date || !(Number(row.amount) > 0))) return this.t("יש למלא תאריך וסכום לכל המחאה", "Fill a date and amount for every check");
        if (this.checksTotal() !== this.roundMoney(this.amount)) return this.t("סכום ההמחאות אינו שווה לסכום לתשלום", "The checks total doesn't equal the amount due");
        return this.t("רישום המחאות והפקת קבלה", "Record checks & issue receipt");
    }

    private checkPanelHtml(hasCustomer: boolean): string {
        const count = this.desiredCheckCount();
        const modeTabs = `<div class="ppw-tfmode">
            <button class="${this.checkSeriesMode === "single" ? "on" : ""}" data-check-mode="single">${this.e(this.t("המחאה בודדת", "Single check"))}</button>
            <button class="${this.checkSeriesMode === "series" ? "on" : ""}" data-check-mode="series">${this.e(this.t("סדרת המחאות", "Check series"))}</button>
        </div>`;
        const seriesControls = this.checkSeriesMode === "series" ? `<div class="ppw-chkseries">
            <div class="ppw-field ppw-chkcount"><label>${this.e(this.t("מספר תשלומים", "Number of payments"))}</label>
                <div class="ppw-chkstep">
                    <button type="button" data-check-count-dec ${count <= 2 ? "disabled" : ""}>−</button>
                    <input type="text" inputmode="numeric" data-check-count-input value="${count}" aria-label="${this.e(this.t("מספר תשלומים", "Number of payments"))}" />
                    <button type="button" data-check-count-inc ${count >= 24 ? "disabled" : ""}>+</button>
                </div>
            </div>
            <div class="ppw-field"><label>${this.e(this.t("מספר המחאה ראשונה", "First check number"))}</label>
                <input type="text" inputmode="numeric" data-check-start value="${this.e(this.checkStartNumber)}" placeholder="${this.e(this.t("אופציונלי", "Optional"))}" />
            </div>
            <div class="ppw-field"><label>${this.e(this.t("תאריך המחאה ראשונה", "First check date"))}</label>
                <input type="date" data-check-firstdate value="${this.e(this.checkFirstDate)}" />
            </div>
            <button type="button" class="ppw-chkfill-btn" data-check-fill title="${this.e(this.t("ממלא מספרים ותאריכים רצופים לכל ההמחאות (חודש קדימה בכל שורה)", "Fills sequential numbers and dates for every check (one month apart)"))}">${this.iconSequence()}<span>${this.e(this.t("מלא רצף", "Fill run"))}</span></button>
        </div>` : "";
        const accountBody = this.transferNewHtml(hasCustomer);
        const total = this.checksTotal();
        const due = this.roundMoney(this.amount);
        const balanced = total === due;
        return `<div class="ppw-card">
            <div class="ppw-card-head"><strong>${this.e(this.t("המחאות", "Checks"))}</strong><span class="ppw-pci">${this.iconCheck()} ${this.e(this.t("רישום ידני", "Recorded"))}</span></div>
            ${modeTabs}
            ${seriesControls}
            <div class="ppw-chk-acctitle">${this.e(this.t("חשבון המחאות", "Check account"))}</div>
            ${accountBody}
            ${this.checksTableHtml()}
            <div class="ppw-chk-foot ${balanced ? "" : "warn"}">
                <span>${this.e(this.t(`סה״כ ${count} המחאות`, `${count} checks total`))}</span>
                <strong>${this.e(this.formatMoney(total))}${balanced ? "" : ` / ${this.formatMoney(due)}`}</strong>
            </div>
            <div class="ppw-note">${this.e(this.t("סדרת המחאות נרשמת כתשלום אחד ומפיקה קבלה אחת המפרטת את כל ההמחאות. אין חיוב אונליין.", "A check series is recorded as one payment and issues a single receipt listing every check. There is no online charge."))}</div>
            ${this.currentTransferAccountStatus() === "invalid" ? `<div class="ppw-note err">${this.e(this.t("מספר חשבון הבנק אינו עובר בדיקת תקינות עבור הבנק שנבחר. בדוק את פרטי החשבון — PayPlus ידחה חשבון לא תקין.", "The bank account number fails the validity check for the selected bank. Check the account details — PayPlus will reject an invalid account."))}</div>` : ""}
            ${!balanced ? `<div class="ppw-note err">${this.e(this.t("סכום ההמחאות אינו שווה לסכום לתשלום. עדכן את הסכומים.", "The checks total doesn't equal the amount due. Adjust the amounts."))}</div>` : ""}
            ${this.statusText ? `<div class="ppw-note err">${this.e(this.statusText)}</div>` : ""}
        </div>`;
    }

    private checksTableHtml(): string {
        const single = this.checks.length <= 1;
        const rows = this.checks.map((row, i) => `<div class="ppw-chkrow">
            ${single ? "" : `<span class="ppw-chkidx">${i + 1}</span>`}
            <div class="ppw-field"><label>${this.e(this.t("מספר המחאה", "Check number"))}</label><input type="text" inputmode="numeric" data-check-num="${i}" value="${this.e(row.number)}" placeholder="${this.e(this.t("מספר", "Number"))}" /></div>
            <div class="ppw-field"><label>${this.e(this.t("תאריך פירעון", "Due date"))}</label><input type="date" data-check-date="${i}" value="${this.e(row.date)}" /></div>
            <div class="ppw-field"><label>${this.e(this.t("סכום", "Amount"))}</label><input type="number" step="0.01" min="0" inputmode="decimal" data-check-amt="${i}" value="${row.amount}" /></div>
            ${single ? "" : `<button type="button" class="ppw-chkdel" data-check-del="${i}" title="${this.e(this.t("מחק המחאה", "Remove check"))}" aria-label="${this.e(this.t("מחק המחאה", "Remove check"))}">${this.iconTrash()}</button>`}
        </div>`).join("");
        return `<div class="ppw-chktable ${single ? "single" : ""}">${rows}</div>`;
    }

    private async recordChecks(): Promise<void> {
        if (this.busy) return;
        if (!this.checkValid()) {
            this.statusText = this.checkInvalidReason();
            this.statusKind = "error";
            this.render();
            return;
        }
        this.busy = true;
        this.step = 3;
        this.execState = "running";
        this.execTitle = this.t("רושם המחאות ומפיק קבלה…", "Recording the checks and issuing a receipt…");
        this.execDetail = this.t("ההמחאות נרשמו. ממתין להפקת קבלה מ-PayPlus…", "The checks were recorded. Waiting for PayPlus to issue the receipt…");
        this.render();
        try {
            const paymentLineId = await this.createCheckPaymentLine();
            const finalized = await this.waitForReceiptFinalization(paymentLineId);
            this.receiptDocId = String(finalized._alex_receiptdocumentid_value || "");
            this.receiptLabel = String(finalized["_alex_receiptdocumentid_value@OData.Community.Display.V1.FormattedValue" as keyof PaymentLine] || "");
            await this.load2();
            await this.maybeCloseInvoice();
            this.execState = "success";
            this.busy = false;
            this.render();
        } catch (error) {
            this.busy = false;
            this.execState = "error";
            this.execTitle = this.t("רישום ההמחאות נכשל", "Recording the checks failed");
            this.execDetail = error instanceof Error ? error.message : String(error);
            this.render();
        }
    }

    private async createCheckPaymentLine(): Promise<string> {
        if (!this.billingCase?.alex_payplusbillingcaseid) throw new Error(this.t("לא נמצא תיק גבייה לשמירת התשלום.", "No billing case was found for saving the payment."));
        const total = this.checksTotal();
        if (!total || total <= 0) throw new Error(this.t("יש להזין סכום חיובי.", "Enter a positive amount."));
        const drafts = this.allocationDrafts();
        this.validateAllocationDrafts(drafts);
        let bankNumber = "";
        let branchNumber = "";
        let accountNumber = "";
        let bankAccountId = "";
        if (this.transferMode === "existing") {
            const account = this.customerBankAccounts.find((row) => row.alex_customerbankaccountid === this.selectedBankAccountId);
            if (!account) throw new Error(this.t("בחר חשבון בנק.", "Select a bank account."));
            bankAccountId = account.alex_customerbankaccountid || "";
            accountNumber = String(account.alex_accountnumber || "");
            bankNumber = account.alex_BankId?.alex_bankcode != null ? String(account.alex_BankId.alex_bankcode) : "";
            branchNumber = account.alex_BranchId?.alex_branchcode != null ? String(account.alex_BranchId.alex_branchcode) : "";
        } else {
            const bank = this.banks.find((row) => row.alex_bankid === this.tfBankId);
            const branch = this.branches.find((row) => row.alex_bankbranchid === this.tfBranchId);
            accountNumber = this.tfAccountNumber.trim();
            bankNumber = bank?.alex_bankcode != null ? String(bank.alex_bankcode) : "";
            branchNumber = branch?.alex_branchcode != null ? String(branch.alex_branchcode) : "";
            if (this.saveBankAccountChecked && (this.customerContactId || this.customerAccountId)) {
                bankAccountId = await this.createCustomerBankAccount(accountNumber, this.tfHolderName.trim());
            }
        }
        const currency = this.billingCase.alex_currencycode || "ILS";
        const payplusPayments = this.checks.map((row) => ({
            payment_type: "payment-check",
            amount: this.roundMoney(row.amount),
            date: row.date,
            currency,
            bank: bankNumber,
            bank_number: bankNumber,
            branch: branchNumber,
            branch_number: branchNumber,
            account_number: accountNumber,
            cheque_number: row.number.trim()
        }));
        const seriesId = this.newGuid();
        const first = this.checks[0];
        const count = this.checks.length;
        const notes = JSON.stringify({
            createdBy: "PayPlus.PaymentWizard",
            method: "check",
            seriesId,
            seriesCount: count,
            payplusPayments,
            checks: this.checks.map((row) => ({ number: row.number.trim(), date: row.date, amount: this.roundMoney(row.amount) })),
            bankNumber,
            branchNumber,
            accountNumber,
            savedAccount: !!bankAccountId,
            selectedInvoiceLineIds: drafts.map((draft) => draft.line.invoicedetailid || "").filter(Boolean)
        });
        const label = count > 1 ? this.t(`המחאות ×${count}`, `Checks ×${count}`) : this.t("המחאה", "Check");
        const body: Record<string, unknown> = {
            alex_name: `${label} ${this.formatMoney(total)}`,
            alex_sequence: this.paymentLines.length + 1,
            alex_chargemode: 100000000,
            alex_paymentmethod: 100000001,
            alex_status: PAYMENT_STATUS.draft,
            alex_amount: total,
            alex_currencycode: currency,
            alex_paymentdate: first.date,
            alex_duedate: first.date,
            alex_checkseriesid: seriesId,
            alex_checkseriesindex: 1,
            alex_checkseriescount: count,
            alex_notes: notes.substring(0, 4000),
            alex_requesteddocflow: this.requestedDocFlow,
            "alex_billingcaseid@odata.bind": `/alex_payplusbillingcases(${this.billingCase.alex_payplusbillingcaseid})`
        };
        if (first.number.trim()) body.alex_checknumber = first.number.trim().substring(0, 50);
        if (bankNumber) body.alex_banknumber = bankNumber.substring(0, 20);
        if (branchNumber) body.alex_branchnumber = branchNumber.substring(0, 20);
        if (accountNumber) body.alex_accountnumber = accountNumber.substring(0, 50);
        if (this.tfReference.trim()) body.alex_reference = this.tfReference.trim().substring(0, 200);
        if (bankAccountId) body["alex_customerbankaccountid@odata.bind"] = `/alex_customerbankaccounts(${bankAccountId})`;
        const created = await this.api().createRecord("alex_paypluspaymentline", body);
        const paymentLineId = created.id.replace(/[{}]/g, "").toLowerCase();
        await this.createAllocationRows(paymentLineId, drafts, ALLOCATION_STATUS.proposed);
        await this.api().updateRecord("alex_paypluspaymentline", paymentLineId, { alex_status: PAYMENT_STATUS.pendingExecution });
        return paymentLineId;
    }


    private hostedFieldsHtml(): string {
        return `<div class="ppw-hfbox ${this.cardReady ? "ready" : "loading"}" id="ppw-hfbox">
            <div class="ppw-hf-fields">
                <div class="ppw-field full"><label>${this.e(this.t("מספר כרטיס", "Card number"))}</label><span id="ppw-cc-wrapper" class="ppw-hf-wrap"><span id="ppw-cc" class="ppw-hosted"></span></span></div>
                <div class="ppw-hfrow">
                    <div class="ppw-field">
                        <label>${this.e(this.t("תוקף (חודש/שנה)", "Expiry (MM/YY)"))}</label>
                        <span id="ppw-expiry-wrapper" class="ppw-hf-wrap"><span id="ppw-expiry" class="ppw-hosted"></span></span>
                        <div class="ppw-split-expiry" id="ppw-split-expiry">
                            <div class="ppw-split-col">
                                <span id="ppw-expirym-wrapper" class="ppw-hf-wrap"><span id="ppw-expirym" class="ppw-hosted"></span></span>
                                <small class="ppw-sublabel">${this.e(this.t("חודש (MM)", "Month (MM)"))}</small>
                            </div>
                            <div class="ppw-split-col">
                                <span id="ppw-expiryy-wrapper" class="ppw-hf-wrap"><span id="ppw-expiryy" class="ppw-hosted"></span></span>
                                <small class="ppw-sublabel">${this.e(this.t("שנה (YY)", "Year (YY)"))}</small>
                            </div>
                        </div>
                    </div>
                    <div class="ppw-field"><label>${this.e(this.t("קוד אבטחה (CVV)", "Security code (CVV)"))}</label><span id="ppw-cvv-wrapper" class="ppw-hf-wrap"><span id="ppw-cvv" class="ppw-hosted"></span></span></div>
                </div>
                <div class="ppw-field full"><label>${this.e(this.t("שם בעל הכרטיס", "Cardholder name"))}</label><input id="ppw-card-holder" type="text" autocomplete="off" placeholder="${this.e(this.t("שם מלא", "Full name"))}" /></div>
                <div id="ppw-recaptcha"></div>
            </div>
            <div class="ppw-hf-loading" id="ppw-hf-loading"><span class="ppw-spinner"></span><span class="ppw-hf-loadingtext">${this.e(this.t("מכין סביבת תשלום מאובטחת…", "Preparing a secure payment environment…"))}</span></div>
        </div>`;
    }

    private step3Html(): string {
        if (this.execState === "running") {
            return `<div class="ppw-pane">
                <div class="ppw-sec-title">${this.e(this.t("ביצוע ותוצאה", "Execution & result"))}</div>
                <div class="ppw-sec-sub" data-exec-sub>${this.e(this.execTitle)}</div>
                <div class="ppw-exec-pending">
                    <div class="ppw-spinner big"></div>
                    <div class="pt">${this.e(this.execTitle)}</div>
                    <div class="ps" data-exec-detail>${this.e(this.execDetail)}</div>
                </div>
            </div>`;
        }
        if (this.execState === "success") {
            const receipt = this.receiptLabel || this.receiptDocId;
            const closedLine = this.invoiceClosed ? `<div class="ppw-paid-badge">${this.iconCheckBig()}<span>${this.e(this.t("החשבונית נסגרה כ״שולם במלואו״ ב-D365.", "The invoice was closed as \u201cPaid in full\u201d in D365."))}</span></div>` : "";
            const splitLine = this.splitOutcome ? `<div class="ppw-paid-badge split">${this.iconCheckBig()}<span>${this.e(this.splitOutcome)}</span></div>` : "";
            const savedLine = this.cardSaved ? `<div class="ppw-paid-badge card">${this.iconSaved()}<span>${this.e(this.t("הכרטיס נשמר ללקוח כאמצעי ברירת המחדל.", "The card was saved for the customer as the default method."))}</span></div>` : "";
            return `<div class="ppw-pane">
                <div class="ppw-sec-title">${this.e(this.t("ביצוע ותוצאה", "Execution & result"))}</div>
                <div class="ppw-sec-sub">${this.e(this.t("החיוב אושר והקבלה הופקה.", "The charge was approved and the receipt was issued."))}</div>
                <div class="ppw-result ok">
                    <div class="ic">${this.iconCheckBig()}</div>
                    <div class="rc-body">
                        <div class="rc-t">${this.e(this.t("התשלום אושר", "Payment approved"))} · ${this.e(this.formatMoney(this.amount))}</div>
                        <div class="rc-s">${this.e(receipt ? this.t(`הופקה קבלה: ${receipt}`, `Receipt issued: ${receipt}`) : this.t("הקבלה הופקה בהצלחה.", "The receipt was issued successfully."))}</div>
                    </div>
                </div>
                ${closedLine}
                ${splitLine}
                ${savedLine}
                ${this.receiptDocId ? this.sendActionsHtml() : ""}
            </div>`;
        }
        return `<div class="ppw-pane">
            <div class="ppw-sec-title">${this.e(this.t("ביצוע ותוצאה", "Execution & result"))}</div>
            <div class="ppw-sec-sub">${this.e(this.t("החיוב לא הושלם. ניתן לחזור ולנסות שוב.", "The charge did not complete. Go back and try again."))}</div>
            <div class="ppw-result fail">
                <div class="ic">${this.iconX()}</div>
                <div class="rc-body">
                    <div class="rc-t">${this.e(this.execTitle || this.t("שגיאה", "Error"))}</div>
                    <div class="rc-s">${this.e(this.execDetail)}</div>
                </div>
            </div>
        </div>`;
    }

    private footerHtml(): string {
        const totals = this.paymentTotals();
        let mainText = this.t(`לתשלום: ${this.formatMoney(this.amount)}`, `To pay: ${this.formatMoney(this.amount)}`);
        let subText = this.t(`מסמך צפוי: ${this.documentOutcomeLabel()}`, `Expected document: ${this.documentOutcomeLabel()}`);
        const backVisible = this.step === 2;
        let nextLabel = this.t("המשך", "Continue");
        let nextAction = "next";
        let nextEnabled = true;

        if (this.step === 2) {
            nextLabel = this.t(`בצע תשלום · ${this.formatMoney(this.amount)}`, `Charge · ${this.formatMoney(this.amount)}`);
            if (this.payMethod === "saved") {
                nextEnabled = !!this.selectedSavedCardId && !this.busy;
                subText = this.busy ? this.t("מבצע חיוב בכרטיס השמור…", "Charging the saved card…") : (this.selectedSavedCardId ? this.t("חיוב בטוקן מאובטח", "Secure token charge") : this.t("בחר כרטיס שמור", "Select a saved card"));
            } else if (this.payMethod === "bank") {
                nextLabel = this.t(`רשום תשלום · ${this.formatMoney(this.amount)}`, `Record · ${this.formatMoney(this.amount)}`);
                nextEnabled = this.transferValid() && !this.busy;
                subText = this.busy ? this.t("רושם העברה בנקאית…", "Recording bank transfer…") : (this.transferValid() ? this.t("רישום העברה והפקת קבלה", "Record transfer & issue receipt") : this.t("השלם את פרטי החשבון", "Complete the account details"));
            } else if (this.payMethod === "check") {
                nextLabel = this.t(`רשום תשלום · ${this.formatMoney(this.checksTotal())}`, `Record · ${this.formatMoney(this.checksTotal())}`);
                nextEnabled = this.checkValid() && !this.busy;
                subText = this.busy ? this.t("רושם המחאות…", "Recording checks…") : (this.checkValid() ? this.t("רישום המחאות והפקת קבלה", "Record checks & issue receipt") : this.checkInvalidReason());
            } else {
                nextEnabled = this.cardReady && !this.busy;
                subText = this.busy ? this.t("מבצע חיוב מאובטח…", "Running secure charge…") : (this.cardReady ? this.t("החיבור המאובטח מוכן", "Secure connection ready") : this.t("מכין תשלום מאובטח…", "Preparing secure payment…"));
            }
        } else if (this.step === 3) {
            if (this.execState === "running") { nextEnabled = false; nextLabel = this.t("מבצע…", "Working…"); mainText = this.execTitle; subText = this.execDetail; }
            else if (this.execState === "success") {
                const paid = this.paymentTotals().currentBalance <= 0;
                nextLabel = paid ? this.t("סיום", "Finish") : this.t("תשלום נוסף", "New payment");
                nextAction = paid ? "finish" : "next";
                mainText = paid ? this.t("החשבונית שולמה במלואה", "Invoice fully paid") : this.t("הושלם בהצלחה", "Completed successfully");
                subText = this.receiptLabel ? this.t(`קבלה: ${this.receiptLabel}`, `Receipt: ${this.receiptLabel}`) : this.t("הקבלה הופקה", "Receipt issued");
            }
            else { nextLabel = this.t("נסה שוב", "Try again"); nextAction = "back"; mainText = this.t("החיוב נכשל", "Charge failed"); subText = this.execDetail; }
        } else {
            subText = totals.currentBalance <= 0 ? this.t("היתרה שולמה במלואה", "The balance is fully paid") : subText;
        }

        const back = backVisible ? `<button class="ppw-btn ghost" data-action="back">${this.e(this.t("הקודם", "Back"))}</button>` : `<span class="ppw-btn-spacer"></span>`;
        const next = `<button class="ppw-btn primary ${nextEnabled ? "" : "disabled"}" data-action="${nextAction}" ${nextEnabled ? "" : "disabled"}>${this.e(nextLabel)}</button>`;
        return `<footer class="ppw-footer">
            <div class="ppw-foot-info"><div class="fi-main">${this.e(mainText)}</div><div class="fi-sub">${this.e(subText)}</div></div>
            <div class="ppw-foot-actions">${back}${next}</div>
        </footer>`;
    }

    /* -------------------- Icons -------------------- */
    private checkIcon(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M5 13l4 4L19 7"/></svg>'; }
    private iconCard(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20"/></svg>'; }
    private iconSaved(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="8" cy="12" r="1.5"/></svg>'; }
    private iconBank(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 21h18M4 10h16M5 21V10M19 21V10M12 3L4 8h16z"/></svg>'; }
    private iconCheck(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="6" width="18" height="12" rx="2"/><path d="M7 14h6M16 14h1"/></svg>'; }
    private iconShield(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M12 2l7 4v6c0 5-3.5 8-7 10-3.5-2-7-5-7-10V6z"/></svg>'; }
    private iconCheckBig(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M5 13l4 4L19 7"/></svg>'; }
    private iconX(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M6 6l12 12M18 6L6 18"/></svg>'; }
    private iconTrash(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 7h16M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2M6 7l1 13a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1l1-13M10 11v6M14 11v6"/></svg>'; }
    private iconSequence(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h11M4 12h11M4 17h7"/><path d="M17 15l3 3 3-3"/><path d="M20 18V8"/></svg>'; }
    private iconMail(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/></svg>'; }
    private iconSms(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12a8 8 0 0 1-8 8H7l-4 3 1.2-4.6A8 8 0 1 1 21 12z"/></svg>'; }
    private iconWhatsapp(): string { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"><path d="M20.5 11.6a8.5 8.5 0 0 1-12.6 7.5L3 20.5l1.5-4.8a8.5 8.5 0 1 1 16-4.1z"/><path d="M8.6 8.4c-.3 0-.6.1-.8.4-.3.3-.9.9-.9 2.1s.9 2.4 1 2.6c.1.2 1.7 2.8 4.3 3.8 2.1.8 2.6.7 3 .6.6-.1 1.4-.6 1.6-1.2.2-.6.2-1 .1-1.2-.1-.1-.3-.2-.6-.4z"/></svg>'; }

    /* -------------------- Helpers -------------------- */
    private roundMoney(value: number): number { return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100; }
    private moneyInputValue(value: number): string { return this.roundMoney(value).toFixed(2); }
    private formatMoney(value: number): string { return `${this.roundMoney(value).toLocaleString(this.isRtl ? "he-IL" : "en-US", MONEY_FORMAT)} ${this.billingCase?.alex_currencycode || "ILS"}`; }
    private newGuid(): string { return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => { const r = Math.random() * 16 | 0; const v = c === "x" ? r : (r & 0x3 | 0x8); return v.toString(16); }); }
    private e(value: string): string { return String(value || "").replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[char] || char)); }
}
