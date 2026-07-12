import { IInputs, IOutputs } from "./generated/ManifestTypes";

interface ContextInfo {
    entityId?: string;
    entityTypeName?: string;
    entityRecordName?: string;
}

interface SourceField {
    logical: string;
    en: string;
    he: string;
    type: number;
}

interface SourceTable {
    logical: string;
    en: string;
    he: string;
    fields: SourceField[];
}

interface TransformRule {
    id: string;
    name: string;
    expression: string;
    outputType: number | null;
    isActive: boolean;
}

interface DataverseLabel {
    LocalizedLabels?: { Label?: string; LanguageCode?: number }[];
    UserLocalizedLabel?: { Label?: string; LanguageCode?: number } | null;
}

interface PayPlusField {
    logical: string;
    en: string;
    he: string;
    required: boolean;
    type: number;
    suggested: Record<string, string>;
}

interface PayPlusTarget {
    value: number;
    en: string;
    he: string;
    fields: PayPlusField[];
    advanced?: boolean;
    hidden?: boolean;
}

interface ProfileInfo {
    name: string;
    environment: string;
    isActive: boolean;
}

interface EntityMapping {
    id: string;
    name: string;
    sourceLogical: string;
    sourceDisplay: string;
    targetValue: number | null;
    targetLabel: string;
    isActive: boolean;
    pluginStepStatus: number | null;
}

interface FieldMapping {
    id: string;
    targetLogical: string;
    targetDisplay: string;
    sourceType: number;
    sourceLogical: string;
    sourceDisplay: string;
    transformRuleId: string;
    transformRuleName: string;
    defaultValue: string;
    required: boolean;
    payplusType: number | null;
    dataverseType: number | null;
    isActive: boolean;
}

interface AutoMapChoice {
    sourceLogical: string;
    sourceType: number;
    defaultValue: string;
    sourceField: SourceField | null;
}

interface DraftState {
    sourceLogical: string;
    targetValue: number;
    fields: Record<string, string>;
}

interface SyncStats {
    pending: number;
    succeeded: number;
    failed: number;
    lastSync: string;
}

const DATA_TYPE = {
    text: 100000000,
    number: 100000001,
    decimal: 100000002,
    money: 100000003,
    boolean: 100000004,
    dateTime: 100000005,
    lookup: 100000006,
    choice: 100000007,
    json: 100000008,
    array: 100000009
};

const SOURCE_TYPE_FIELD = 100000000;
const SOURCE_TYPE_CONSTANT = 100000001;
const SOURCE_TYPE_FORMULA = 100000002;
const SOURCE_TYPE_LOOKUP = 100000003;
const SOURCE_TYPE_RELATED = 100000004;
const SOURCE_TYPE_VALUE_MAPPING = 100000005;
const NULL_OMIT = 100000000;
const CHANGE_CURRENT_STATE = 100000000;
const MISSING_UID_CREATE = 100000000;
const PLUGIN_NOT_REQUIRED = 100000000;
const PLUGIN_NOT_REGISTERED = 100000001;
const PLUGIN_REGISTERED = 100000002;
const PRODUCT_DEFAULT_CATEGORY_UID = "6319f6a8-d135-4715-b289-3914267b9899";
const PLUGIN_FAILED = 100000003;
const COMBO_LIMIT = 80;

type ComboKind = "newSource" | "newTarget" | "editSource" | "editTarget";

const UI = {
    en: {
        kicker: "PAYPLUS · DYNAMICS 365",
        title: "Mapping Studio",
        profileFallback: "Sync Profile",
        environmentUnknown: "Environment not set",
        active: "Active",
        inactive: "Inactive",
        refresh: "Refresh",
        loading: "Loading Mapping Studio",
        loadingDetail: "Reading the sync profile, mappings, fields, and operational status.",
        loadError: "Could not load Mapping Studio",
        loadErrorDetail: "Check permissions and table metadata, then refresh.",
        saveProfileFirst: "Save the sync profile before using Mapping Studio.",
        draftProfile: "New sync profile",
        draftHint: "You can start mapping now. The mapping will be created after the form is saved.",
        unexpectedError: "Unexpected error.",
        stepSource: "Dynamics source",
        stepTarget: "PayPlus target",
        stepMapping: "Field mapping",
        stepActivate: "Activate",
        sourceTables: "Source tables",
        sourceTablesHint: "Mappings under this profile",
        searchTable: "Search table",
        noTables: "No mappings found.",
        addSource: "Dynamics source table",
        addTarget: "PayPlus target",
        searchSource: "Search Dynamics table",
        searchTarget: "Search PayPlus target",
        addMapping: "Add mapping",
        sourceMissing: "No source selected",
        targetMissing: "No PayPlus target",
        createFirstMapping: "Choose a Dynamics source table and PayPlus target to start.",
        sourceToTarget: "Source to target",
        autoMap: "Auto map",
        validate: "Validate",
        registerSteps: "Register steps",
        activate: "Start sync",
        activateSync: "Start sync",
        deactivateSync: "Stop sync",
        advancedTargets: "Advanced:",
        advancedSyncWarning: "We strongly recommend not running this PayPlus target through automatic synchronization. Create or update these records with Power Automate or another controlled automation process to avoid unintended charges, documents, or business actions.",
        activeSyncLock: "Sync is active. Stop sync before changing the source, target, or field mapping.",
        subjectCodeHelp: "Use only a short numeric PayPlus subject code, up to 15 digits. Do not map a Dataverse GUID here.",
        actions: "Actions",
        clearMapping: "Clear",
        sourceTable: "Dynamics source",
        payplusTarget: "PayPlus target",
        searchField: "Search field",
        missingOnly: "Missing only",
        requiredOnly: "Required only",
        payplusField: "PayPlus field",
        sourceType: "Value source",
        dynamicsField: "Dynamics value",
        required: "Required",
        status: "Status",
        chooseSourceField: "Choose direct field",
        chooseLookupField: "Choose lookup column",
        chooseRelatedField: "Choose related table field",
        chooseTransformRule: "Choose transform rule",
        constantValue: "Constant value",
        formulaValue: "Transform rule",
        sourceTypeField: "Direct field",
        sourceTypeConstant: "Constant",
        sourceTypeFormula: "Transform rule",
        sourceTypeLookup: "Lookup reference",
        sourceTypeRelated: "Related field",
        sourceTypeValueMapping: "Value mapping",
        requiredYes: "Required",
        requiredNo: "Optional",
        mapped: "Mapped",
        notMapped: "Not mapped",
        noFields: "No fields to show.",
        statusPanel: "Operational status",
        statusPanelHint: "Current table context",
        lastSync: "Last sync",
        pending: "Pending",
        succeeded: "Succeeded",
        failed: "Failed",
        dash: "-",
        checkSource: "Dynamics source selected",
        checkTarget: "PayPlus target selected",
        checkRequiredOk: "All required PayPlus fields are mapped.",
        checkRequiredWarn: "Required PayPlus fields are still missing.",
        showPayload: "Developer payload preview",
        missingSourceTarget: "Select both a Dynamics source and a PayPlus target.",
        creatingMapping: "Creating mapping. Please wait...",
        mappingCreated: "Mapping created.",
        draftMappingCreated: "Draft mapping is ready. Save the form to create it in Dataverse.",
        draftSaved: "The draft mapping was created after the profile was saved.",
        savingChanges: "Saving change. Please wait...",
        autoMappingBusy: "Creating automatic field mappings. Please wait...",
        autoMapDone: "Automatic mapping applied.",
        validateOk: "Validation passed.",
        validateWarn: "Validation found missing required fields.",
        registerStepsBusy: "Registering plugin steps for this source table. Please wait...",
        registerStepsDone: "Plugin steps are registered for this mapping.",
        registerStepsFailed: "Plugin step registration failed. Check table permissions and metadata.",
        activateBlocked: "Activation is blocked until required fields are mapped.",
        activateNeedsRegisteredStep: "Activation is blocked until plugin steps are registered for the selected source table.",
        activateBusy: "Starting continuous sync for this mapping. Please wait...",
        deactivateBusy: "Stopping mapping sync. Please wait...",
        activated: "Continuous sync is active for this mapping.",
        deactivated: "Mapping sync stopped."
    },
    he: {
        kicker: "PAYPLUS · DYNAMICS 365",
        title: "Mapping Studio",
        profileFallback: "פרופיל סנכרון",
        environmentUnknown: "סביבה לא הוגדרה",
        active: "פעיל",
        inactive: "לא פעיל",
        refresh: "רענון",
        loading: "טוען את Mapping Studio",
        loadingDetail: "קורא פרופיל, מיפויים, שדות ונתוני תפעול.",
        loadError: "טעינת Mapping Studio נכשלה",
        loadErrorDetail: "בדקו הרשאות ומטא-דאטה ואז רעננו.",
        saveProfileFirst: "יש לשמור את פרופיל הסנכרון לפני שימוש ב-Mapping Studio.",
        draftProfile: "פרופיל סנכרון חדש",
        draftHint: "אפשר להתחיל למפות עכשיו. המיפוי ייווצר אחרי שמירת הטופס.",
        unexpectedError: "שגיאה לא צפויה.",
        stepSource: "מקור Dynamics",
        stepTarget: "יעד PayPlus",
        stepMapping: "מיפוי שדות",
        stepActivate: "הפעלה",
        sourceTables: "טבלאות מקור",
        sourceTablesHint: "מיפויים תחת הפרופיל",
        searchTable: "חיפוש טבלה",
        noTables: "לא נמצאו מיפויים.",
        addSource: "טבלת מקור Dynamics",
        addTarget: "יעד PayPlus",
        searchSource: "חיפוש טבלת Dynamics",
        searchTarget: "חיפוש יעד PayPlus",
        addMapping: "הוסף מיפוי",
        sourceMissing: "לא נבחר מקור",
        targetMissing: "לא נבחר יעד PayPlus",
        createFirstMapping: "בחרו טבלת מקור ב-Dynamics ויעד PayPlus כדי להתחיל.",
        sourceToTarget: "מקור אל יעד",
        autoMap: "מיפוי אוטומטי",
        validate: "בדיקה",
        registerSteps: "רשום steps",
        activate: "הפעל סנכרון",
        activateSync: "הפעל סנכרון",
        deactivateSync: "כבה סנכרון",
        advancedTargets: "מתקדם:",
        advancedSyncWarning: "אנו ממליצים בחום לא להריץ יעד PayPlus זה בסנכרון אוטומטי. עדיף ליצור או לעדכן רשומות אלו באמצעות Power Automate או תהליך אוטומטי מבוקר אחר, כדי למנוע חיובים, מסמכים או פעולות עסקיות לא רצויות.",
        activeSyncLock: "הסנכרון פעיל. יש לכבות סנכרון לפני שינוי מקור, יעד או מיפוי שדות.",
        subjectCodeHelp: "יש להשתמש רק בקוד נושא מספרי קצר של PayPlus, עד 15 ספרות. אין למפות לכאן GUID של Dataverse.",
        actions: "פעולות",
        clearMapping: "נקה",
        sourceTable: "מקור Dynamics",
        payplusTarget: "יעד PayPlus",
        searchField: "חיפוש שדה",
        missingOnly: "רק חסרים",
        requiredOnly: "רק שדות חובה",
        payplusField: "שדה PayPlus",
        sourceType: "מקור ערך",
        dynamicsField: "ערך Dynamics",
        required: "חובה",
        status: "סטטוס",
        chooseSourceField: "בחרו שדה ישיר",
        chooseLookupField: "בחרו עמודת Lookup",
        chooseRelatedField: "בחרו שדה מטבלה קשורה",
        chooseTransformRule: "בחרו כלל המרה",
        constantValue: "ערך קבוע",
        formulaValue: "כלל המרה",
        sourceTypeField: "שדה ישיר",
        sourceTypeConstant: "קבוע",
        sourceTypeFormula: "כלל המרה / נוסחה",
        sourceTypeLookup: "Lookup - מזהה רשומה",
        sourceTypeRelated: "שדה מטבלה קשורה",
        sourceTypeValueMapping: "מיפוי ערכים",
        requiredYes: "חובה",
        requiredNo: "רשות",
        mapped: "ממופה",
        notMapped: "לא ממופה",
        noFields: "אין שדות להצגה.",
        statusPanel: "סטטוס תפעולי",
        statusPanelHint: "בהקשר הטבלה הנבחרת",
        lastSync: "סנכרון אחרון",
        pending: "ממתינים",
        succeeded: "הצליחו",
        failed: "נכשלו",
        dash: "-",
        checkSource: "נבחר מקור Dynamics",
        checkTarget: "נבחר יעד PayPlus",
        checkRequiredOk: "כל שדות החובה של PayPlus ממופים.",
        checkRequiredWarn: "עדיין חסרים שדות חובה של PayPlus.",
        showPayload: "תצוגת Payload למפתחים",
        missingSourceTarget: "יש לבחור גם מקור Dynamics וגם יעד PayPlus.",
        creatingMapping: "יוצר מיפוי. נא להמתין...",
        mappingCreated: "המיפוי נוצר.",
        draftMappingCreated: "טיוטת המיפוי מוכנה. שמרו את הטופס כדי ליצור אותה ב-Dataverse.",
        draftSaved: "טיוטת המיפוי נוצרה לאחר שמירת הפרופיל.",
        savingChanges: "שומר שינוי. נא להמתין...",
        autoMappingBusy: "יוצר מיפויי שדות אוטומטיים. נא להמתין...",
        autoMapDone: "המיפוי האוטומטי הוחל.",
        validateOk: "הבדיקה עברה.",
        validateWarn: "הבדיקה מצאה שדות חובה חסרים.",
        registerStepsBusy: "רושם Plugin Steps לטבלת המקור. נא להמתין...",
        registerStepsDone: "Plugin Steps נרשמו עבור המיפוי.",
        registerStepsFailed: "רישום Plugin Steps נכשל. בדקו הרשאות ומטא-דאטה של הטבלה.",
        activateBlocked: "לא ניתן להפעיל עד שכל שדות החובה ימופו.",
        activateNeedsRegisteredStep: "לא ניתן להפעיל עד ש-Plugin Steps נרשמו לטבלת המקור שנבחרה.",
        activateBusy: "מפעיל סנכרון קבוע למיפוי. נא להמתין...",
        deactivateBusy: "מכבה סנכרון למיפוי. נא להמתין...",
        activated: "סנכרון קבוע הופעל למיפוי.",
        deactivated: "הסנכרון למיפוי כובה."
    }
};

const SOURCE_TABLES: SourceTable[] = [
    table("account", "Account", "לקוח", [
        source("accountid", "Account GUID", "מזהה רשומת לקוח", DATA_TYPE.text),
        source("name", "Name", "שם", DATA_TYPE.text),
        source("emailaddress1", "Email", "דואר אלקטרוני", DATA_TYPE.text),
        source("telephone1", "Main phone", "טלפון ראשי", DATA_TYPE.text),
        source("address1_line1", "Address line", "כתובת", DATA_TYPE.text),
        source("address1_city", "City", "עיר", DATA_TYPE.text),
        source("address1_postalcode", "Postal code", "מיקוד", DATA_TYPE.text),
        source("accountnumber", "Account number", "מספר לקוח", DATA_TYPE.text),
        source("alex_vatnumber", "VAT number", "מספר עוסק", DATA_TYPE.number),
        source("description", "Description", "תיאור", DATA_TYPE.text),
        source("alex_paypluscustomeruid", "PayPlus customer UID", "מזהה לקוח PayPlus", DATA_TYPE.text)
    ]),
    table("contact", "Contact", "איש קשר", [
        source("contactid", "Contact GUID", "מזהה רשומת איש קשר", DATA_TYPE.text),
        source("fullname", "Full name", "שם מלא", DATA_TYPE.text),
        source("emailaddress1", "Email", "דואר אלקטרוני", DATA_TYPE.text),
        source("mobilephone", "Mobile phone", "טלפון נייד", DATA_TYPE.text),
        source("telephone1", "Business phone", "טלפון עסקי", DATA_TYPE.text),
        source("governmentid", "Government ID", "מספר מזהה", DATA_TYPE.text),
        source("address1_line1", "Address line", "כתובת", DATA_TYPE.text),
        source("address1_city", "City", "עיר", DATA_TYPE.text),
        source("address1_postalcode", "Postal code", "מיקוד", DATA_TYPE.text),
        source("jobtitle", "Job title", "תפקיד", DATA_TYPE.text),
        source("description", "Description", "תיאור", DATA_TYPE.text),
        source("parentcustomerid", "Parent customer", "לקוח אב", DATA_TYPE.lookup),
        source("alex_paypluscustomeruid", "PayPlus customer UID", "מזהה לקוח PayPlus", DATA_TYPE.text)
    ]),
    table("product", "Product", "מוצר", [
        source("name", "Name", "שם", DATA_TYPE.text),
        source("productnumber", "Product ID", "מזהה מוצר", DATA_TYPE.text),
        source("price", "Price", "מחיר", DATA_TYPE.money),
        source("standardcost", "Standard cost", "עלות", DATA_TYPE.money),
        source("description", "Description", "תיאור", DATA_TYPE.text),
        source("transactioncurrencyid", "Currency", "מטבע", DATA_TYPE.lookup),
        source("statecode", "Status", "מצב", DATA_TYPE.choice),
        source("pricelevelid", "Default price list", "מחירון ברירת מחדל", DATA_TYPE.lookup),
        source("defaultuomid", "Default unit", "יחידת ברירת מחדל", DATA_TYPE.lookup)
    ]),
    table("productpricelevel", "Price List Item", "פריט מחירון", [
        source("amount", "Amount", "סכום", DATA_TYPE.money),
        source("productid", "Product", "מוצר", DATA_TYPE.lookup),
        source("pricelevelid", "Price list", "מחירון", DATA_TYPE.lookup),
        source("transactioncurrencyid", "Currency", "מטבע", DATA_TYPE.lookup),
        source("uomid", "Unit", "יחידה", DATA_TYPE.lookup)
    ]),
    table("transactioncurrency", "Currency", "מטבע", [
        source("currencyname", "Currency name", "שם מטבע", DATA_TYPE.text),
        source("isocurrencycode", "ISO currency code", "קוד מטבע ISO", DATA_TYPE.text),
        source("currencysymbol", "Currency symbol", "סימן מטבע", DATA_TYPE.text)
    ]),
    table("invoice", "Invoice", "חשבונית", [
        source("invoicenumber", "Invoice number", "מספר חשבונית", DATA_TYPE.text),
        source("customerid", "Customer", "לקוח", DATA_TYPE.lookup),
        source("totalamount", "Total amount", "סכום כולל", DATA_TYPE.money),
        source("transactioncurrencyid", "Currency", "מטבע", DATA_TYPE.lookup),
        source("description", "Description", "תיאור", DATA_TYPE.text),
        source("invoiceid", "Invoice ID", "מזהה חשבונית", DATA_TYPE.text)
    ]),
    table("quote", "Quote", "הצעת מחיר", [
        source("name", "Name", "שם", DATA_TYPE.text),
        source("quotenumber", "Quote number", "מספר הצעה", DATA_TYPE.text),
        source("customerid", "Customer", "לקוח", DATA_TYPE.lookup),
        source("totalamount", "Total amount", "סכום כולל", DATA_TYPE.money),
        source("transactioncurrencyid", "Currency", "מטבע", DATA_TYPE.lookup),
        source("expireson", "Valid until", "בתוקף עד", DATA_TYPE.dateTime),
        source("description", "Description", "תיאור", DATA_TYPE.text)
    ]),
    table("salesorder", "Order", "הזמנה", [
        source("name", "Name", "שם", DATA_TYPE.text),
        source("ordernumber", "Order number", "מספר הזמנה", DATA_TYPE.text),
        source("customerid", "Customer", "לקוח", DATA_TYPE.lookup),
        source("totalamount", "Total amount", "סכום כולל", DATA_TYPE.money),
        source("transactioncurrencyid", "Currency", "מטבע", DATA_TYPE.lookup),
        source("datefulfilled", "Fulfilled date", "תאריך אספקה", DATA_TYPE.dateTime),
        source("description", "Description", "תיאור", DATA_TYPE.text)
    ]),
    table("msdyn_purchaseorder", "Purchase Order", "הזמנת רכש", [
        source("msdyn_name", "Name", "שם", DATA_TYPE.text),
        source("msdyn_purchaseorderid", "Purchase order ID", "מזהה הזמנת רכש", DATA_TYPE.text),
        source("msdyn_vendor", "Vendor", "ספק", DATA_TYPE.lookup),
        source("msdyn_subtotalamount", "Subtotal", "סכום ביניים", DATA_TYPE.money),
        source("transactioncurrencyid", "Currency", "מטבע", DATA_TYPE.lookup)
    ]),
    table("opportunity", "Opportunity", "הזדמנות", [
        source("name", "Topic", "נושא", DATA_TYPE.text),
        source("customerid", "Customer", "לקוח", DATA_TYPE.lookup),
        source("estimatedvalue", "Estimated value", "ערך משוער", DATA_TYPE.money),
        source("transactioncurrencyid", "Currency", "מטבע", DATA_TYPE.lookup)
    ]),
    table("alex_creditcard", "Saved card", "כרטיס שמור", [
        source("alex_name", "Name", "שם", DATA_TYPE.text),
        source("alex_token", "Token", "טוקן", DATA_TYPE.text),
        source("alex_last4", "Last 4", "ארבע ספרות", DATA_TYPE.text),
        source("alex_paypluscustomeruid", "PayPlus customer UID", "מזהה לקוח PayPlus", DATA_TYPE.text)
    ])
];

const TARGETS: PayPlusTarget[] = [
    target(100000000, "Customer", "לקוח", [
        ppField("email", "Email", "דואר אלקטרוני", true, DATA_TYPE.text, { account: "emailaddress1", contact: "emailaddress1" }),
        ppField("customer_name", "Customer name", "שם לקוח", true, DATA_TYPE.text, { account: "name", contact: "fullname" }),
        ppField("paying_vat", "Paying VAT", "חייב במע\"מ", false, DATA_TYPE.boolean, {}),
        ppField("vat_number", "VAT number", "מספר עוסק / ח.פ", false, DATA_TYPE.number, { account: "alex_vatnumber", contact: "governmentid" }),
        ppField("customer_number", "Customer number", "מספר לקוח פנימי", false, DATA_TYPE.text, { account: "accountnumber" }),
        ppField("notes", "Notes", "הערות", false, DATA_TYPE.text, { account: "description", contact: "description" }),
        ppField("phone", "Phone", "טלפון", false, DATA_TYPE.text, { account: "telephone1", contact: "mobilephone" }),
        ppField("contacts.full_name", "Contact full name", "שם איש קשר", false, DATA_TYPE.text, { contact: "fullname", account: "primarycontactid.fullname" }),
        ppField("contacts.cell_phone", "Contact cell phone", "טלפון נייד איש קשר", false, DATA_TYPE.text, { contact: "mobilephone", account: "primarycontactid.mobilephone" }),
        ppField("contacts.contact_email", "Contact email", "דוא\"ל איש קשר", false, DATA_TYPE.text, { contact: "emailaddress1", account: "primarycontactid.emailaddress1" }),
        ppField("contacts.contact_address", "Contact address", "כתובת איש קשר", false, DATA_TYPE.text, { contact: "address1_line1", account: "address1_line1" }),
        ppField("contacts.contact_city", "Contact city", "עיר איש קשר", false, DATA_TYPE.text, { contact: "address1_city", account: "address1_city" }),
        ppField("contacts.contact_postal_code", "Contact postal code", "מיקוד איש קשר", false, DATA_TYPE.text, { contact: "address1_postalcode", account: "address1_postalcode" }),
        ppField("contacts.contact_country_iso", "Contact country ISO", "מדינת איש קשר ISO", false, DATA_TYPE.text, {}),
        ppField("contacts.job_position", "Contact job position", "תפקיד איש קשר", false, DATA_TYPE.text, { contact: "jobtitle" }),
        ppField("business_address", "Address", "כתובת", false, DATA_TYPE.text, { account: "address1_line1", contact: "address1_line1" }),
        ppField("business_city", "City", "עיר", false, DATA_TYPE.text, { account: "address1_city", contact: "address1_city" }),
        ppField("business_postal_code", "Postal code", "מיקוד", false, DATA_TYPE.text, { account: "address1_postalcode", contact: "address1_postalcode" }),
        ppField("business_country_iso", "Country ISO", "מדינה ISO", false, DATA_TYPE.text, {}),
        ppField("communication_email", "Communication email", "דואר אלקטרוני לתקשורת", false, DATA_TYPE.text, { account: "emailaddress1", contact: "emailaddress1" }),
        ppField("subject_code", "Short numeric subject code", "קוד נושא מספרי קצר", false, DATA_TYPE.text, {})
    ]),
    target(100000001, "Product", "מוצר", [
        ppField("category_uids", "Category UIDs", "מזהי קטגוריות", true, DATA_TYPE.array, {}),
        ppField("name", "Product name", "שם מוצר", true, DATA_TYPE.text, { product: "name", productpricelevel: "product.name" }),
        ppField("price", "Price", "מחיר", true, DATA_TYPE.money, { product: "productpricelevel.amount", productpricelevel: "amount" }),
        ppField("currency_code", "Currency", "מטבע", true, DATA_TYPE.text, { product: "transactioncurrencyid.isocurrencycode", productpricelevel: "transactioncurrencyid.isocurrencycode" }),
        ppField("vat_type", "VAT type", "סוג מע\"מ", true, DATA_TYPE.number, {}),
        ppField("valid", "Valid", "פעיל", false, DATA_TYPE.boolean, { product: "statecode" }),
        ppField("barcode", "Barcode", "ברקוד", false, DATA_TYPE.text, { product: "productnumber", productpricelevel: "product.productnumber" }),
        ppField("value", "Cost price", "מחיר עלות", false, DATA_TYPE.money, { product: "standardcost" }),
        ppField("description", "Description", "תיאור", false, DATA_TYPE.text, { product: "description", productpricelevel: "product.name" }),
        ppField("fixed_amount_discount", "Fixed amount discount", "הנחה בסכום קבוע", false, DATA_TYPE.decimal, {}),
        ppField("percentage_discount", "Percentage discount", "הנחה באחוזים", false, DATA_TYPE.decimal, {}),
        ppField("guide_document_url", "Guide document URL", "קישור למסמך מוצר", false, DATA_TYPE.text, {})
    ]),
    target(100000002, "Product Category", "קטגוריה", [
        ppField("name", "Category name", "שם קטגוריה", true, DATA_TYPE.text, { product: "name" }),
        ppField("valid", "Valid", "פעיל", true, DATA_TYPE.boolean, { product: "statecode" })
    ]),
    target(100000003, "Invoice", "חשבונית", documentTargetFields({ identifier: { invoice: "invoiceid" }, moreInfo: { invoice: "invoicenumber" }, amount: { invoice: "totalamount" }, currency: { invoice: "transactioncurrencyid" }, customerUid: { invoice: "customerid" }, description: { invoice: "description" } }), { advanced: true }),
    target(100000004, "Quote", "הצעת מחיר", documentTargetFields({ identifier: { quote: "quoteid", opportunity: "opportunityid" }, moreInfo: { quote: "quotenumber", opportunity: "name" }, amount: { quote: "totalamount", opportunity: "estimatedvalue" }, currency: { quote: "transactioncurrencyid", opportunity: "transactioncurrencyid" }, customerUid: { quote: "customerid", opportunity: "customerid" }, description: { quote: "description" }, docDate: { quote: "expireson" } }), { advanced: true }),
    target(100000005, "Proforma Invoice", "חשבונית עסקה", documentTargetFields({ identifier: { quote: "quoteid", invoice: "invoiceid" }, moreInfo: { quote: "quotenumber", invoice: "invoicenumber" }, amount: { quote: "totalamount", invoice: "totalamount" }, currency: { quote: "transactioncurrencyid", invoice: "transactioncurrencyid" }, customerUid: { quote: "customerid", invoice: "customerid" }, description: { quote: "description", invoice: "description" } }), { advanced: true }),
    target(100000006, "Order", "הזמנה", documentTargetFields({ identifier: { salesorder: "salesorderid" }, moreInfo: { salesorder: "ordernumber" }, amount: { salesorder: "totalamount" }, currency: { salesorder: "transactioncurrencyid" }, customerUid: { salesorder: "customerid" }, description: { salesorder: "description" } }), { advanced: true }),
    target(100000007, "Payment Request", "בקשת תשלום", paymentRequestTargetFields(), { advanced: true }),
    target(100000008, "Purchase Order", "הזמנת רכש", documentTargetFields({ identifier: { msdyn_purchaseorder: "msdyn_purchaseorderid" }, moreInfo: { msdyn_purchaseorder: "msdyn_name" }, amount: { msdyn_purchaseorder: "msdyn_subtotalamount" }, currency: { msdyn_purchaseorder: "transactioncurrencyid" }, customerUid: { msdyn_purchaseorder: "msdyn_vendor" }, customerName: { msdyn_purchaseorder: "msdyn_vendor" } }), { advanced: true }),
    target(100000009, "Customer Bank Account", "חשבון בנק לקוח", [
        ppField("customer_uid", "Customer UID", "מזהה לקוח", true, DATA_TYPE.text, { account: "alex_paypluscustomeruid", contact: "alex_paypluscustomeruid" }),
        ppField("bank_number", "Bank number", "מספר בנק", true, DATA_TYPE.text, {}),
        ppField("branch_number", "Branch number", "מספר סניף", true, DATA_TYPE.text, {}),
        ppField("account_number", "Account number", "מספר חשבון", true, DATA_TYPE.text, { account: "accountnumber" }),
        ppField("account_holder_name", "Account holder", "בעל החשבון", false, DATA_TYPE.text, { account: "name", contact: "fullname" })
    ]),
    target(100000010, "Company Bank Account", "חשבון בנק חברה", [
        ppField("bank_account_uid", "Bank account UID", "מזהה חשבון בנק", false, DATA_TYPE.text, {}),
        ppField("bank_number", "Bank number", "מספר בנק", true, DATA_TYPE.text, {}),
        ppField("branch_number", "Branch number", "מספר סניף", true, DATA_TYPE.text, {}),
        ppField("account_number", "Account number", "מספר חשבון", true, DATA_TYPE.text, {}),
        ppField("account_name", "Account name", "שם חשבון", false, DATA_TYPE.text, { account: "name" })
    ]),
    target(100000011, "Saved Card Token", "טוקן כרטיס שמור", savedCardTokenTargetFields(), { advanced: true }),
    target(100000012, "Recurring Payment", "תשלום מחזורי", recurringPaymentTargetFields(), { advanced: true }),
    target(100000013, "Recurring Charge", "חיוב מחזורי", recurringChargeTargetFields(), { advanced: true }),
    target(100000014, "Transaction", "עסקה", transactionTargetFields(), { advanced: true }),
    target(100000015, "Transaction Report", "דוח עסקאות", [
        ppField("fromDate", "From date", "מתאריך", true, DATA_TYPE.dateTime, {}),
        ppField("untilDate", "Until date", "עד תאריך", true, DATA_TYPE.dateTime, {}),
        ppField("transaction_uid", "Transaction UID", "מזהה עסקה", false, DATA_TYPE.text, {}),
        ppField("customer_uid", "Customer UID", "מזהה לקוח", false, DATA_TYPE.text, { account: "alex_paypluscustomeruid", contact: "alex_paypluscustomeruid" })
    ], { hidden: true }),
    target(100000016, "Payment Page", "דף תשלום", [
        ppField("uid", "Payment page UID", "מזהה דף תשלום", false, DATA_TYPE.text, {}),
        ppField("terminal_uid", "Terminal UID", "מזהה מסוף", true, DATA_TYPE.text, {}),
        ppField("name", "Name", "שם", true, DATA_TYPE.text, {}),
        ppField("language_code", "Language", "שפה", false, DATA_TYPE.text, {})
    ], { hidden: true }),
    target(100000017, "Coupon Group", "קבוצת קופונים", [
        ppField("coupon_group_uid", "Coupon group UID", "מזהה קבוצת קופונים", false, DATA_TYPE.text, {}),
        ppField("name", "Name", "שם", true, DATA_TYPE.text, {}),
        ppField("valid", "Active", "פעיל", false, DATA_TYPE.boolean, {})
    ]),
    target(100000018, "Coupon", "קופון", [
        ppField("coupon_group_uid", "Coupon group UID", "מזהה קבוצת קופונים", true, DATA_TYPE.text, {}),
        ppField("coupon_uid", "Coupon UID", "מזהה קופון", false, DATA_TYPE.text, {}),
        ppField("code", "Coupon code", "קוד קופון", true, DATA_TYPE.text, {}),
        ppField("discount_type", "Discount type", "סוג הנחה", false, DATA_TYPE.text, {}),
        ppField("discount_value", "Discount value", "ערך הנחה", false, DATA_TYPE.decimal, {})
    ]),
    target(100000019, "Cashier", "קופאי", [
        ppField("cashier_uid", "Cashier UID", "מזהה קופאי", false, DATA_TYPE.text, {}),
        ppField("name", "Name", "שם", true, DATA_TYPE.text, {}),
        ppField("email", "Email", "דואר אלקטרוני", false, DATA_TYPE.text, {}),
        ppField("phone", "Phone", "טלפון", false, DATA_TYPE.text, {})
    ]),
    target(100000020, "Device", "מכשיר", [
        ppField("device_uid", "Device UID", "מזהה מכשיר", false, DATA_TYPE.text, {}),
        ppField("terminal_uid", "Terminal UID", "מזהה מסוף", true, DATA_TYPE.text, {}),
        ppField("amount", "Amount", "סכום", false, DATA_TYPE.money, {}),
        ppField("currency_code", "Currency", "מטבע", false, DATA_TYPE.text, {})
    ]),
    target(100000021, "Deposit", "הפקדה", [
        ppField("deposit_uid", "Deposit UID", "מזהה הפקדה", false, DATA_TYPE.text, {}),
        ppField("terminal_uid", "Terminal UID", "מזהה מסוף", false, DATA_TYPE.text, {}),
        ppField("amount", "Amount", "סכום", false, DATA_TYPE.money, {}),
        ppField("deposit_date", "Deposit date", "תאריך הפקדה", false, DATA_TYPE.dateTime, {})
    ]),
    target(100000022, "SMS Contact", "איש קשר SMS", [
        ppField("contact_uid", "Contact UID", "מזהה איש קשר", false, DATA_TYPE.text, {}),
        ppField("name", "Name", "שם", true, DATA_TYPE.text, { contact: "fullname", account: "name" }),
        ppField("phone", "Phone", "טלפון", true, DATA_TYPE.text, { contact: "mobilephone", account: "telephone1" }),
        ppField("email", "Email", "דואר אלקטרוני", false, DATA_TYPE.text, { contact: "emailaddress1", account: "emailaddress1" })
    ], { hidden: true }),
    target(100000023, "SMS Group", "קבוצת SMS", [
        ppField("group_uid", "Group UID", "מזהה קבוצה", false, DATA_TYPE.text, {}),
        ppField("name", "Name", "שם", true, DATA_TYPE.text, {}),
        ppField("description", "Description", "תיאור", false, DATA_TYPE.text, {})
    ], { hidden: true }),
    target(100000024, "SMS Message", "הודעת SMS", [
        ppField("message_uid", "Message UID", "מזהה הודעה", false, DATA_TYPE.text, {}),
        ppField("phone", "Phone", "טלפון", true, DATA_TYPE.text, { contact: "mobilephone", account: "telephone1" }),
        ppField("message", "Message", "הודעה", true, DATA_TYPE.text, {}),
        ppField("send_at", "Send at", "מועד שליחה", false, DATA_TYPE.dateTime, {})
    ], { hidden: true }),
    target(100000025, "OTP Request", "בקשת OTP", [
        ppField("destination", "Destination", "יעד", true, DATA_TYPE.text, { contact: "mobilephone", account: "telephone1" }),
        ppField("channel", "Channel", "ערוץ", true, DATA_TYPE.text, {}),
        ppField("code", "Code", "קוד", false, DATA_TYPE.text, {}),
        ppField("expires_at", "Expires at", "תוקף עד", false, DATA_TYPE.dateTime, {})
    ], { hidden: true }),
    target(100000026, "Invoice+ Expense", "הוצאה Invoice+", [
        ppField("uuid", "Expense UUID", "מזהה הוצאה", false, DATA_TYPE.text, {}),
        ppField("supplier_name", "Supplier", "ספק", true, DATA_TYPE.text, {}),
        ppField("amount", "Amount", "סכום", true, DATA_TYPE.money, {}),
        ppField("vat_amount", "VAT amount", "סכום מעמ", false, DATA_TYPE.money, {}),
        ppField("expense_date", "Expense date", "תאריך הוצאה", false, DATA_TYPE.dateTime, {})
    ], { hidden: true }),
    target(100000027, "Invoice+ Document", "מסמך Invoice+", [
        ppField("doc_type", "Document type", "סוג מסמך", true, DATA_TYPE.text, {}),
        ppField("customer_uid", "Customer UID", "מזהה לקוח", false, DATA_TYPE.text, { account: "alex_paypluscustomeruid", contact: "alex_paypluscustomeruid" }),
        ppField("document_number", "Document number", "מספר מסמך", false, DATA_TYPE.text, { invoice: "invoicenumber", quote: "quotenumber", salesorder: "ordernumber" }),
        ppField("amount", "Amount", "סכום", true, DATA_TYPE.money, { invoice: "totalamount", quote: "totalamount", salesorder: "totalamount" }),
        ppField("currency_code", "Currency", "מטבע", true, DATA_TYPE.text, { invoice: "transactioncurrencyid", quote: "transactioncurrencyid", salesorder: "transactioncurrencyid" })
    ], { hidden: true }),
    target(100000028, "Bank Dictionary", "מילון בנקים", [
        ppField("bank_number", "Bank number", "מספר בנק", false, DATA_TYPE.text, {}),
        ppField("name", "Name", "שם", true, DATA_TYPE.text, {})
    ], { hidden: true }),
    target(100000029, "Branch Dictionary", "מילון סניפים", [
        ppField("bank_number", "Bank number", "מספר בנק", true, DATA_TYPE.text, {}),
        ppField("branch_number", "Branch number", "מספר סניף", true, DATA_TYPE.text, {}),
        ppField("name", "Name", "שם", false, DATA_TYPE.text, {})
    ], { hidden: true }),
    target(100000030, "Terminal", "מסוף", [
        ppField("terminal_uid", "Terminal UID", "מזהה מסוף", false, DATA_TYPE.text, {}),
        ppField("name_terminal", "Terminal name", "שם מסוף", true, DATA_TYPE.text, {}),
        ppField("terminal_type_id", "Terminal type", "סוג מסוף", false, DATA_TYPE.number, {}),
        ppField("merchant_number", "Merchant number", "מספר ספק", false, DATA_TYPE.text, {})
    ]),
    target(100000031, "Currency", "מטבע", [
        ppField("currency_code", "Currency code", "קוד מטבע", true, DATA_TYPE.text, { transactioncurrency: "isocurrencycode" }),
        ppField("name", "Name", "שם", false, DATA_TYPE.text, { transactioncurrency: "currencyname" })
    ]),
    target(100000032, "Alternative Payment Method", "אמצעי תשלום חלופי", [
        ppField("method_uid", "Method UID", "מזהה אמצעי", false, DATA_TYPE.text, {}),
        ppField("name", "Name", "שם", true, DATA_TYPE.text, {}),
        ppField("valid", "Active", "פעיל", false, DATA_TYPE.boolean, {})
    ], { hidden: true }),
    target(100000033, "Error Code", "קוד שגיאה", [
        ppField("code", "Code", "קוד", true, DATA_TYPE.text, {}),
        ppField("description", "Description", "תיאור", true, DATA_TYPE.text, {})
    ], { hidden: true }),
    target(100000034, "Brand", "מותג כרטיס", [
        ppField("brand_id", "Brand ID", "מזהה מותג", true, DATA_TYPE.number, { alex_creditcard: "alex_brand" }),
        ppField("name", "Name", "שם", true, DATA_TYPE.text, { alex_creditcard: "alex_brandname" })
    ], { hidden: true })
];

function source(logical: string, en: string, he: string, type: number): SourceField {
    return { logical, en, he, type };
}

function table(logical: string, en: string, he: string, fields: SourceField[]): SourceTable {
    return { logical, en, he, fields };
}

function target(value: number, en: string, he: string, fields: PayPlusField[], options: { advanced?: boolean; hidden?: boolean } = {}): PayPlusTarget {
    return { value, en, he, fields, ...options };
}

function ppField(logical: string, en: string, he: string, required: boolean, type: number, suggested: Record<string, string>): PayPlusField {
    return { logical, en, he, required, type, suggested };
}

interface DocumentFieldSuggestions {
    identifier?: Record<string, string>;
    docDate?: Record<string, string>;
    moreInfo?: Record<string, string>;
    amount?: Record<string, string>;
    currency?: Record<string, string>;
    customerName?: Record<string, string>;
    customerUid?: Record<string, string>;
    customerEmail?: Record<string, string>;
    customerPhone?: Record<string, string>;
    vatNumber?: Record<string, string>;
    address?: Record<string, string>;
    city?: Record<string, string>;
    postalCode?: Record<string, string>;
    description?: Record<string, string>;
}

function documentTargetFields(suggested: DocumentFieldSuggestions): PayPlusField[] {
    return [
        ppField("unique_identifier", "Unique identifier", "מזהה ייחודי", false, DATA_TYPE.text, suggested.identifier || {}),
        ppField("doc_date", "Document date", "תאריך מסמך", false, DATA_TYPE.dateTime, suggested.docDate || {}),
        ppField("brand_uuid", "Brand UUID", "מזהה מותג", false, DATA_TYPE.text, {}),
        ppField("preview", "Preview only", "תצוגה מקדימה בלבד", false, DATA_TYPE.boolean, {}),
        ppField("draft", "Draft", "טיוטה", false, DATA_TYPE.boolean, {}),
        ppField("hide_base_currency", "Hide base currency", "הסתר מטבע בסיס", false, DATA_TYPE.boolean, {}),
        ppField("more_info", "More info", "מידע נוסף", false, DATA_TYPE.text, suggested.moreInfo || suggested.description || {}),
        ppField("close_doc", "Close document", "סגור מסמך", false, DATA_TYPE.boolean, {}),
        ppField("cancel_doc", "Cancel document", "בטל מסמך", false, DATA_TYPE.boolean, {}),
        ppField("transaction_uuid", "Transaction UUID", "מזהה עסקה", false, DATA_TYPE.text, {}),
        ppField("send_document_email", "Send document email", "שלח מסמך במייל", false, DATA_TYPE.boolean, {}),
        ppField("send_document_sms", "Send document SMS", "שלח מסמך ב-SMS", false, DATA_TYPE.boolean, {}),
        ppField("callback_url", "Callback URL", "כתובת Callback", false, DATA_TYPE.text, {}),
        ppField("vatType", "VAT type", "סוג מע\"מ", false, DATA_TYPE.number, {}),
        ppField("vat_percentage", "VAT percentage", "אחוז מע\"מ", false, DATA_TYPE.decimal, {}),
        ppField("language", "Language", "שפה", false, DATA_TYPE.text, {}),
        ppField("currency_code", "Currency", "מטבע", false, DATA_TYPE.text, suggested.currency || {}),
        ppField("conversion_rate", "Conversion rate", "שער המרה", false, DATA_TYPE.decimal, {}),
        ppField("autocalculate_rate", "Auto calculate rate", "חשב שער אוטומטית", false, DATA_TYPE.boolean, {}),
        ppField("prevent_email", "Prevent email", "מנע שליחת מייל", false, DATA_TYPE.boolean, {}),
        ppField("totalAmount", "Total amount", "סכום כולל", false, DATA_TYPE.money, suggested.amount || {}),
        ppField("customer.customer_name", "Customer name", "שם לקוח", false, DATA_TYPE.text, suggested.customerName || {}),
        ppField("customer.customer_uid", "Customer UID", "מזהה לקוח", false, DATA_TYPE.text, suggested.customerUid || {}),
        ppField("customer.email", "Customer email", "דוא\"ל לקוח", false, DATA_TYPE.text, suggested.customerEmail || {}),
        ppField("customer.phone", "Customer phone", "טלפון לקוח", false, DATA_TYPE.text, suggested.customerPhone || {}),
        ppField("customer.vat_number", "Customer VAT number", "מספר עוסק לקוח", false, DATA_TYPE.text, suggested.vatNumber || {}),
        ppField("customer.business_number", "Business number", "מספר עסק", false, DATA_TYPE.text, suggested.vatNumber || {}),
        ppField("customer.address", "Customer address", "כתובת לקוח", false, DATA_TYPE.text, suggested.address || {}),
        ppField("customer.city", "Customer city", "עיר לקוח", false, DATA_TYPE.text, suggested.city || {}),
        ppField("customer.postal_code", "Customer postal code", "מיקוד לקוח", false, DATA_TYPE.text, suggested.postalCode || {}),
        ppField("customer.country_iso", "Customer country ISO", "מדינת לקוח ISO", false, DATA_TYPE.text, {}),
        ppField("customer.more_info", "Customer more info", "מידע נוסף לקוח", false, DATA_TYPE.text, suggested.description || {}),
        ppField("items.name", "Item name", "שם פריט", false, DATA_TYPE.text, {}),
        ppField("items.product_uid", "Item product UID", "מזהה מוצר בפריט", false, DATA_TYPE.text, {}),
        ppField("items.barcode", "Item barcode", "ברקוד פריט", false, DATA_TYPE.text, {}),
        ppField("items.quantity", "Item quantity", "כמות פריט", false, DATA_TYPE.decimal, {}),
        ppField("items.price", "Item price", "מחיר פריט", false, DATA_TYPE.money, suggested.amount || {}),
        ppField("items.vat_type", "Item VAT type", "סוג מע\"מ פריט", false, DATA_TYPE.number, {}),
        ppField("items.discount_type", "Item discount type", "סוג הנחת פריט", false, DATA_TYPE.text, {}),
        ppField("items.discount_value", "Item discount value", "ערך הנחת פריט", false, DATA_TYPE.decimal, {}),
        ppField("items.category_uid", "Item category UID", "מזהה קטגוריית פריט", false, DATA_TYPE.text, {}),
        ppField("payments.payment_type", "Payment type", "סוג תשלום", false, DATA_TYPE.text, {}),
        ppField("payments.amount", "Payment amount", "סכום תשלום", false, DATA_TYPE.money, suggested.amount || {}),
        ppField("payments.date", "Payment date", "תאריך תשלום", false, DATA_TYPE.dateTime, suggested.docDate || {}),
        ppField("payments.currency", "Payment currency", "מטבע תשלום", false, DATA_TYPE.text, suggested.currency || {}),
        ppField("payments.card_type", "Card type", "סוג כרטיס", false, DATA_TYPE.text, {}),
        ppField("payments.four_digits", "Card last four digits", "ארבע ספרות", false, DATA_TYPE.text, {}),
        ppField("payments.card_expiry", "Card expiry", "תוקף כרטיס", false, DATA_TYPE.text, {}),
        ppField("payments.number_of_payments", "Number of payments", "מספר תשלומים", false, DATA_TYPE.number, {}),
        ppField("payments.bank", "Bank", "בנק", false, DATA_TYPE.text, {}),
        ppField("payments.branch", "Branch", "סניף", false, DATA_TYPE.text, {}),
        ppField("payments.account_number", "Account number", "מספר חשבון", false, DATA_TYPE.text, {}),
        ppField("payments.cheque_number", "Cheque number", "מספר המחאה", false, DATA_TYPE.text, {}),
        ppField("payments.transaction_uid", "Payment transaction UID", "מזהה עסקת תשלום", false, DATA_TYPE.text, {}),
        ppField("tags", "Tags", "תגיות", false, DATA_TYPE.array, {})
    ];
}

function paymentRequestTargetFields(): PayPlusField[] {
    return [
        ppField("terminal_uid", "Terminal UID", "מזהה מסוף", false, DATA_TYPE.text, {}),
        ppField("payment_page_uid", "Payment page UID", "מזהה דף תשלום", false, DATA_TYPE.text, {}),
        ppField("charge_method", "Charge method", "שיטת חיוב", false, DATA_TYPE.text, {}),
        ppField("amount", "Amount", "סכום", true, DATA_TYPE.money, { invoice: "totalamount", quote: "totalamount", salesorder: "totalamount", opportunity: "estimatedvalue" }),
        ppField("currency_code", "Currency", "מטבע", true, DATA_TYPE.text, { invoice: "transactioncurrencyid", quote: "transactioncurrencyid", salesorder: "transactioncurrencyid" }),
        ppField("more_info", "More info", "מידע נוסף", false, DATA_TYPE.text, { invoice: "invoiceid", quote: "quoteid", salesorder: "salesorderid" }),
        ppField("initial_invoice", "Initial invoice", "חשבונית ראשונית", false, DATA_TYPE.boolean, {}),
        ppField("customer", "Customer object", "אובייקט לקוח", false, DATA_TYPE.json, {}),
        ppField("customer.email", "Customer email", "דוא\"ל לקוח", false, DATA_TYPE.text, { account: "emailaddress1", contact: "emailaddress1" }),
        ppField("items", "Items", "פריטים", false, DATA_TYPE.array, {}),
        ppField("cashier_uid", "Cashier UID", "מזהה קופאי", false, DATA_TYPE.text, {}),
        ppField("charge_default", "Charge default", "חיוב ברירת מחדל", false, DATA_TYPE.boolean, {}),
        ppField("hide_other_charge_methods", "Hide other charge methods", "הסתר שיטות חיוב אחרות", false, DATA_TYPE.boolean, {}),
        ppField("language_code", "Language", "שפה", false, DATA_TYPE.text, {}),
        ppField("sendEmailApproval", "Send approval email", "שלח אישור במייל", false, DATA_TYPE.boolean, {}),
        ppField("sendEmailFailure", "Send failure email", "שלח כשל במייל", false, DATA_TYPE.boolean, {}),
        ppField("send_failure_callback", "Failure callback", "Callback כשל", false, DATA_TYPE.boolean, {}),
        ppField("expiry_datetime", "Expiry date", "תוקף", false, DATA_TYPE.dateTime, {}),
        ppField("refURL_success", "Success URL", "URL הצלחה", false, DATA_TYPE.text, {}),
        ppField("refURL_failure", "Failure URL", "URL כשל", false, DATA_TYPE.text, {}),
        ppField("refURL_cancel", "Cancel URL", "URL ביטול", false, DATA_TYPE.text, {}),
        ppField("refURL_origin", "Origin URL", "URL מקור", false, DATA_TYPE.text, {}),
        ppField("refURL_callback", "Callback URL", "URL Callback", false, DATA_TYPE.text, {}),
        ppField("custom_invoice_name", "Custom invoice name", "שם חשבונית מותאם", false, DATA_TYPE.text, {}),
        ppField("create_token", "Create token", "צור טוקן", false, DATA_TYPE.boolean, {}),
        ppField("hosted_fields", "Hosted fields", "Hosted fields", false, DATA_TYPE.boolean, {}),
        ppField("invoice_language", "Invoice language", "שפת חשבונית", false, DATA_TYPE.text, {}),
        ppField("paying_vat", "Paying VAT", "חייב במע\"מ", false, DATA_TYPE.boolean, {}),
        ppField("payments", "Payments", "תשלומים", false, DATA_TYPE.number, {}),
        ppField("payments_credit", "Credit payments", "תשלומי אשראי", false, DATA_TYPE.number, {}),
        ppField("payments_selected", "Selected payments", "תשלומים שנבחרו", false, DATA_TYPE.number, {}),
        ppField("close_doc", "Close document", "סגור מסמך", false, DATA_TYPE.boolean, {}),
        ppField("invoice_integration_uid", "Invoice integration UID", "מזהה אינטגרציית חשבונית", false, DATA_TYPE.text, {}),
        ppField("more_info_2", "More info 2", "מידע נוסף 2", false, DATA_TYPE.text, {}),
        ppField("more_info_3", "More info 3", "מידע נוסף 3", false, DATA_TYPE.text, {}),
        ppField("more_info_4", "More info 4", "מידע נוסף 4", false, DATA_TYPE.text, {}),
        ppField("more_info_5", "More info 5", "מידע נוסף 5", false, DATA_TYPE.text, {})
    ];
}

function savedCardTokenTargetFields(): PayPlusField[] {
    return [
        ppField("terminal_uid", "Terminal UID", "מזהה מסוף", false, DATA_TYPE.text, {}),
        ppField("cashier_uid", "Cashier UID", "מזהה קופאי", false, DATA_TYPE.text, {}),
        ppField("customer_uid", "Customer UID", "מזהה לקוח", false, DATA_TYPE.text, { alex_creditcard: "alex_paypluscustomeruid", account: "alex_paypluscustomeruid", contact: "alex_paypluscustomeruid" }),
        ppField("token", "Token", "טוקן", true, DATA_TYPE.text, { alex_creditcard: "alex_token" }),
        ppField("amount", "Amount", "סכום", false, DATA_TYPE.money, {}),
        ppField("currency_code", "Currency", "מטבע", false, DATA_TYPE.text, {}),
        ppField("credit_terms", "Credit terms", "תנאי אשראי", false, DATA_TYPE.text, {}),
        ppField("use_token", "Use token", "השתמש בטוקן", false, DATA_TYPE.boolean, {}),
        ppField("initial_invoice", "Initial invoice", "חשבונית ראשונית", false, DATA_TYPE.boolean, {}),
        ppField("create_token", "Create token", "צור טוקן", false, DATA_TYPE.boolean, {}),
        ppField("customer_name_invoice", "Invoice customer name", "שם לקוח לחשבונית", false, DATA_TYPE.text, {}),
        ppField("deferMonths", "Defer months", "דחיית חודשים", false, DATA_TYPE.number, {}),
        ppField("id", "External id", "מזהה חיצוני", false, DATA_TYPE.text, {}),
        ppField("add_data", "Additional data", "מידע נוסף", false, DATA_TYPE.json, {}),
        ppField("original_terminal_uid", "Original terminal UID", "מסוף מקור", false, DATA_TYPE.text, {}),
        ppField("customer", "Customer object", "אובייקט לקוח", false, DATA_TYPE.json, {}),
        ppField("products", "Products", "מוצרים", false, DATA_TYPE.array, {}),
        ppField("payments", "Payments", "תשלומים", false, DATA_TYPE.number, {}),
        ppField("extra_info", "Extra info", "מידע נוסף", false, DATA_TYPE.text, {}),
        ppField("more_info_1", "More info 1", "מידע נוסף 1", false, DATA_TYPE.text, {}),
        ppField("more_info_2", "More info 2", "מידע נוסף 2", false, DATA_TYPE.text, {}),
        ppField("more_info_3", "More info 3", "מידע נוסף 3", false, DATA_TYPE.text, {}),
        ppField("more_info_4", "More info 4", "מידע נוסף 4", false, DATA_TYPE.text, {}),
        ppField("more_info_5", "More info 5", "מידע נוסף 5", false, DATA_TYPE.text, {}),
        ppField("four_digits", "Last four digits", "ארבע ספרות", false, DATA_TYPE.text, { alex_creditcard: "alex_last4" }),
        ppField("expiry_month", "Expiry month", "חודש תפוגה", false, DATA_TYPE.number, { alex_creditcard: "alex_expirymonth" }),
        ppField("expiry_year", "Expiry year", "שנת תפוגה", false, DATA_TYPE.number, { alex_creditcard: "alex_expiryyear" })
    ];
}

function recurringPaymentTargetFields(): PayPlusField[] {
    return [
        ppField("terminal_uid", "Terminal UID", "מזהה מסוף", false, DATA_TYPE.text, {}),
        ppField("customer_uid", "Customer UID", "מזהה לקוח", true, DATA_TYPE.text, { account: "alex_paypluscustomeruid", contact: "alex_paypluscustomeruid" }),
        ppField("card_token", "Card token", "טוקן כרטיס", true, DATA_TYPE.text, { alex_creditcard: "alex_token" }),
        ppField("cashier_uid", "Cashier UID", "מזהה קופאי", false, DATA_TYPE.text, {}),
        ppField("currency_code", "Currency", "מטבע", true, DATA_TYPE.text, { invoice: "transactioncurrencyid", salesorder: "transactioncurrencyid" }),
        ppField("instant_first_payment", "Instant first payment", "תשלום ראשון מיידי", false, DATA_TYPE.boolean, {}),
        ppField("recurring_type", "Recurring type", "סוג מחזוריות", false, DATA_TYPE.text, {}),
        ppField("recurring_range", "Recurring range", "טווח מחזוריות", false, DATA_TYPE.text, {}),
        ppField("number_of_charges", "Number of charges", "מספר חיובים", false, DATA_TYPE.number, {}),
        ppField("start_date", "Start date", "תאריך התחלה", true, DATA_TYPE.dateTime, {}),
        ppField("end_date", "End date", "תאריך סיום", false, DATA_TYPE.dateTime, {}),
        ppField("items", "Recurring items", "פריטים מחזוריים", false, DATA_TYPE.array, {}),
        ppField("items.product_uid", "Item product UID", "מזהה מוצר", false, DATA_TYPE.text, {}),
        ppField("items.quantity", "Item quantity", "כמות", false, DATA_TYPE.decimal, {}),
        ppField("items.price", "Item price", "מחיר", false, DATA_TYPE.money, { invoice: "totalamount", salesorder: "totalamount" }),
        ppField("items.discount_type", "Item discount type", "סוג הנחה", false, DATA_TYPE.text, {}),
        ppField("items.discount_value", "Item discount value", "ערך הנחה", false, DATA_TYPE.decimal, {}),
        ppField("items.product_invoice_extra_details", "Invoice extra details", "פרטי חשבונית נוספים", false, DATA_TYPE.text, {}),
        ppField("bank_account_uid", "Bank account UID", "מזהה חשבון בנק", false, DATA_TYPE.text, {}),
        ppField("company_bank_account_uid", "Company bank account UID", "מזהה חשבון בנק חברה", false, DATA_TYPE.text, {}),
        ppField("one_time_items", "One time items", "פריטים חד פעמיים", false, DATA_TYPE.array, {}),
        ppField("one_time_charge_date", "One time charge date", "תאריך חיוב חד פעמי", false, DATA_TYPE.dateTime, {}),
        ppField("successful_invoice", "Successful invoice", "חשבונית בהצלחה", false, DATA_TYPE.boolean, {}),
        ppField("send_customer_success_email", "Success email", "מייל הצלחה ללקוח", false, DATA_TYPE.boolean, {}),
        ppField("customer_failure_email", "Failure email", "מייל כשל ללקוח", false, DATA_TYPE.boolean, {}),
        ppField("send_customer_success_sms", "Success SMS", "SMS הצלחה ללקוח", false, DATA_TYPE.boolean, {}),
        ppField("customer_failure_sms", "Failure SMS", "SMS כשל ללקוח", false, DATA_TYPE.boolean, {}),
        ppField("extra_info", "Extra info", "מידע נוסף", false, DATA_TYPE.text, {})
    ];
}

function recurringChargeTargetFields(): PayPlusField[] {
    return [
        ppField("transaction_uid", "Transaction UID", "מזהה עסקה", true, DATA_TYPE.text, {}),
        ppField("amount", "Amount", "סכום", false, DATA_TYPE.money, {}),
        ppField("more_info", "More info", "מידע נוסף", false, DATA_TYPE.text, {}),
        ppField("cvv", "CVV", "CVV", false, DATA_TYPE.text, {}),
        ppField("items", "Items", "פריטים", false, DATA_TYPE.array, {}),
        ppField("recurring_uid", "Recurring UID", "מזהה תשלום מחזורי", false, DATA_TYPE.text, {}),
        ppField("charge_uid", "Charge UID", "מזהה חיוב", false, DATA_TYPE.text, {}),
        ppField("charge_date", "Charge date", "תאריך חיוב", false, DATA_TYPE.dateTime, {})
    ];
}

function transactionTargetFields(): PayPlusField[] {
    return [
        ppField("transaction_uid", "Transaction UID", "מזהה עסקה", false, DATA_TYPE.text, {}),
        ppField("customer_uid", "Customer UID", "מזהה לקוח", false, DATA_TYPE.text, { account: "alex_paypluscustomeruid", contact: "alex_paypluscustomeruid" }),
        ppField("fromDate", "From date", "מתאריך", false, DATA_TYPE.dateTime, {}),
        ppField("untilDate", "Until date", "עד תאריך", false, DATA_TYPE.dateTime, {}),
        ppField("more_info", "More info", "מידע נוסף", false, DATA_TYPE.text, { alex_pp_hfsession: "alex_requestid" }),
        ppField("amount", "Amount", "סכום", false, DATA_TYPE.money, { invoice: "totalamount", quote: "totalamount", salesorder: "totalamount", opportunity: "estimatedvalue" }),
        ppField("currency_code", "Currency", "מטבע", false, DATA_TYPE.text, { invoice: "transactioncurrencyid", quote: "transactioncurrencyid", salesorder: "transactioncurrencyid" })
    ];
}

export class MappingStudio implements ComponentFramework.StandardControl<IInputs, IOutputs> {
    private context!: ComponentFramework.Context<IInputs>;
    private notifyOutputChanged!: () => void;
    private root!: HTMLDivElement;
    private profileId = "";
    private profile: ProfileInfo = { name: "", environment: "", isActive: false };
    private mappings: EntityMapping[] = [];
    private fields: FieldMapping[] = [];
    private transformRules: TransformRule[] = [];
    private selectedMappingId = "";
    private stats: SyncStats = { pending: 0, succeeded: 0, failed: 0, lastSync: "" };
    private isRtl = false;
    private status: "loading" | "ready" | "error" = "loading";
    private errorText = "";
    private busyText = "";
    private toastText = "";
    private fieldFilter = "";
    private missingOnly = false;
    private requiredOnly = false;
    private showAdvancedTargets = false;
    private newSource = "account";
    private newTarget = 100000000;
    private openCombo: ComboKind | "" = "";
    private comboQueries: Record<ComboKind, string> = { newSource: "", newTarget: "", editSource: "", editTarget: "" };
    private openFieldId = "";
    private fieldQueries: Record<string, string> = {};
    private comboPortal: HTMLDivElement | null = null;
    private sourceTables: SourceTable[] = SOURCE_TABLES;
    private sourceFieldsByTable = new Map<string, SourceField[]>();
    private metadataLoaded = false;
    private hostValue = "";
    private draft: DraftState | null = null;
    private operationId = 0;

    public init(
        context: ComponentFramework.Context<IInputs>,
        notifyOutputChanged: () => void,
        _state: ComponentFramework.Dictionary,
        container: HTMLDivElement
    ): void {
        this.context = context;
        this.notifyOutputChanged = notifyOutputChanged;
        this.hostValue = context.parameters.hostValue.raw || "";
        this.draft = this.parseDraft(this.hostValue);
        context.mode.trackContainerResize(true);
        this.isRtl = context.userSettings.languageId === 1037;
        this.root = document.createElement("div");
        this.root.className = "ppms";
        this.root.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
        container.appendChild(this.root);
        this.resolveProfileId();
        this.render();
        void this.loadAll();
    }

    public updateView(context: ComponentFramework.Context<IInputs>): void {
        this.context = context;
        this.hostValue = context.parameters.hostValue.raw || this.hostValue;
        const previous = this.profileId;
        this.resolveProfileId();
        if (this.profileId && this.profileId !== previous) {
            void this.loadAll();
        }
    }

    public getOutputs(): IOutputs {
        return { hostValue: this.hostValue };
    }

    public destroy(): void {
        this.closePortal();
        this.root.replaceChildren();
    }

    private resolveProfileId(): void {
        const ci =
            ((this.context.mode as unknown as { contextInfo?: ContextInfo }).contextInfo) ||
            ((this.context as unknown as { page?: ContextInfo }).page);
        this.profileId = (ci?.entityId || "").replace(/[{}]/g, "").toLowerCase();
    }

    private async loadAll(): Promise<void> {
        await this.loadSourceTables();
        await this.loadTransformRules();
        if (!this.profileId) {
            this.profile = { name: this.t("draftProfile"), environment: this.t("draftHint"), isActive: false };
            await this.ensureSourceFields(this.draft?.sourceLogical || this.newSource);
            this.loadDraftMapping();
            this.status = "ready";
            this.render();
            return;
        }
        const op = ++this.operationId;
        this.status = "loading";
        this.errorText = "";
        this.render();
        try {
            await Promise.all([this.loadProfile(), this.loadMappings()]);
            if (!this.mappings.length && this.draft) {
                await this.createMappingFromDraft();
                this.toast(this.t("draftSaved"));
            }
            if (!this.selectedMappingId && this.mappings.length) {
                this.selectedMappingId = this.mappings[0].id;
            }
            const selected = this.selectedMapping();
            if (selected) await this.ensureSourceFields(selected.sourceLogical);
            await Promise.all([this.loadFields(), this.loadStats()]);
            await this.ensureTargetFieldsForSelected();
            if (op === this.operationId) {
                this.status = "ready";
                this.render();
            }
        } catch (error) {
            if (op === this.operationId) {
                this.status = "error";
                this.errorText = this.errorMessage(error);
                this.render();
            }
        }
    }

    private async loadProfile(): Promise<void> {
        const row = await this.context.webAPI.retrieveRecord("alex_payplus_syncprofile", this.profileId, "?$select=alex_name,alex_environment,alex_isactive");
        this.profile = {
            name: this.textValue(row, "alex_name") || this.t("profileFallback"),
            environment: this.formatted(row, "alex_environment") || this.textValue(row, "alex_environment"),
            isActive: row["alex_isactive"] === true
        };
    }

    private async loadMappings(): Promise<void> {
        const filter = encodeURIComponent(`_alex_syncprofileid_value eq ${this.profileId}`);
        const query = "?$select=alex_payplus_entitymappingid,alex_name,alex_sourcetablelogicalname,alex_sourcetabledisplayname,alex_targetobject,alex_isactive,alex_pluginstepstatus,modifiedon" +
            `&$filter=${filter}&$orderby=modifiedon desc`;
        const result = await this.context.webAPI.retrieveMultipleRecords("alex_payplus_entitymapping", query);
        this.mappings = result.entities.map((row) => this.parseMapping(row));
        if (this.selectedMappingId && !this.mappings.some((m) => m.id === this.selectedMappingId)) {
            this.selectedMappingId = this.mappings[0]?.id || "";
        }
    }

    private async loadFields(): Promise<void> {
        if (!this.selectedMappingId) {
            this.fields = [];
            return;
        }
        const filter = encodeURIComponent(`_alex_entitymappingid_value eq ${this.selectedMappingId}`);
        const query = "?$select=alex_payplus_fieldmappingid,alex_targetfieldlogicalname,alex_targetfielddisplayname,alex_sourcetype,alex_sourcefieldlogicalname,alex_sourcefielddisplayname,_alex_transformruleid_value,alex_defaultvalue,alex_requiredforpayload,alex_payplusdatatype,alex_dataversetype,alex_isactive,alex_sortorder" +
            `&$filter=${filter}&$orderby=alex_sortorder asc,createdon asc`;
        const result = await this.context.webAPI.retrieveMultipleRecords("alex_payplus_fieldmapping", query);
        this.fields = result.entities.map((row) => this.parseField(row));
    }

    private async loadTransformRules(): Promise<void> {
        try {
            const query = "?$select=alex_payplus_transformruleid,alex_name,alex_expression,alex_outputtype,alex_isactive&$filter=statecode eq 0&$orderby=alex_name asc";
            const result = await this.context.webAPI.retrieveMultipleRecords("alex_payplus_transformrule", query);
            this.transformRules = result.entities.map((row) => ({
                id: this.textValue(row, "alex_payplus_transformruleid"),
                name: this.textValue(row, "alex_name"),
                expression: this.textValue(row, "alex_expression"),
                outputType: row["alex_outputtype"] == null ? null : Number(row["alex_outputtype"]),
                isActive: row["alex_isactive"] !== false
            })).filter((rule) => rule.id && rule.name && rule.isActive);
        } catch {
            this.transformRules = [];
        }
    }

    private async loadStats(): Promise<void> {
        if (!this.profileId) return;
        let filter = `_alex_syncprofileid_value eq ${this.profileId}`;
        if (this.selectedMappingId) filter += ` and _alex_entitymappingid_value eq ${this.selectedMappingId}`;
        const query = "?$select=alex_status,alex_processedon,modifiedon" +
            `&$filter=${encodeURIComponent(filter)}&$top=5000&$orderby=modifiedon desc`;
        const result = await this.context.webAPI.retrieveMultipleRecords("alex_payplus_syncoutbox", query);
        let pending = 0;
        let succeeded = 0;
        let failed = 0;
        let lastSync = "";
        result.entities.forEach((row) => {
            const status = Number(row["alex_status"] || -1);
            if (status === 100000002) succeeded += 1;
            else if (status === 100000003) failed += 1;
            else if ([100000000, 100000001, 100000004].includes(status)) pending += 1;
            const formatted = this.formatted(row, "alex_processedon") || this.formatted(row, "modifiedon");
            if (!lastSync && formatted) lastSync = formatted;
        });
        this.stats = { pending, succeeded, failed, lastSync };
    }

    private async loadSourceTables(): Promise<void> {
        if (this.metadataLoaded) return;
        this.metadataLoaded = true;
        try {
            const query = "?$select=LogicalName,DisplayName,EntitySetName,IsIntersect&$filter=IsIntersect eq false";
            const entities = await this.retrieveMetadata(`EntityDefinitions${query}`);
            const tables = entities
                .map((row) => this.parseSourceTable(row))
                .filter((sourceTable): sourceTable is SourceTable => !!sourceTable)
                .sort((left, right) => this.sourceOptionLabel(left).localeCompare(this.sourceOptionLabel(right), this.isRtl ? "he" : "en"));
            if (tables.length) {
                this.sourceTables = tables;
                if (!this.sourceTable(this.newSource)) {
                    this.newSource = this.sourceTable("account")?.logical || tables[0].logical;
                }
            }
        } catch {
            this.sourceTables = SOURCE_TABLES;
        }
    }

    private parseSourceTable(row: ComponentFramework.WebApi.Entity): SourceTable | null {
        const logical = this.metadataText(row, "LogicalName");
        if (!logical) return null;
        const fallback = SOURCE_TABLES.find((sourceTable) => sourceTable.logical === logical);
        const displayName = row["DisplayName"] as DataverseLabel | undefined;
        return {
            logical,
            en: this.metadataLabel(displayName, 1033, fallback?.en || logical),
            he: this.metadataLabel(displayName, 1037, fallback?.he || fallback?.en || logical),
            fields: fallback?.fields || []
        };
    }

    private async ensureSourceFields(sourceLogical: string): Promise<void> {
        if (!sourceLogical || this.sourceFieldsByTable.has(sourceLogical)) return;
        try {
            const query = "?$select=LogicalName,DisplayName,AttributeType,AttributeTypeName,IsValidForRead,IsLogical,IsPrimaryId&$filter=IsValidForRead eq true";
            const entities = await this.retrieveMetadata(`EntityDefinitions(LogicalName='${this.odataString(sourceLogical)}')/Attributes${query}`);
            const fields = entities
                .map((row) => this.parseSourceField(row))
                .filter((field): field is SourceField => !!field)
                .sort((left, right) => this.label(left).localeCompare(this.label(right), this.isRtl ? "he" : "en"));
            this.sourceFieldsByTable.set(sourceLogical, fields.length ? fields : (this.sourceTable(sourceLogical)?.fields || []));
        } catch {
            this.sourceFieldsByTable.set(sourceLogical, this.sourceTable(sourceLogical)?.fields || []);
        }
    }

    private parseSourceField(row: ComponentFramework.WebApi.Entity): SourceField | null {
        const logical = this.metadataText(row, "LogicalName");
        if (!logical) return null;
        const displayName = row["DisplayName"] as DataverseLabel | undefined;
        return {
            logical,
            en: this.metadataLabel(displayName, 1033, logical),
            he: this.metadataLabel(displayName, 1037, this.metadataLabel(displayName, 1033, logical)),
            type: this.dataTypeFromAttribute(row)
        };
    }

    private async retrieveMetadata(path: string): Promise<ComponentFramework.WebApi.Entity[]> {
        const response = await fetch(`${this.clientUrl()}/api/data/v9.2/${path}`, {
            method: "GET",
            credentials: "same-origin",
            headers: {
                Accept: "application/json",
                "OData-MaxVersion": "4.0",
                "OData-Version": "4.0"
            }
        });
        if (!response.ok) throw new Error(`Metadata request failed: ${response.status}`);
        const body = await response.json() as { value?: ComponentFramework.WebApi.Entity[] };
        return body.value || [];
    }

    private clientUrl(): string {
        const parentContext = (window.parent as unknown as { Xrm?: { Utility?: { getGlobalContext?: () => { getClientUrl?: () => string } } } }).Xrm?.Utility?.getGlobalContext?.();
        const ownContext = (window as unknown as { Xrm?: { Utility?: { getGlobalContext?: () => { getClientUrl?: () => string } } } }).Xrm?.Utility?.getGlobalContext?.();
        return (parentContext?.getClientUrl?.() || ownContext?.getClientUrl?.() || "").replace(/\/$/, "");
    }

    private odataString(value: string): string {
        return value.replace(/'/g, "''");
    }

    private dataTypeFromAttribute(row: ComponentFramework.WebApi.Entity): number {
        const typeName = ((row["AttributeTypeName"] as { Value?: string } | undefined)?.Value || "").toLowerCase();
        const attributeType = this.metadataText(row, "AttributeType").toLowerCase();
        if (typeName.includes("money") || attributeType === "money") return DATA_TYPE.money;
        if (typeName.includes("datetime") || attributeType === "datetime") return DATA_TYPE.dateTime;
        if (["lookup", "customer", "owner"].some((type) => typeName.includes(type) || attributeType === type)) return DATA_TYPE.lookup;
        if (["picklist", "status", "state"].some((type) => typeName.includes(type) || attributeType === type)) return DATA_TYPE.choice;
        if (typeName.includes("boolean") || attributeType === "boolean") return DATA_TYPE.boolean;
        if (["decimal", "double"].some((type) => typeName.includes(type) || attributeType === type)) return DATA_TYPE.decimal;
        if (["integer", "bigint"].some((type) => typeName.includes(type) || attributeType === type)) return DATA_TYPE.number;
        if (typeName.includes("partylist") || attributeType === "partylist") return DATA_TYPE.array;
        return DATA_TYPE.text;
    }

    private metadataLabel(label: DataverseLabel | undefined, languageCode: number, fallback: string): string {
        return label?.LocalizedLabels?.find((localized) => localized.LanguageCode === languageCode)?.Label || label?.UserLocalizedLabel?.Label || fallback;
    }

    private metadataText(row: ComponentFramework.WebApi.Entity, key: string): string {
        const value = row[key] ?? row[key.charAt(0).toLowerCase() + key.slice(1)];
        return value == null ? "" : String(value);
    }

    private parseMapping(row: ComponentFramework.WebApi.Entity): EntityMapping {
        const targetValue = row["alex_targetobject"] == null ? null : Number(row["alex_targetobject"]);
        return {
            id: this.textValue(row, "alex_payplus_entitymappingid"),
            name: this.textValue(row, "alex_name"),
            sourceLogical: this.textValue(row, "alex_sourcetablelogicalname"),
            sourceDisplay: this.textValue(row, "alex_sourcetabledisplayname"),
            targetValue,
            targetLabel: this.formatted(row, "alex_targetobject"),
            isActive: row["alex_isactive"] === true,
            pluginStepStatus: row["alex_pluginstepstatus"] == null ? null : Number(row["alex_pluginstepstatus"])
        };
    }

    private parseField(row: ComponentFramework.WebApi.Entity): FieldMapping {
        return {
            id: this.textValue(row, "alex_payplus_fieldmappingid"),
            targetLogical: this.textValue(row, "alex_targetfieldlogicalname"),
            targetDisplay: this.textValue(row, "alex_targetfielddisplayname"),
            sourceType: row["alex_sourcetype"] == null ? this.inferSourceType(this.textValue(row, "alex_sourcefieldlogicalname")) : Number(row["alex_sourcetype"]),
            sourceLogical: this.textValue(row, "alex_sourcefieldlogicalname"),
            sourceDisplay: this.textValue(row, "alex_sourcefielddisplayname"),
            transformRuleId: this.textValue(row, "_alex_transformruleid_value"),
            transformRuleName: this.formatted(row, "_alex_transformruleid_value"),
            defaultValue: this.textValue(row, "alex_defaultvalue"),
            required: row["alex_requiredforpayload"] === true,
            payplusType: row["alex_payplusdatatype"] == null ? null : Number(row["alex_payplusdatatype"]),
            dataverseType: row["alex_dataversetype"] == null ? null : Number(row["alex_dataversetype"]),
            isActive: row["alex_isactive"] === true
        };
    }

    private render(): void {
        this.closePortal();
        this.root.innerHTML = this.shellHtml();
        this.bindEvents();
    }

    private renderAndFocus(inputId: string): void {
        this.render();
        window.setTimeout(() => {
            const input = this.byId(inputId) as HTMLInputElement | null;
            if (!input) return;
            input.focus();
            input.setSelectionRange(input.value.length, input.value.length);
        }, 0);
    }

    private shellHtml(): string {
        const body = this.status === "loading" ? this.stateHtml("loading") : this.status === "error" ? this.stateHtml("error") : this.readyHtml();
        return `<div class="ppms-card">${this.headerHtml()}${body}${this.busyText ? `<div class="ppms-busy"><span class="ppms-spinner"></span>${this.esc(this.busyText)}</div>` : ""}${this.toastText ? `<div class="ppms-toast">${this.esc(this.toastText)}</div>` : ""}</div>`;
    }

    private headerHtml(): string {
        const active = this.profile.isActive ? this.t("active") : this.t("inactive");
        return `<div class="ppms-head"><div class="ppms-brand"><span class="ppms-mark">P+</span><span><span class="ppms-kicker">${this.esc(this.t("kicker"))}</span><strong>${this.esc(this.t("title"))}</strong></span></div><div class="ppms-profile"><span>${this.esc(this.profile.name || this.t("profileFallback"))}</span><span>${this.esc(this.profile.environment || this.t("environmentUnknown"))}</span><span>${this.esc(active)}</span></div><button class="ppms-iconbtn" id="ppms-refresh" type="button" title="${this.esc(this.t("refresh"))}">${this.iconRefresh()}</button></div>`;
    }

    private stateHtml(kind: "loading" | "error"): string {
        const title = kind === "loading" ? this.t("loading") : this.t("loadError");
        const detail = kind === "loading" ? this.t("loadingDetail") : (this.errorText || this.t("loadErrorDetail"));
        return `<div class="ppms-state"><div class="ppms-state-icon">${kind === "loading" ? "" : "!"}</div><strong>${this.esc(title)}</strong><span>${this.esc(detail)}</span></div>`;
    }

    private readyHtml(): string {
        return `${this.stepperHtml()}<div class="ppms-workspace">${this.sourcesHtml()}${this.mappingHtml()}${this.inspectorHtml()}</div>`;
    }

    private stepperHtml(): string {
        const selected = this.selectedMapping();
        const hasSource = !!selected?.sourceLogical;
        const hasTarget = selected?.targetValue != null;
        const mapped = this.fields.some((f) => f.sourceLogical);
        const canActivate = hasSource && hasTarget && mapped && this.requiredMissing().length === 0;
        const steps = [["1", this.t("stepSource"), hasSource], ["2", this.t("stepTarget"), hasTarget], ["3", this.t("stepMapping"), mapped], ["4", this.t("stepActivate"), canActivate]];
        return `<div class="ppms-steps">${steps.map((s) => `<span class="${s[2] ? "done" : ""}"><b>${s[0]}</b>${this.esc(String(s[1]))}</span>`).join("")}</div>`;
    }

    private sourcesHtml(): string {
        return `<aside class="ppms-pane ppms-sidebar"><div class="ppms-pane-head"><strong>${this.esc(this.t("sourceTables"))}</strong><span>${this.esc(this.t("sourceTablesHint"))}</span></div><div class="ppms-pane-body"><div class="ppms-list">${this.mappings.length ? this.mappings.map((m) => this.sourceItemHtml(m)).join("") : `<div class="ppms-empty">${this.esc(this.t("noTables"))}</div>`}</div>${this.addBoxHtml()}</div></aside>`;
    }

    private addBoxHtml(): string {
        return `<div class="ppms-addbox"><label>${this.esc(this.t("addSource"))}</label>${this.sourceComboHtml("ppms-new-source", "newSource", this.newSource, this.t("addSource"))}<div class="ppms-target-head"><span>${this.esc(this.t("addTarget"))}</span>${this.advancedTargetsToggleHtml()}</div>${this.targetComboHtml("ppms-new-target", "newTarget", this.newTarget, this.t("addTarget"))}<button class="ppms-btn" id="ppms-add-mapping" type="button">${this.esc(this.t("addMapping"))}</button></div>`;
    }

    private sourceItemHtml(mapping: EntityMapping): string {
        const selected = mapping.id === this.selectedMappingId;
        const ready = this.mappingReadiness(mapping);
        const stepOk = !mapping.isActive || mapping.pluginStepStatus === PLUGIN_REGISTERED;
        return `<button type="button" class="ppms-source ${selected ? "selected" : ""}" data-mapping-id="${this.esc(mapping.id)}"><span class="ppms-source-top"><span><b>${this.esc(mapping.sourceDisplay || mapping.sourceLogical || this.t("sourceMissing"))}</b><em>${this.esc(mapping.sourceLogical)}</em></span><i class="${mapping.isActive && stepOk ? "ok" : "warn"}"></i></span><span class="ppms-source-target">${this.esc(this.targetLabel(mapping.targetValue))}</span><span class="ppms-rail"><span style="width:${ready}%"></span></span></button>`;
    }

    private mappingHtml(): string {
        const selected = this.selectedMapping();
        if (!selected) return `<section class="ppms-pane ppms-main"><div class="ppms-empty ppms-large-empty">${this.esc(this.t("createFirstMapping"))}</div></section>`;
        const syncButtonText = selected.isActive ? this.t("deactivateSync") : this.t("activateSync");
        const lockHint = selected.isActive ? `<div class="ppms-lock-note">${this.esc(this.t("activeSyncLock"))}</div>` : "";
        const editDisabled = selected.isActive ? "disabled" : "";
        return `<section class="ppms-pane ppms-main">${this.advancedWarningHtml(selected)}${lockHint}<div class="ppms-main-head"><div><strong>${this.esc(selected.sourceDisplay || selected.sourceLogical)}</strong><span>${this.esc(this.t("sourceToTarget"))}: ${this.esc(selected.sourceLogical)} -> ${this.esc(this.targetLabel(selected.targetValue))}</span></div><div class="ppms-actions"><button class="ppms-btn" id="ppms-auto-map" type="button" ${editDisabled}>${this.esc(this.t("autoMap"))}</button><button class="ppms-btn" id="ppms-validate" type="button">${this.esc(this.t("validate"))}</button><button class="ppms-btn" id="ppms-register-steps" type="button" ${editDisabled}>${this.esc(this.t("registerSteps"))}</button><button class="ppms-btn ppms-primary" id="ppms-activate" type="button">${this.esc(syncButtonText)}</button></div></div>${this.mappingSelectorsHtml(selected)}${this.mappingFiltersHtml()}${this.fieldOptionsHtml(selected)}<div class="ppms-grid"><div class="ppms-row ppms-grid-head"><span>${this.esc(this.t("payplusField"))}</span><span>${this.esc(this.t("sourceType"))}</span><span>${this.esc(this.t("dynamicsField"))}</span><span>${this.esc(this.t("required"))}</span><span>${this.esc(this.t("status"))}</span><span>${this.esc(this.t("actions"))}</span></div>${this.fieldRowsHtml(selected)}</div></section>`;
    }

    private advancedWarningHtml(mapping: EntityMapping): string {
        if (!this.target(mapping.targetValue)?.advanced) return "";
        return `<div class="ppms-warning"><span class="ppms-warning-triangle"></span><strong>${this.esc(this.t("advancedTargets"))}</strong><span>${this.esc(this.t("advancedSyncWarning"))}</span></div>`;
    }

    private mappingSelectorsHtml(selected: EntityMapping): string {
        const targetValue = selected.targetValue ?? this.newTarget;
        return `<div class="ppms-selectors"><label><span>${this.esc(this.t("sourceTable"))}</span>${this.sourceComboHtml("ppms-edit-source", "editSource", selected.sourceLogical, this.t("sourceTable"), selected.isActive)}</label><label><span>${this.esc(this.t("payplusTarget"))}</span>${this.targetComboHtml("ppms-edit-target", "editTarget", targetValue, this.t("payplusTarget"), selected.isActive)}</label></div>`;
    }

    private advancedTargetsToggleHtml(): string {
        return `<label class="ppms-check ppms-advanced-targets-label"><input type="checkbox" class="ppms-advanced-targets" ${this.showAdvancedTargets ? "checked" : ""} />${this.esc(this.t("advancedTargets"))}</label>`;
    }

    private mappingFiltersHtml(): string {
        return `<div class="ppms-filters"><input class="ppms-input" id="ppms-field-filter" value="${this.esc(this.fieldFilter)}" placeholder="${this.esc(this.t("searchField"))}" /><label class="ppms-check"><input type="checkbox" id="ppms-missing-only" ${this.missingOnly ? "checked" : ""} />${this.esc(this.t("missingOnly"))}</label><label class="ppms-check"><input type="checkbox" id="ppms-required-only" ${this.requiredOnly ? "checked" : ""} />${this.esc(this.t("requiredOnly"))}</label></div>`;
    }

    private fieldOptionsHtml(mapping: EntityMapping): string {
        return "";
    }

    private fieldRowsHtml(mapping: EntityMapping): string {
        const rows = this.visibleFields();
        if (!rows.length) return `<div class="ppms-empty">${this.esc(this.t("noFields"))}</div>`;
        return rows.map((row) => {
            const targetField = this.targetField(mapping.targetValue, row.targetLogical);
            const required = row.required || !!targetField?.required;
            const targetLabel = targetField ? this.label(targetField) : (row.targetDisplay || row.targetLogical);
            const sourceOk = this.rowHasValue(row);
            const help = row.targetLogical === "subject_code" ? `<span class="ppms-help" title="${this.esc(this.t("subjectCodeHelp"))}" aria-label="${this.esc(this.t("subjectCodeHelp"))}">i</span>` : "";
            const editDisabled = mapping.isActive ? "disabled" : "";
            return `<div class="ppms-row ${mapping.isActive ? "ppms-locked-row" : ""}" data-field-id="${this.esc(row.id)}"><span class="ppms-fixed-field"><b>${this.esc(`${targetLabel} - ${row.targetLogical}`)}${help}</b></span><span>${this.sourceTypeSelectHtml(row, mapping.isActive)}</span><span>${this.sourceValueHtml(mapping.sourceLogical, row, mapping.isActive)}</span><span><b class="ppms-pill ${required ? "danger" : ""}">${this.esc(required ? this.t("requiredYes") : this.t("requiredNo"))}</b></span><span><b class="ppms-status ${sourceOk ? "ok" : "warn"}">${this.esc(sourceOk ? this.t("mapped") : this.t("notMapped"))}</b></span><span><button class="ppms-clear-field" type="button" data-field-id="${this.esc(row.id)}" ${sourceOk && !mapping.isActive ? "" : "disabled"} ${editDisabled}>${this.esc(this.t("clearMapping"))}</button></span></div>`;
        }).join("");
    }

    private inspectorHtml(): string {
        const selected = this.selectedMapping();
        const missing = this.requiredMissing();
        return `<aside class="ppms-pane ppms-inspector"><div class="ppms-pane-head"><strong>${this.esc(this.t("statusPanel"))}</strong><span>${this.esc(this.t("statusPanelHint"))}</span></div><div class="ppms-pane-body"><div class="ppms-metrics"><div><b>${this.esc(this.stats.lastSync || this.t("dash"))}</b><span>${this.esc(this.t("lastSync"))}</span></div><div><b>${this.stats.pending}</b><span>${this.esc(this.t("pending"))}</span></div><div><b>${this.stats.succeeded}</b><span>${this.esc(this.t("succeeded"))}</span></div><div><b>${this.stats.failed}</b><span>${this.esc(this.t("failed"))}</span></div></div><div class="ppms-checks"><div class="${selected?.sourceLogical ? "ok" : "warn"}">${this.esc(this.t("checkSource"))}</div><div class="${selected?.targetValue != null ? "ok" : "warn"}">${this.esc(this.t("checkTarget"))}</div><div class="${missing.length ? "warn" : "ok"}">${this.esc(missing.length ? this.t("checkRequiredWarn") : this.t("checkRequiredOk"))}</div></div><details class="ppms-dev"><summary>${this.esc(this.t("showPayload"))}</summary><pre>${this.esc(this.payloadPreview())}</pre></details></div></aside>`;
    }

    private bindEvents(): void {
        this.byId("ppms-refresh")?.addEventListener("click", () => { void this.loadAll(); });
        this.byId("ppms-field-filter")?.addEventListener("input", (event) => { this.fieldFilter = (event.target as HTMLInputElement).value; this.render(); });
        this.byId("ppms-missing-only")?.addEventListener("change", (event) => { this.missingOnly = (event.target as HTMLInputElement).checked; this.render(); });
        this.byId("ppms-required-only")?.addEventListener("change", (event) => { this.requiredOnly = (event.target as HTMLInputElement).checked; this.render(); });
        this.root.querySelectorAll<HTMLButtonElement>(".ppms-source[data-mapping-id]").forEach((button) => button.addEventListener("click", () => { void this.selectMapping(button.dataset.mappingId || ""); }));
        this.bindComboInputs();
        this.byId("ppms-add-mapping")?.addEventListener("click", () => { void this.addMapping(); });
        this.byId("ppms-auto-map")?.addEventListener("click", () => { void this.applyAutoMap(); });
        this.byId("ppms-validate")?.addEventListener("click", () => this.validateSelected());
        this.byId("ppms-register-steps")?.addEventListener("click", () => { void this.registerSelectedSteps(); });
        this.byId("ppms-activate")?.addEventListener("click", () => { void this.activateSelected(); });
        this.root.querySelectorAll<HTMLInputElement>(".ppms-advanced-targets").forEach((input) => {
            input.addEventListener("change", () => { this.showAdvancedTargets = input.checked; this.render(); });
        });
        this.root.querySelectorAll<HTMLSelectElement>(".ppms-source-type[data-field-id]").forEach((select) => {
            select.addEventListener("change", () => { void this.updateFieldSourceType(select.dataset.fieldId || "", Number(select.value)); });
        });
        this.root.querySelectorAll<HTMLInputElement>(".ppms-default-value[data-field-id]").forEach((input) => {
            input.addEventListener("change", () => { void this.updateFieldDefaultValue(input.dataset.fieldId || "", input.value); });
        });
        this.root.querySelectorAll<HTMLSelectElement>(".ppms-transform-rule[data-field-id]").forEach((select) => {
            select.addEventListener("change", () => { void this.updateFieldTransformRule(select.dataset.fieldId || "", select.value); });
        });
        this.root.querySelectorAll<HTMLButtonElement>(".ppms-clear-field[data-field-id]").forEach((button) => {
            button.addEventListener("click", () => { void this.clearFieldMapping(button.dataset.fieldId || ""); });
        });
        this.bindFieldCombos();
    }

    private async selectMapping(id: string): Promise<void> {
        if (!id || id === this.selectedMappingId) return;
        this.selectedMappingId = id;
        this.fields = [];
        this.render();
        await this.ensureSourceFields(this.selectedMapping()?.sourceLogical || "");
        await Promise.all([this.loadFields(), this.loadStats()]);
        await this.ensureTargetFieldsForSelected();
        this.render();
    }

    private async addMapping(): Promise<void> {
        this.commitComboQuery("newSource");
        this.commitComboQuery("newTarget");
        const sourceLogical = this.newSource.trim();
        const targetDef = this.target(this.newTarget);
        if (!sourceLogical || !targetDef) {
            this.toast(this.t("missingSourceTarget"));
            return;
        }
        await this.ensureSourceFields(sourceLogical);
        const sourceDef = this.sourceTable(sourceLogical);
        const sourceDisplay = sourceDef ? this.label(sourceDef) : sourceLogical;
        if (!this.profileId) {
            this.createDraft(sourceLogical, targetDef.value);
            this.toast(this.t("draftMappingCreated"));
            return;
        }
        await this.runBusy(this.t("creatingMapping"), async () => {
            const created = await this.context.webAPI.createRecord("alex_payplus_entitymapping", {
                alex_name: `${sourceDisplay} -> ${this.label(targetDef)}`,
                alex_sourcetablelogicalname: sourceLogical,
                alex_sourcetabledisplayname: sourceDisplay,
                alex_targetobject: targetDef.value,
                alex_allowcreate: true,
                alex_allowupdate: true,
                alex_isactive: false,
                alex_changehandlingmode: CHANGE_CURRENT_STATE,
                alex_coalesceupdates: true,
                alex_missinguidpolicy: MISSING_UID_CREATE,
                alex_pluginstepstatus: this.pluginStepStatusForSource(sourceLogical),
                "alex_syncprofileid@odata.bind": `/alex_payplus_syncprofiles(${this.profileId})`
            });
            this.selectedMappingId = created.id.replace(/[{}]/g, "").toLowerCase();
            await this.loadMappings();
            await this.applyAutoMap(false);
        });
        this.toast(this.t("mappingCreated"));
    }

    private async updateSelectedSource(sourceLogical: string): Promise<void> {
        const selected = this.selectedMapping();
        if (!selected || !sourceLogical || sourceLogical === selected.sourceLogical) return;
        if (!this.ensureEditable(selected)) return;
        await this.ensureSourceFields(sourceLogical);
        const sourceDef = this.sourceTable(sourceLogical);
        const display = sourceDef ? this.label(sourceDef) : sourceLogical;
        if (!this.profileId) {
            this.createDraft(sourceLogical, selected.targetValue ?? this.newTarget);
            return;
        }
        await this.runBusy(this.t("savingChanges"), async () => {
            await this.context.webAPI.updateRecord("alex_payplus_entitymapping", selected.id, {
                alex_sourcetablelogicalname: sourceLogical,
                alex_sourcetabledisplayname: display,
                alex_name: `${display} -> ${this.targetLabel(selected.targetValue)}`,
                alex_pluginstepstatus: this.pluginStepStatusForSource(sourceLogical)
            });
            await this.loadMappings();
            await this.applyAutoMap(false);
        });
    }

    private async updateSelectedTarget(targetValue: number): Promise<void> {
        const selected = this.selectedMapping();
        const targetDef = this.target(targetValue);
        if (!selected || !targetDef || targetValue === selected.targetValue) return;
        if (!this.ensureEditable(selected)) return;
        if (!this.profileId) {
            this.createDraft(selected.sourceLogical || this.newSource, targetValue);
            return;
        }
        await this.runBusy(this.t("savingChanges"), async () => {
            await this.context.webAPI.updateRecord("alex_payplus_entitymapping", selected.id, {
                alex_targetobject: targetValue,
                alex_name: `${selected.sourceDisplay || selected.sourceLogical} -> ${this.label(targetDef)}`
            });
            await this.loadMappings();
        });
    }

    private async applyAutoMap(showToast = true): Promise<void> {
        const selected = this.selectedMapping();
        const targetDef = this.target(selected?.targetValue ?? null);
        if (!selected || !targetDef) return;
        if (!this.ensureEditable(selected)) return;
        if (!this.profileId) {
            this.createDraft(selected.sourceLogical || this.newSource, targetDef.value);
            if (showToast) this.toast(this.t("autoMapDone"));
            return;
        }
        await this.runBusy(this.t("autoMappingBusy"), async () => {
            const existing = new Map(this.fields.map((f) => [f.targetLogical, f]));
            for (let index = 0; index < targetDef.fields.length; index += 1) {
                const targetField = targetDef.fields[index];
                const choice = this.autoMapChoice(targetField, selected.sourceLogical);
                const payload = this.fieldPayload(selected.id, targetField, choice.sourceLogical, choice.sourceField, index + 1, choice);
                const current = existing.get(targetField.logical);
                if (current) await this.context.webAPI.updateRecord("alex_payplus_fieldmapping", current.id, payload);
                else await this.context.webAPI.createRecord("alex_payplus_fieldmapping", payload);
            }
            await Promise.all([this.loadFields(), this.loadStats()]);
        });
        if (showToast) this.toast(this.t("autoMapDone"));
    }

    private async ensureTargetFieldsForSelected(): Promise<void> {
        const selected = this.selectedMapping();
        const targetDef = this.target(selected?.targetValue ?? null);
        if (!this.profileId || !selected || !targetDef) return;
        const existing = new Set(this.fields.map((field) => field.targetLogical));
        const missing = targetDef.fields.filter((field) => !existing.has(field.logical));
        if (!missing.length) return;
        for (let index = 0; index < missing.length; index += 1) {
            const targetField = missing[index];
            const choice = this.autoMapChoice(targetField, selected.sourceLogical);
            await this.context.webAPI.createRecord("alex_payplus_fieldmapping", this.fieldPayload(selected.id, targetField, choice.sourceLogical, choice.sourceField, this.fields.length + index + 1, choice));
        }
        await this.loadFields();
    }

    private async updateFieldSource(fieldId: string, sourceLogical: string): Promise<void> {
        const selected = this.selectedMapping();
        const row = this.fields.find((f) => f.id === fieldId);
        if (!selected || !row) return;
        if (!this.ensureEditable(selected)) return;
        const sourceDef = this.sourceFieldForRow(selected.sourceLogical, sourceLogical, row);
        const sourceType = row.sourceType === SOURCE_TYPE_FIELD ? this.inferSourceType(sourceLogical) : row.sourceType;
        if (!this.profileId) {
            row.sourceLogical = sourceLogical;
            row.sourceDisplay = sourceDef ? this.label(sourceDef) : sourceLogical;
            row.sourceType = sourceType;
            this.writeDraftFromCurrent();
            this.render();
            return;
        }
        await this.runBusy(this.t("savingChanges"), async () => {
            await this.context.webAPI.updateRecord("alex_payplus_fieldmapping", fieldId, {
                alex_sourcetype: sourceType,
                alex_sourcefieldlogicalname: sourceLogical || null,
                alex_sourcefielddisplayname: sourceDef ? this.label(sourceDef) : sourceLogical || null,
                alex_dataversetype: sourceDef?.type ?? row.dataverseType ?? DATA_TYPE.text
            });
            await this.loadFields();
        });
    }

    private async updateFieldSourceType(fieldId: string, sourceType: number): Promise<void> {
        const selected = this.selectedMapping();
        const row = this.fields.find((field) => field.id === fieldId);
        if (!row || !this.sourceTypeOptions().some((option) => option.value === sourceType)) return;
        if (!this.ensureEditable(selected)) return;
        if (!this.profileId) {
            row.sourceType = sourceType;
            this.writeDraftFromCurrent();
            this.render();
            return;
        }
        await this.runBusy(this.t("savingChanges"), async () => {
            await this.context.webAPI.updateRecord("alex_payplus_fieldmapping", fieldId, { alex_sourcetype: sourceType });
            await this.loadFields();
        });
    }

    private async updateFieldDefaultValue(fieldId: string, value: string): Promise<void> {
        const selected = this.selectedMapping();
        const row = this.fields.find((field) => field.id === fieldId);
        if (!row) return;
        if (!this.ensureEditable(selected)) return;
        if (!this.profileId) {
            row.defaultValue = value;
            this.writeDraftFromCurrent();
            this.render();
            return;
        }
        await this.runBusy(this.t("savingChanges"), async () => {
            await this.context.webAPI.updateRecord("alex_payplus_fieldmapping", fieldId, { alex_defaultvalue: value || null });
            await this.loadFields();
        });
    }

    private async updateFieldTransformRule(fieldId: string, transformRuleId: string): Promise<void> {
        const selected = this.selectedMapping();
        const row = this.fields.find((field) => field.id === fieldId);
        const rule = this.transformRules.find((item) => item.id === transformRuleId) || null;
        if (!row) return;
        if (!this.ensureEditable(selected)) return;
        if (!this.profileId) {
            row.transformRuleId = transformRuleId;
            row.transformRuleName = rule?.name || "";
            this.writeDraftFromCurrent();
            this.render();
            return;
        }
        await this.runBusy(this.t("savingChanges"), async () => {
            await this.context.webAPI.updateRecord("alex_payplus_fieldmapping", fieldId, {
                "alex_transformruleid@odata.bind": transformRuleId ? `/alex_payplus_transformrules(${transformRuleId})` : null
            });
            await this.loadFields();
        });
    }

    private async clearFieldMapping(fieldId: string): Promise<void> {
        const selected = this.selectedMapping();
        const row = this.fields.find((field) => field.id === fieldId);
        if (!row) return;
        if (!this.ensureEditable(selected)) return;
        if (!this.profileId) {
            row.sourceLogical = "";
            row.sourceDisplay = "";
            row.sourceType = SOURCE_TYPE_FIELD;
            row.transformRuleId = "";
            row.transformRuleName = "";
            row.defaultValue = "";
            row.dataverseType = DATA_TYPE.text;
            this.writeDraftFromCurrent();
            this.render();
            return;
        }
        await this.runBusy(this.t("savingChanges"), async () => {
            await this.context.webAPI.updateRecord("alex_payplus_fieldmapping", fieldId, {
                alex_name: `${row.targetLogical} <- ${this.t("notMapped")}`,
                alex_sourcetype: SOURCE_TYPE_FIELD,
                alex_sourcefieldlogicalname: null,
                alex_sourcefielddisplayname: null,
                alex_defaultvalue: null,
                alex_dataversetype: DATA_TYPE.text,
                "alex_transformruleid@odata.bind": null
            });
            await this.loadFields();
        });
    }

    private async updateFieldTarget(fieldId: string, targetLogical: string): Promise<void> {
        const selected = this.selectedMapping();
        const row = this.fields.find((f) => f.id === fieldId);
        const targetField = this.targetField(selected?.targetValue ?? null, targetLogical);
        if (!selected || !row || !targetLogical) return;
        if (!this.ensureEditable(selected)) return;
        if (!this.profileId) {
            row.targetLogical = targetLogical;
            row.targetDisplay = targetField ? this.label(targetField) : targetLogical;
            row.required = targetField?.required ?? row.required;
            row.payplusType = targetField?.type ?? row.payplusType;
            this.writeDraftFromCurrent();
            this.render();
            return;
        }
        await this.runBusy(this.t("savingChanges"), async () => {
            await this.context.webAPI.updateRecord("alex_payplus_fieldmapping", fieldId, {
                alex_targetfieldlogicalname: targetLogical,
                alex_targetfielddisplayname: targetField ? this.label(targetField) : targetLogical,
                alex_requiredforpayload: targetField?.required ?? row.required,
                alex_payplusdatatype: targetField?.type ?? row.payplusType ?? DATA_TYPE.text
            });
            await this.loadFields();
        });
    }

    private validateSelected(): void {
        this.toast(this.requiredMissing().length ? this.t("validateWarn") : this.t("validateOk"));
    }

    private async activateSelected(): Promise<void> {
        const selected = this.selectedMapping();
        if (!selected) return;
        if (!this.profileId) {
            this.toast(this.t("draftMappingCreated"));
            return;
        }
        const nextActive = !selected.isActive;
        if (nextActive && this.requiredMissing().length) {
            this.toast(this.t("activateBlocked"));
            return;
        }
        await this.runBusy(nextActive ? this.t("activateBusy") : this.t("deactivateBusy"), async () => {
            if (nextActive) {
                await this.context.webAPI.updateRecord("alex_payplus_entitymapping", selected.id, { alex_pluginstepstatus: PLUGIN_NOT_REGISTERED });
                await this.reconcileSteps(selected.id);
                await this.loadMappings();
                const refreshed = this.mappings.find((mapping) => mapping.id === selected.id);
                if (refreshed?.pluginStepStatus !== PLUGIN_REGISTERED) throw new Error(this.t("activateNeedsRegisteredStep"));
                await this.context.webAPI.updateRecord("alex_payplus_entitymapping", selected.id, { alex_isactive: true });
            } else {
                await this.context.webAPI.updateRecord("alex_payplus_entitymapping", selected.id, {
                    alex_isactive: false,
                    alex_pluginstepstatus: PLUGIN_NOT_REQUIRED
                });
            }
            await this.loadMappings();
        });
        this.toast(nextActive ? this.t("activated") : this.t("deactivated"));
    }

    private async registerSelectedSteps(): Promise<void> {
        const selected = this.selectedMapping();
        if (!selected || !this.profileId) return;
        await this.runBusy(this.t("registerStepsBusy"), async () => {
            await this.reconcileSteps(selected.id);
            await this.loadMappings();
        });
        const refreshed = this.mappings.find((mapping) => mapping.id === selected.id);
        this.toast(refreshed?.pluginStepStatus === PLUGIN_REGISTERED ? this.t("registerStepsDone") : this.t("registerStepsFailed"));
    }

    private async reconcileSteps(mappingId: string): Promise<void> {
        const response = await fetch(`${this.clientUrl()}/api/data/v9.2/alex_ReconcilePayPlusSyncSteps`, {
            method: "POST",
            credentials: "same-origin",
            headers: {
                Accept: "application/json",
                "Content-Type": "application/json; charset=utf-8",
                "OData-MaxVersion": "4.0",
                "OData-Version": "4.0"
            },
            body: JSON.stringify({ EntityMappingId: mappingId })
        });
        if (!response.ok) throw new Error(await response.text());
    }

    private fieldPayload(mappingId: string, targetField: PayPlusField, sourceLogical: string, sourceField: SourceField | null, sortOrder: number, choice?: AutoMapChoice): ComponentFramework.WebApi.Entity {
        const sourceType = choice?.sourceType ?? this.inferSourceType(sourceLogical);
        const defaultValue = choice?.defaultValue ?? "";
        return {
            alex_name: `${targetField.logical} <- ${sourceLogical || defaultValue || this.t("notMapped")}`,
            alex_targetfieldlogicalname: targetField.logical,
            alex_targetfielddisplayname: this.label(targetField),
            alex_sourcefieldlogicalname: sourceLogical || null,
            alex_sourcefielddisplayname: sourceField ? this.label(sourceField) : null,
            alex_sourcetype: sourceType,
            alex_defaultvalue: defaultValue || null,
            alex_requiredforpayload: targetField.required,
            alex_payplusdatatype: targetField.type,
            alex_dataversetype: sourceField?.type ?? DATA_TYPE.text,
            alex_nullhandling: NULL_OMIT,
            alex_sortorder: sortOrder,
            alex_isactive: true,
            "alex_entitymappingid@odata.bind": `/alex_payplus_entitymappings(${mappingId})`
        };
    }

    private autoMapChoice(targetField: PayPlusField, sourceLogical: string): AutoMapChoice {
        const constant = this.autoMapConstant(targetField, sourceLogical);
        if (constant != null) {
            return { sourceLogical: "", sourceType: SOURCE_TYPE_CONSTANT, defaultValue: constant, sourceField: null };
        }
        const suggested = this.suggestedSourceForTarget(targetField, sourceLogical);
        const sourceField = this.sourceFieldForRow(sourceLogical, suggested);
        return { sourceLogical: suggested, sourceType: this.inferSourceType(suggested), defaultValue: "", sourceField };
    }

    private autoMapConstant(targetField: PayPlusField, sourceLogical: string): string | null {
        if (sourceLogical === "productpricelevel" && targetField.logical === "category_uids") return PRODUCT_DEFAULT_CATEGORY_UID;
        if (sourceLogical === "productpricelevel" && targetField.logical === "vat_type") return "0";
        if (sourceLogical === "productpricelevel" && targetField.logical === "valid") return "true";
        return null;
    }

    private suggestedSourceForTarget(targetField: PayPlusField, sourceLogical: string): string {
        const suggested = targetField.suggested[sourceLogical] || "";
        if (targetField.logical === "subject_code" && this.isDataverseGuidField(suggested)) return "";
        return suggested;
    }

    private ensureEditable(mapping: EntityMapping | null): boolean {
        if (!mapping?.isActive) return true;
        this.toast(this.t("activeSyncLock"));
        return false;
    }

    private isDataverseGuidField(sourceLogical: string): boolean {
        const leaf = sourceLogical.split(".").pop() || sourceLogical;
        return /(?:id)$/i.test(leaf) && !/(number|code)$/i.test(leaf);
    }

    private visibleFields(): FieldMapping[] {
        const q = this.fieldFilter.toLowerCase();
        return this.fields.filter((row) => {
            const value = [row.targetLogical, row.targetDisplay, row.sourceLogical, row.sourceDisplay, row.transformRuleName, this.sourceTypeLabel(row.sourceType), row.defaultValue].join(" ").toLowerCase();
            return (!q || value.includes(q)) && (!this.missingOnly || !this.rowHasValue(row)) && (!this.requiredOnly || row.required);
        });
    }

    private selectedMapping(): EntityMapping | null {
        return this.mappings.find((m) => m.id === this.selectedMappingId) || null;
    }

    private requiredMissing(): FieldMapping[] {
        return this.fields.filter((f) => f.required && !this.rowHasValue(f));
    }

    private mappingReadiness(mapping: EntityMapping): number {
        if (mapping.id !== this.selectedMappingId || !this.fields.length) return mapping.isActive ? 100 : 35;
        return Math.round((this.fields.filter((f) => this.rowHasValue(f)).length / this.fields.length) * 100);
    }

    private payloadPreview(): string {
        const selected = this.selectedMapping();
        const fields: Record<string, string> = {};
        this.fields.filter((f) => this.rowHasValue(f)).forEach((f) => { fields[f.targetLogical] = this.payloadValue(f); });
        return JSON.stringify({ source: selected?.sourceLogical || "", target: this.targetLabel(selected?.targetValue ?? null), operation: "upsert", fields }, null, 2);
    }

    private target(value: number | null): PayPlusTarget | null {
        return TARGETS.find((t) => t.value === value) || null;
    }

    private sourceTypeOptions(): { value: number; label: string }[] {
        return [
            { value: SOURCE_TYPE_FIELD, label: this.t("sourceTypeField") },
            { value: SOURCE_TYPE_CONSTANT, label: this.t("sourceTypeConstant") },
            { value: SOURCE_TYPE_FORMULA, label: this.t("sourceTypeFormula") },
            { value: SOURCE_TYPE_LOOKUP, label: this.t("sourceTypeLookup") },
            { value: SOURCE_TYPE_RELATED, label: this.t("sourceTypeRelated") },
            { value: SOURCE_TYPE_VALUE_MAPPING, label: this.t("sourceTypeValueMapping") }
        ];
    }

    private sourceTypeLabel(sourceType: number): string {
        return this.sourceTypeOptions().find((option) => option.value === sourceType)?.label || this.t("sourceTypeField");
    }

    private inferSourceType(sourceLogical: string): number {
        return sourceLogical.includes(".") ? SOURCE_TYPE_RELATED : SOURCE_TYPE_FIELD;
    }

    private rowHasValue(row: FieldMapping): boolean {
        if (row.sourceType === SOURCE_TYPE_CONSTANT) return !!row.defaultValue.trim();
        if (row.sourceType === SOURCE_TYPE_FORMULA) return !!row.sourceLogical && !!row.transformRuleId;
        return !!row.sourceLogical;
    }

    private payloadValue(row: FieldMapping): string {
        const baseValue = row.sourceType === SOURCE_TYPE_CONSTANT ? row.defaultValue : `@{${row.sourceLogical}}`;
        if (row.transformRuleId) return `@transform{${row.transformRuleName || row.transformRuleId}}(${baseValue})`;
        if (row.sourceType === SOURCE_TYPE_CONSTANT) return row.defaultValue;
        if (row.sourceType === SOURCE_TYPE_FORMULA) return row.transformRuleId ? `@transform{${row.transformRuleName || row.transformRuleId}}` : `=${row.defaultValue}`;
        if (row.sourceType === SOURCE_TYPE_RELATED) return `@related{${row.sourceLogical}}`;
        if (row.sourceType === SOURCE_TYPE_VALUE_MAPPING) return `@map{${row.sourceLogical}}`;
        return `@{${row.sourceLogical}}`;
    }

    private targetLabel(value: number | null): string {
        const targetDef = this.target(value);
        return targetDef ? this.label(targetDef) : this.t("targetMissing");
    }

    private targetField(value: number | null, logical: string): PayPlusField | null {
        return this.target(value)?.fields.find((f) => f.logical === logical) || null;
    }

    private sourceTable(logical: string): SourceTable | null {
        return this.sourceTables.find((t) => t.logical === logical) || SOURCE_TABLES.find((t) => t.logical === logical) || null;
    }

    private pluginStepStatusForSource(sourceLogical: string): number {
        return sourceLogical ? PLUGIN_NOT_REGISTERED : PLUGIN_NOT_REQUIRED;
    }

    private sourceFields(sourceLogical: string): SourceField[] {
        const tableDef = this.sourceTable(sourceLogical);
        const metadataFields = this.sourceFieldsByTable.get(sourceLogical) || [];
        const baseFields = metadataFields.length ? metadataFields : (tableDef?.fields || []);
        const extras = this.fields
            .filter((f) => f.sourceLogical && !baseFields.some((sf) => sf.logical === f.sourceLogical))
            .map((f) => source(f.sourceLogical, f.sourceDisplay || f.sourceLogical, f.sourceDisplay || f.sourceLogical, f.dataverseType || DATA_TYPE.text));
        return [...baseFields, ...extras];
    }

    private sourceField(sourceLogical: string, fieldLogical: string): SourceField | null {
        return this.sourceFields(sourceLogical).find((f) => f.logical === fieldLogical) || null;
    }

    private label(item: { en: string; he: string }): string {
        return this.isRtl ? item.he : item.en;
    }

    private textValue(row: ComponentFramework.WebApi.Entity, key: string): string {
        const value = row[key];
        return value == null ? "" : String(value);
    }

    private formatted(row: ComponentFramework.WebApi.Entity, key: string): string {
        return this.textValue(row, `${key}@OData.Community.Display.V1.FormattedValue`);
    }

    private byId(id: string): HTMLElement | null {
        return this.root.querySelector(`#${id}`);
    }

    private async runBusy(message: string, action: () => Promise<void>): Promise<void> {
        this.busyText = message;
        this.render();
        try {
            await action();
        } catch (error) {
            this.toast(this.errorMessage(error));
        } finally {
            this.busyText = "";
            this.render();
        }
    }

    private loadDraftMapping(): void {
        const sourceLogical = this.draft?.sourceLogical || this.newSource;
        const targetValue = this.draft?.targetValue ?? this.newTarget;
        const sourceDef = this.sourceTable(sourceLogical);
        const targetDef = this.target(targetValue);
        if (!this.draft) {
            this.mappings = [];
            this.fields = [];
            this.selectedMappingId = "";
            return;
        }
        this.mappings = [{
            id: "draft",
            name: `${sourceDef ? this.label(sourceDef) : sourceLogical} -> ${targetDef ? this.label(targetDef) : this.targetLabel(targetValue)}`,
            sourceLogical,
            sourceDisplay: sourceDef ? this.label(sourceDef) : sourceLogical,
            targetValue,
            targetLabel: this.targetLabel(targetValue),
            isActive: false,
            pluginStepStatus: PLUGIN_NOT_REQUIRED
        }];
        this.selectedMappingId = "draft";
        this.fields = (targetDef?.fields || []).map((targetField, index) => {
            const sourceLogicalForField = this.draft?.fields[targetField.logical] ?? this.suggestedSourceForTarget(targetField, sourceLogical);
            const sourceDefForField = this.sourceField(sourceLogical, sourceLogicalForField);
            return {
                id: `draft-${index}`,
                targetLogical: targetField.logical,
                targetDisplay: this.label(targetField),
                sourceType: this.inferSourceType(sourceLogicalForField),
                sourceLogical: sourceLogicalForField,
                sourceDisplay: sourceDefForField ? this.label(sourceDefForField) : sourceLogicalForField,
                transformRuleId: "",
                transformRuleName: "",
                defaultValue: "",
                required: targetField.required,
                payplusType: targetField.type,
                dataverseType: sourceDefForField?.type ?? DATA_TYPE.text,
                isActive: true
            };
        });
        this.stats = { pending: 0, succeeded: 0, failed: 0, lastSync: "" };
    }

    private createDraft(sourceLogical: string, targetValue: number): void {
        const targetDef = this.target(targetValue);
        const fields: Record<string, string> = {};
        (targetDef?.fields || []).forEach((targetField) => {
            fields[targetField.logical] = this.suggestedSourceForTarget(targetField, sourceLogical);
        });
        this.draft = { sourceLogical, targetValue, fields };
        this.persistDraft();
        this.loadDraftMapping();
        this.render();
    }

    private writeDraftFromCurrent(): void {
        const selected = this.selectedMapping();
        if (!selected) return;
        const fields: Record<string, string> = {};
        this.fields.forEach((field) => { fields[field.targetLogical] = field.sourceLogical; });
        this.draft = { sourceLogical: selected.sourceLogical, targetValue: selected.targetValue ?? this.newTarget, fields };
        this.persistDraft();
    }

    private persistDraft(): void {
        this.hostValue = this.draft ? JSON.stringify({ mappingStudioDraft: this.draft }) : "";
        this.notifyOutputChanged();
    }

    private parseDraft(value: string): DraftState | null {
        if (!value) return null;
        try {
            const parsed = JSON.parse(value) as { mappingStudioDraft?: DraftState };
            if (parsed.mappingStudioDraft?.sourceLogical && parsed.mappingStudioDraft.targetValue != null) {
                return parsed.mappingStudioDraft;
            }
        } catch {
            return null;
        }
        return null;
    }

    private async createMappingFromDraft(): Promise<void> {
        if (!this.draft || !this.profileId) return;
        await this.ensureSourceFields(this.draft.sourceLogical);
        const sourceDef = this.sourceTable(this.draft.sourceLogical);
        const targetDef = this.target(this.draft.targetValue);
        if (!targetDef) return;
        const sourceDisplay = sourceDef ? this.label(sourceDef) : this.draft.sourceLogical;
        const created = await this.context.webAPI.createRecord("alex_payplus_entitymapping", {
            alex_name: `${sourceDisplay} -> ${this.label(targetDef)}`,
            alex_sourcetablelogicalname: this.draft.sourceLogical,
            alex_sourcetabledisplayname: sourceDisplay,
            alex_targetobject: targetDef.value,
            alex_allowcreate: true,
            alex_allowupdate: true,
            alex_isactive: false,
            alex_changehandlingmode: CHANGE_CURRENT_STATE,
            alex_coalesceupdates: true,
            alex_missinguidpolicy: MISSING_UID_CREATE,
            alex_pluginstepstatus: this.pluginStepStatusForSource(this.draft.sourceLogical),
            "alex_syncprofileid@odata.bind": `/alex_payplus_syncprofiles(${this.profileId})`
        });
        const mappingId = created.id.replace(/[{}]/g, "").toLowerCase();
        for (let index = 0; index < targetDef.fields.length; index += 1) {
            const targetField = targetDef.fields[index];
            const sourceLogical = this.draft.fields[targetField.logical] || this.suggestedSourceForTarget(targetField, this.draft.sourceLogical);
            const sourceDefForField = this.sourceField(this.draft.sourceLogical, sourceLogical);
            await this.context.webAPI.createRecord("alex_payplus_fieldmapping", this.fieldPayload(mappingId, targetField, sourceLogical, sourceDefForField, index + 1));
        }
        this.selectedMappingId = mappingId;
        this.draft = null;
        this.persistDraft();
        await this.loadMappings();
    }

    private bindComboInputs(): void {
        this.root.querySelectorAll<HTMLInputElement>(".ppms-combo-input[data-combo]").forEach((input) => {
            const combo = input.dataset.combo as ComboKind;
            input.addEventListener("focus", () => this.openComboInput(combo, input));
            input.addEventListener("input", () => this.typeComboInput(combo, input, input.value));
            input.addEventListener("keydown", (event) => { void this.handleComboKey(event, combo); });
            input.addEventListener("blur", () => window.setTimeout(() => this.closeCombo(combo, input), 160));
        });
    }

    private bindFieldCombos(): void {
        this.root.querySelectorAll<HTMLInputElement>(".ppms-field-input[data-field-id]").forEach((input) => {
            const fieldId = input.dataset.fieldId || "";
            input.addEventListener("focus", () => this.openFieldCombo(fieldId, input));
            input.addEventListener("input", () => this.typeFieldCombo(fieldId, input, input.value));
            input.addEventListener("keydown", (event) => { void this.handleFieldKey(event, fieldId); });
            input.addEventListener("blur", () => window.setTimeout(() => this.closeFieldCombo(fieldId, input), 160));
        });
    }

    private openComboInput(combo: ComboKind, input: HTMLInputElement): void {
        this.openCombo = combo;
        this.comboQueries[combo] = "";
        this.openFieldId = "";
        input.select();
        this.renderComboPortal(input, combo);
    }

    private typeComboInput(combo: ComboKind, input: HTMLInputElement, value: string): void {
        this.openCombo = combo;
        this.comboQueries[combo] = value;
        this.openFieldId = "";
        this.renderComboPortal(input, combo);
    }

    private closeCombo(combo: ComboKind, input?: HTMLInputElement): void {
        if (this.openCombo !== combo) return;
        this.openCombo = "";
        this.comboQueries[combo] = "";
        if (input) input.value = this.comboCurrentLabel(combo);
        this.closePortal();
    }

    private async handleComboKey(event: KeyboardEvent, combo: ComboKind): Promise<void> {
        if (event.key === "Escape") {
            event.preventDefault();
            this.closeCombo(combo, event.currentTarget as HTMLInputElement);
            return;
        }
        if (event.key !== "Enter") return;
        event.preventDefault();
        const option = this.comboOptions(combo)[0];
        if (option) await this.chooseComboOption(combo, option.value);
    }

    private async chooseComboOption(combo: ComboKind, value: string): Promise<void> {
        this.openCombo = "";
        this.comboQueries[combo] = "";
        this.closePortal();
        if (combo === "newSource") this.newSource = value;
        if (combo === "newTarget") {
            this.newTarget = Number(value);
            this.applyPreferredSourceForNewTarget();
        }
        if (combo === "editSource") await this.updateSelectedSource(value);
        if (combo === "editTarget") await this.updateSelectedTarget(Number(value));
        this.render();
    }

    private commitComboQuery(combo: ComboKind): void {
        const query = this.comboQueries[combo].trim();
        if (!query) return;
        const option = this.comboOptions(combo)[0];
        if (!option) return;
        if (combo === "newSource") this.newSource = option.value;
        if (combo === "newTarget") {
            this.newTarget = Number(option.value);
            this.applyPreferredSourceForNewTarget();
        }
        this.comboQueries[combo] = "";
        if (this.openCombo === combo) this.openCombo = "";
    }

    private applyPreferredSourceForNewTarget(): void {
        if (this.newTarget === 100000001 && this.sourceTable("productpricelevel")) this.newSource = "productpricelevel";
    }

    private openFieldCombo(fieldId: string, input: HTMLInputElement): void {
        this.openFieldId = fieldId;
        this.fieldQueries[fieldId] = "";
        this.openCombo = "";
        input.select();
        this.renderFieldPortal(input, fieldId);
    }

    private typeFieldCombo(fieldId: string, input: HTMLInputElement, value: string): void {
        this.openFieldId = fieldId;
        this.fieldQueries[fieldId] = value;
        this.openCombo = "";
        this.renderFieldPortal(input, fieldId);
    }

    private closeFieldCombo(fieldId: string, input?: HTMLInputElement): void {
        if (this.openFieldId !== fieldId) return;
        this.openFieldId = "";
        this.fieldQueries[fieldId] = "";
        if (input) input.value = this.fieldCurrentLabel(fieldId);
        this.closePortal();
    }

    private async handleFieldKey(event: KeyboardEvent, fieldId: string): Promise<void> {
        if (event.key === "Escape") {
            event.preventDefault();
            this.closeFieldCombo(fieldId, event.currentTarget as HTMLInputElement);
            return;
        }
        if (event.key !== "Enter") return;
        event.preventDefault();
        const selected = this.selectedMapping();
        const row = this.fields.find((field) => field.id === fieldId);
        const option = selected ? this.sourceFieldOptions(selected.sourceLogical, this.fieldQueries[fieldId] || "", row)[0] : null;
        if (option) await this.chooseFieldOption(fieldId, option.logical);
    }

    private async chooseFieldOption(fieldId: string, sourceLogical: string): Promise<void> {
        this.openFieldId = "";
        this.fieldQueries[fieldId] = "";
        this.closePortal();
        await this.updateFieldSource(fieldId, sourceLogical);
    }

    private sourceComboHtml(id: string, combo: ComboKind, selectedLogical: string, placeholder: string, disabled = false): string {
        return `<div class="ppms-combobox"><input class="ppms-input ppms-combo-input" id="${id}" data-combo="${combo}" value="${this.esc(this.sourceComboValue(selectedLogical))}" placeholder="${this.esc(placeholder)}" autocomplete="off" spellcheck="false" role="combobox" aria-expanded="false" ${disabled ? "disabled" : ""} /></div>`;
    }

    private targetComboHtml(id: string, combo: ComboKind, selectedValue: number, placeholder: string, disabled = false): string {
        return `<div class="ppms-combobox"><input class="ppms-input ppms-combo-input" id="${id}" data-combo="${combo}" value="${this.esc(this.targetComboValue(selectedValue))}" placeholder="${this.esc(placeholder)}" autocomplete="off" spellcheck="false" role="combobox" aria-expanded="false" ${disabled ? "disabled" : ""} /></div>`;
    }

    private sourceFieldComboHtml(sourceLogical: string, row: FieldMapping, disabled = false): string {
        const inputId = this.fieldInputId(row.id);
        const value = this.sourceFieldComboValue(sourceLogical, row.sourceLogical, row.sourceDisplay);
        const placeholder = row.sourceType === SOURCE_TYPE_LOOKUP ? this.t("chooseLookupField") : (row.sourceType === SOURCE_TYPE_RELATED ? this.t("chooseRelatedField") : this.t("chooseSourceField"));
        return `<div class="ppms-combobox"><input class="ppms-input ppms-field-input" id="${this.esc(inputId)}" data-field-id="${this.esc(row.id)}" value="${this.esc(value)}" placeholder="${this.esc(placeholder)}" autocomplete="off" spellcheck="false" role="combobox" aria-expanded="false" ${disabled ? "disabled" : ""} /></div>`;
    }

    private sourceTypeSelectHtml(row: FieldMapping, disabled = false): string {
        const options = this.sourceTypeOptions().map((option) => `<option value="${option.value}" ${option.value === row.sourceType ? "selected" : ""}>${this.esc(option.label)}</option>`).join("");
        return `<select class="ppms-input ppms-source-type" data-field-id="${this.esc(row.id)}" aria-label="${this.esc(this.t("sourceType"))}" ${disabled ? "disabled" : ""}>${options}</select>`;
    }

    private sourceValueHtml(sourceLogical: string, row: FieldMapping, disabled = false): string {
        if (row.sourceType === SOURCE_TYPE_CONSTANT) {
            const placeholder = this.t("constantValue");
            return `<input class="ppms-input ppms-default-value" data-field-id="${this.esc(row.id)}" value="${this.esc(row.defaultValue)}" placeholder="${this.esc(placeholder)}" ${disabled ? "disabled" : ""} />`;
        }
        const valueHtml = this.sourceFieldComboHtml(sourceLogical, row, disabled);
        if (row.sourceType !== SOURCE_TYPE_FORMULA) return valueHtml;
        return `<div class="ppms-value-stack">${valueHtml}${this.transformRuleSelectHtml(row, disabled)}</div>`;
    }

    private transformRuleSelectHtml(row: FieldMapping, disabled = false): string {
        const options = [`<option value="">${this.esc(this.t("chooseTransformRule"))}</option>`]
            .concat(this.transformRules.map((rule) => `<option value="${this.esc(rule.id)}" ${rule.id === row.transformRuleId ? "selected" : ""}>${this.esc(rule.name)}</option>`))
            .join("");
        return `<select class="ppms-input ppms-transform-rule" data-field-id="${this.esc(row.id)}" aria-label="${this.esc(this.t("formulaValue"))}" ${disabled ? "disabled" : ""}>${options}</select>`;
    }

    private renderComboPortal(input: HTMLInputElement, combo: ComboKind): void {
        this.closePortal();
        const portal = this.createPortal(input);
        const options = this.comboOptions(combo);
        if (!options.length) {
            portal.appendChild(this.emptyPortalItem());
        } else {
            options.forEach((option) => {
                const item = this.portalOption(option.label, this.comboSelectedValue(combo) === option.value);
                item.onmousedown = (event: MouseEvent) => {
                    event.preventDefault();
                    void this.chooseComboOption(combo, option.value);
                };
                portal.appendChild(item);
            });
        }
        document.body.appendChild(portal);
        input.setAttribute("aria-expanded", "true");
        this.comboPortal = portal;
    }

    private renderFieldPortal(input: HTMLInputElement, fieldId: string): void {
        this.closePortal();
        const selected = this.selectedMapping();
        const portal = this.createPortal(input);
        const row = this.fields.find((field) => field.id === fieldId);
        const options = selected ? this.sourceFieldOptions(selected.sourceLogical, this.fieldQueries[fieldId] || "", row) : [];
        if (!options.length) {
            portal.appendChild(this.emptyPortalItem());
        } else {
            options.forEach((option) => {
                const item = this.portalOption(this.fieldOptionLabel(option), row?.sourceLogical === option.logical);
                item.onmousedown = (event: MouseEvent) => {
                    event.preventDefault();
                    void this.chooseFieldOption(fieldId, option.logical);
                };
                portal.appendChild(item);
            });
        }
        document.body.appendChild(portal);
        input.setAttribute("aria-expanded", "true");
        this.comboPortal = portal;
    }

    private createPortal(input: HTMLInputElement): HTMLDivElement {
        const rect = input.getBoundingClientRect();
        const width = Math.max(rect.width, 220);
        const maxHeight = Math.min(280, Math.max(160, window.innerHeight - rect.bottom - 12));
        const portal = document.createElement("div");
        portal.className = "ppms-combo-pop";
        portal.setAttribute("dir", this.isRtl ? "rtl" : "ltr");
        portal.style.position = "fixed";
        portal.style.zIndex = "99999";
        portal.style.top = `${rect.bottom + 2}px`;
        portal.style.left = `${rect.left}px`;
        portal.style.width = `${width}px`;
        portal.style.maxHeight = `${maxHeight}px`;
        portal.style.overflowY = "auto";
        portal.style.background = "#fff";
        portal.style.border = "1px solid rgba(0, 0, 0, 0.18)";
        portal.style.borderRadius = "10px";
        portal.style.boxShadow = "0 12px 34px rgba(15, 23, 42, .18)";
        portal.style.padding = "5px";
        portal.style.font = "13px 'Segoe UI', Arial, sans-serif";
        return portal;
    }

    private portalOption(label: string, selected: boolean): HTMLButtonElement {
        const item = document.createElement("button");
        item.type = "button";
        item.className = `ppms-combo-option${selected ? " sel" : ""}`;
        item.setAttribute("role", "option");
        item.style.display = "flex";
        item.style.alignItems = "center";
        item.style.justifyContent = "space-between";
        item.style.gap = "10px";
        item.style.width = "100%";
        item.style.border = "0";
        item.style.borderRadius = "7px";
        item.style.background = selected ? "rgba(0, 113, 227, .10)" : "transparent";
        item.style.color = selected ? "#0071e3" : "#111418";
        item.style.padding = "8px 10px";
        item.style.font = "inherit";
        item.style.fontWeight = selected ? "650" : "400";
        item.style.textAlign = "start";
        item.style.cursor = "pointer";
        item.onmouseenter = () => { if (!selected) item.style.background = "#f2f2f7"; };
        item.onmouseleave = () => { if (!selected) item.style.background = "transparent"; };
        const text = document.createElement("span");
        text.textContent = label;
        text.style.display = "block";
        text.style.overflow = "hidden";
        text.style.textOverflow = "ellipsis";
        text.style.whiteSpace = "nowrap";
        item.appendChild(text);
        return item;
    }

    private emptyPortalItem(): HTMLDivElement {
        const empty = document.createElement("div");
        empty.className = "ppms-combo-empty";
        empty.textContent = this.t("noFields");
        empty.style.padding = "10px";
        empty.style.textAlign = "center";
        empty.style.color = "#6e6e73";
        return empty;
    }

    private closePortal(): void {
        this.root.querySelectorAll<HTMLInputElement>(".ppms-combo-input,.ppms-field-input").forEach((input) => input.setAttribute("aria-expanded", "false"));
        this.comboPortal?.remove();
        this.comboPortal = null;
    }

    private comboSelectedValue(combo: ComboKind): string {
        const selected = this.selectedMapping();
        if (combo === "newSource") return this.newSource;
        if (combo === "newTarget") return String(this.newTarget);
        if (combo === "editSource") return selected?.sourceLogical || "";
        return String(selected?.targetValue ?? "");
    }

    private comboCurrentLabel(combo: ComboKind): string {
        const selected = this.selectedMapping();
        if (combo === "newSource") return this.sourceComboValue(this.newSource);
        if (combo === "newTarget") return this.targetComboValue(this.newTarget);
        if (combo === "editSource") return this.sourceComboValue(selected?.sourceLogical || "");
        return this.targetComboValue(selected?.targetValue ?? null);
    }

    private fieldCurrentLabel(fieldId: string): string {
        const selected = this.selectedMapping();
        const row = this.fields.find((field) => field.id === fieldId);
        if (!selected || !row) return "";
        return this.sourceFieldComboValue(selected.sourceLogical, row.sourceLogical, row.sourceDisplay);
    }

    private comboOptions(combo: ComboKind): { value: string; label: string }[] {
        const query = this.comboQueries[combo] || "";
        if (combo === "newSource" || combo === "editSource") {
            return this.sourceTableOptions(query).map((sourceTable) => ({ value: sourceTable.logical, label: this.sourceOptionLabel(sourceTable) }));
        }
        return this.targetOptions(query).map((targetDef) => ({ value: String(targetDef.value), label: this.targetOptionLabel(targetDef) }));
    }

    private sourceTableOptions(query: string): SourceTable[] {
        const q = query.trim().toLowerCase();
        const tables = q ? this.sourceTables.filter((sourceTable) => this.optionMatches([sourceTable.logical, sourceTable.en, sourceTable.he, this.sourceOptionLabel(sourceTable)], q)) : this.sourceTables;
        return tables.slice(0, COMBO_LIMIT);
    }

    private targetOptions(query: string): PayPlusTarget[] {
        const q = query.trim().toLowerCase();
        const selectableTargets = this.selectableTargets();
        const targets = q ? selectableTargets.filter((targetDef) => this.optionMatches([String(targetDef.value), targetDef.en, targetDef.he, this.targetOptionLabel(targetDef)], q)) : selectableTargets;
        return targets.slice(0, COMBO_LIMIT);
    }

    private selectableTargets(): PayPlusTarget[] {
        return TARGETS.filter((targetDef) => !targetDef.hidden && (this.showAdvancedTargets || !targetDef.advanced));
    }

    private sourceFieldOptions(sourceLogical: string, query: string, row?: FieldMapping): SourceField[] {
        const q = query.trim().toLowerCase();
        let fields = row?.sourceType === SOURCE_TYPE_RELATED ? this.relatedFieldOptions() : this.sourceFields(sourceLogical);
        if (row?.sourceType === SOURCE_TYPE_LOOKUP) fields = fields.filter((field) => field.type === DATA_TYPE.lookup);
        const filtered = q ? fields.filter((field) => this.optionMatches([field.logical, field.en, field.he, this.fieldOptionLabel(field)], q)) : fields;
        return filtered.slice(0, COMBO_LIMIT);
    }

    private relatedFieldOptions(): SourceField[] {
        const byLogical = new Map<string, SourceTable>();
        [...SOURCE_TABLES, ...this.sourceTables].forEach((sourceTable) => byLogical.set(sourceTable.logical, sourceTable));
        const relatedFields: SourceField[] = [];
        byLogical.forEach((sourceTable) => {
            const fields = this.sourceFieldsByTable.get(sourceTable.logical) || sourceTable.fields;
            fields.forEach((field) => {
                relatedFields.push(source(`${sourceTable.logical}.${field.logical}`, `${sourceTable.en}.${field.en}`, `${sourceTable.he}.${field.he}`, field.type));
            });
        });
        this.fields.filter((field) => field.sourceLogical.includes(".")).forEach((field) => {
            if (!relatedFields.some((item) => item.logical === field.sourceLogical)) {
                relatedFields.push(source(field.sourceLogical, field.sourceDisplay || field.sourceLogical, field.sourceDisplay || field.sourceLogical, field.dataverseType || DATA_TYPE.text));
            }
        });
        return relatedFields.sort((left, right) => this.fieldOptionLabel(left).localeCompare(this.fieldOptionLabel(right), this.isRtl ? "he" : "en"));
    }

    private optionMatches(values: string[], query: string): boolean {
        return values.some((value) => value.toLowerCase().includes(query));
    }

    private resolveSourceTableInput(value: string): string {
        const text = value.trim();
        if (!text) return "";
        const lower = text.toLowerCase();
        const exact = this.sourceTables.find((sourceTable) => [sourceTable.logical, sourceTable.en, sourceTable.he, this.sourceOptionLabel(sourceTable)].some((option) => option.toLowerCase() === lower));
        if (exact) return exact.logical;
        const suffix = this.optionSuffix(text).toLowerCase();
        const bySuffix = this.sourceTables.find((sourceTable) => sourceTable.logical.toLowerCase() === suffix);
        return bySuffix?.logical || this.optionSuffix(text);
    }

    private resolveTargetInput(value: string): number | null {
        const text = value.trim();
        if (!text) return null;
        const lower = text.toLowerCase();
        const exact = TARGETS.find((targetDef) => [String(targetDef.value), targetDef.en, targetDef.he, this.targetOptionLabel(targetDef)].some((option) => option.toLowerCase() === lower));
        if (exact) return exact.value;
        const suffix = this.optionSuffix(text).toLowerCase();
        const bySuffix = TARGETS.find((targetDef) => targetDef.en.toLowerCase() === suffix || targetDef.he.toLowerCase() === suffix);
        return bySuffix?.value ?? null;
    }

    private resolveSourceFieldInput(sourceLogical: string, value: string): string {
        const text = value.trim();
        if (!text) return "";
        const lower = text.toLowerCase();
        const fields = this.sourceFields(sourceLogical);
        const exact = fields.find((field) => [field.logical, field.en, field.he, this.fieldOptionLabel(field)].some((option) => option.toLowerCase() === lower));
        if (exact) return exact.logical;
        const suffix = this.optionSuffix(text).toLowerCase();
        const bySuffix = fields.find((field) => field.logical.toLowerCase() === suffix);
        return bySuffix?.logical || this.optionSuffix(text);
    }

    private optionSuffix(value: string): string {
        const index = value.lastIndexOf(" - ");
        return index >= 0 ? value.slice(index + 3).trim() : value.trim();
    }

    private sourceComboValue(sourceLogical: string): string {
        const sourceTable = this.sourceTable(sourceLogical);
        return sourceTable ? this.sourceOptionLabel(sourceTable) : sourceLogical;
    }

    private targetComboValue(value: number | null): string {
        const targetDef = this.target(value);
        return targetDef ? this.targetOptionLabel(targetDef) : "";
    }

    private targetOptionLabel(targetDef: PayPlusTarget): string {
        const secondary = this.isRtl ? targetDef.en : targetDef.he;
        return secondary && secondary !== this.label(targetDef) ? `${this.label(targetDef)} - ${secondary}` : this.label(targetDef);
    }

    private fieldOptionLabel(field: { logical: string; en: string; he: string }): string {
        return `${this.label(field)} - ${field.logical}`;
    }

    private sourceFieldComboValue(sourceLogical: string, fieldLogical: string, fallbackDisplay: string): string {
        if (!fieldLogical) return "";
        const sourceDef = this.sourceFieldForRow(sourceLogical, fieldLogical);
        if (sourceDef) return this.fieldOptionLabel(sourceDef);
        return fallbackDisplay && fallbackDisplay !== fieldLogical ? `${fallbackDisplay} - ${fieldLogical}` : fieldLogical;
    }

    private fieldInputId(fieldId: string): string {
        return `ppms-field-source-${fieldId}`;
    }

    private sourceFieldForRow(sourceLogical: string, fieldLogical: string, row?: FieldMapping): SourceField | null {
        if ((row?.sourceType === SOURCE_TYPE_RELATED || fieldLogical.includes(".")) && fieldLogical) {
            return this.relatedFieldOptions().find((field) => field.logical === fieldLogical) || null;
        }
        return this.sourceField(sourceLogical, fieldLogical);
    }

    private focusInside(selector: string): boolean {
        const active = document.activeElement;
        return !!active && !!this.root.querySelector(selector) && !!active.closest(selector);
    }

    private sourceOptionLabel(sourceTable: SourceTable): string {
        return `${this.label(sourceTable)} - ${sourceTable.logical}`;
    }

    private toast(message: string): void {
        this.toastText = message;
        this.render();
        window.setTimeout(() => {
            if (this.toastText === message) {
                this.toastText = "";
                this.render();
            }
        }, 2800);
    }

    private t(key: keyof typeof UI.en): string {
        return (this.isRtl ? UI.he[key] : UI.en[key]) || key;
    }

    private esc(value: string): string {
        return (value || "").replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[char] as string));
    }

    private errorMessage(error: unknown): string {
        if (error instanceof Error && error.message) return error.message;
        return this.t("unexpectedError");
    }

    private iconRefresh(): string {
        return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M17.7 6.3A8 8 0 1 0 20 12h-2a6 6 0 1 1-1.76-4.24L13 11h8V3l-3.3 3.3z" /></svg>';
    }
}
