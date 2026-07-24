# Data Model

This document describes the Dataverse data model that supports the PayPlus solution. The tables, columns, choices, and relationships below are taken from the live Dynamics 365 environment. All tables use the `alex_` publisher prefix.

For the runtime behaviour that consumes this model, see [architecture.md](architecture.md).

## Table Catalog

| Group | Logical name | Display name | Purpose |
| --- | --- | --- | --- |
| Configuration | `alex_payplusconfiguration` | PayPlus Configuration | Connector environment, setup wizard state, account-level default (fallback) terminal and payment page, self-service channel toggles, and validation status. |
| Terminals | `alex_payplus_terminal` | PayPlus Terminal | Discovered PayPlus terminals for the environment, with default selection and terminal-level policies. |
| Terminals | `alex_payplus_paymentpage` | PayPlus Payment Page | Discovered PayPlus payment pages, each linked to a terminal, with default selection and page-level behavior. |
| Configuration | `alex_payplus_syncprofile` | PayPlus Sync Profile | Root of a sync package. One active profile per environment; holds defaults and drives connector routing. |
| Sync mapping | `alex_payplus_entitymapping` | PayPlus Entity Mapping | Maps one Dataverse source table to one PayPlus target object. |
| Sync mapping | `alex_payplus_fieldmapping` | PayPlus Field Mapping | Field-level mapping between a source field and a PayPlus field. |
| Sync mapping | `alex_payplus_filterrule` | PayPlus Filter Rule | Optional sync conditions per entity mapping (AND semantics). |
| Sync mapping | `alex_payplus_transformrule` | PayPlus Transform Rule | Reusable value transforms referenced by field mappings. |
| Sync mapping | `alex_payplus_valuemapping` | PayPlus Value Mapping | Explicit source-to-target value maps. |
| Sync runtime | `alex_payplus_syncoutbox` | PayPlus Sync Outbox | Pending outbound sync work items (outbox pattern). |
| Sync runtime | `alex_payplus_syncstate` | PayPlus Sync State | Last known PayPlus UID and status per source record. |
| Sync runtime | `alex_payplus_synclog` | PayPlus Sync Log | Audit trail of sync attempts and results. |
| Tokenization | `alex_creditcard` | Credit Card | Tokenized card metadata and PayPlus token for an account or contact. |
| Tokenization | `alex_pp_hfsession` | Card Collection Session | Hosted-fields / self-service card capture session. |
| Billing & Payments | `alex_payplusbillingcase` | PayPlus Billing Case | The collection anchor for a source record (any table). Tracks totals, amounts due/paid/allocated, status, and the expected document flow. Drives the Payment Wizard. |
| Billing & Payments | `alex_paypluspaymentline` | PayPlus Payment Line | One payment attempt/receipt against a billing case (card, token, bank transfer, check, cash), with clearing/verification state and the issued receipt document. |
| Billing & Payments | `alex_payplusreceiptallocation` | PayPlus Receipt Allocation | Allocates a payment line to what it settles (an invoice, an invoice detail line, or a source line), with snapshots and status. |
| Documents | `alex_payplusdocument` | PayPlus Document | An Invoice+ document (invoice, receipt, tax-invoice-receipt, credit, quote, and more) with its PayPlus identifiers, amounts, status, source linkage, and distribution flags. |
| Documents | `alex_payplusdocumentactionlog` | PayPlus Document Action Log | Audit trail of actions requested on a document (send by email/SMS/WhatsApp, link generation) and their status. |
| Documents | `alex_payplus_documenttype` | PayPlus Document Type | Imported catalog of PayPlus document types with category, codes, bilingual titles, and initiate/declarable policies. |
| Bank reference | `alex_bank` | Bank | Israeli bank list; PayPlus-supported flag. |
| Bank reference | `alex_bankbranch` | Bank Branch | Bank branches with code, city, and address. |
| Customer master | `alex_customerbankaccount` | Customer Bank Account | A customer's bank account (bank + branch, IBAN/SWIFT, standing order), surfaced by the Bank Account Wallet control. |

## Entity Relationship Diagram

```mermaid
erDiagram
    CONFIGURATION ||--o{ TERMINAL : "discovers"
    CONFIGURATION ||--o{ PAYMENTPAGE : "discovers"
    TERMINAL ||--o{ PAYMENTPAGE : "has"
    SYNCPROFILE ||--o{ ENTITYMAPPING : "has"
    SYNCPROFILE ||--o{ VALUEMAPPING : "has"
    SYNCPROFILE ||--o{ SYNCOUTBOX : "scopes"
    SYNCPROFILE ||--o{ SYNCSTATE : "scopes"
    SYNCPROFILE ||--o{ SYNCLOG : "scopes"
    ENTITYMAPPING ||--o{ FIELDMAPPING : "has"
    ENTITYMAPPING ||--o{ FILTERRULE : "has"
    ENTITYMAPPING ||--o{ SYNCOUTBOX : "produces"
    ENTITYMAPPING ||--o{ SYNCSTATE : "tracks"
    ENTITYMAPPING ||--o{ SYNCLOG : "logs"
    TRANSFORMRULE ||--o{ FIELDMAPPING : "transforms"
    SYNCSTATE ||--o{ SYNCOUTBOX : "referenced by"
    SYNCSTATE ||--o{ SYNCLOG : "referenced by"
    SYNCOUTBOX ||--o{ SYNCLOG : "referenced by"
    SYNCOUTBOX ||--o{ SYNCOUTBOX : "superseded by"
    ACCOUNT ||--o{ CREDITCARD : "owns"
    CONTACT ||--o{ CREDITCARD : "owns"
    ACCOUNT ||--o{ HFSESSION : "requests"
    CONTACT ||--o{ HFSESSION : "requests"

    CONFIGURATION {
        guid alex_payplusconfigurationid PK
        choice alex_environment
        string alex_terminaluidref
        string alex_paymentpageuidref
    }
    TERMINAL {
        guid alex_payplus_terminalid PK
        string alex_terminaluid
        choice alex_environment
        bool alex_isdefault
    }
    PAYMENTPAGE {
        guid alex_payplus_paymentpageid PK
        lookup alex_terminalid FK
        string alex_paymentpageuid
        choice alex_environment
        bool alex_isdefault
    }
    SYNCPROFILE {
        guid alex_payplus_syncprofileid PK
        string alex_name
        choice alex_environment
        bool alex_isactive
        choice alex_defaultoperationmode
    }
    ENTITYMAPPING {
        guid alex_payplus_entitymappingid PK
        lookup alex_syncprofileid FK
        string alex_sourcetablelogicalname
        choice alex_targetobject
        bool alex_isactive
    }
    FIELDMAPPING {
        guid alex_payplus_fieldmappingid PK
        lookup alex_entitymappingid FK
        lookup alex_transformruleid FK
        string alex_sourcefieldlogicalname
        string alex_targetfieldlogicalname
        choice alex_sourcetype
    }
    FILTERRULE {
        guid alex_payplus_filterruleid PK
        lookup alex_entitymappingid FK
        string alex_sourcefieldlogicalname
        choice alex_operator
        string alex_comparevalue
    }
    TRANSFORMRULE {
        guid alex_payplus_transformruleid PK
        string alex_rulecode
        choice alex_rulekind
        string alex_expression
    }
    VALUEMAPPING {
        guid alex_payplus_valuemappingid PK
        lookup alex_syncprofileid FK
        string alex_sourcevalue
        string alex_targetvalue
        bool alex_isdefault
    }
    SYNCOUTBOX {
        guid alex_payplus_syncoutboxid PK
        lookup alex_syncprofileid FK
        lookup alex_entitymappingid FK
        lookup alex_syncstateid FK
        choice alex_operation
        choice alex_status
    }
    SYNCSTATE {
        guid alex_payplus_syncstateid PK
        lookup alex_syncprofileid FK
        lookup alex_entitymappingid FK
        string alex_payplusuid
        choice alex_laststatus
    }
    SYNCLOG {
        guid alex_payplus_synclogid PK
        lookup alex_syncprofileid FK
        lookup alex_outboxid FK
        lookup alex_syncstateid FK
        choice alex_eventtype
    }
    CREDITCARD {
        guid alex_creditcardid PK
        lookup alex_account FK
        lookup alex_contact FK
        string alex_token
        choice alex_brand
        bool alex_isdefault
    }
    HFSESSION {
        guid alex_pp_hfsessionid PK
        lookup alex_account FK
        lookup alex_contact FK
        string alex_requestid
        string alex_status
    }
```

## Relationship Summary

| Child table | Foreign key column | Parent table |
| --- | --- | --- |
| `alex_payplus_terminal` | `alex_configurationid` | `alex_payplusconfiguration` |
| `alex_payplus_terminal` | `alex_syncprofileid` | `alex_payplus_syncprofile` |
| `alex_payplus_paymentpage` | `alex_terminalid` | `alex_payplus_terminal` |
| `alex_payplus_paymentpage` | `alex_configurationid` | `alex_payplusconfiguration` |
| `alex_payplus_paymentpage` | `alex_syncprofileid` | `alex_payplus_syncprofile` |
| `alex_payplus_entitymapping` | `alex_syncprofileid` | `alex_payplus_syncprofile` |
| `alex_payplus_valuemapping` | `alex_syncprofileid` | `alex_payplus_syncprofile` |
| `alex_payplus_fieldmapping` | `alex_entitymappingid` | `alex_payplus_entitymapping` |
| `alex_payplus_fieldmapping` | `alex_transformruleid` | `alex_payplus_transformrule` |
| `alex_payplus_filterrule` | `alex_entitymappingid` | `alex_payplus_entitymapping` |
| `alex_payplus_syncoutbox` | `alex_syncprofileid` | `alex_payplus_syncprofile` |
| `alex_payplus_syncoutbox` | `alex_entitymappingid` | `alex_payplus_entitymapping` |
| `alex_payplus_syncoutbox` | `alex_syncstateid` | `alex_payplus_syncstate` |
| `alex_payplus_syncoutbox` | `alex_supersededbyid` | `alex_payplus_syncoutbox` (self) |
| `alex_payplus_syncstate` | `alex_syncprofileid` | `alex_payplus_syncprofile` |
| `alex_payplus_syncstate` | `alex_entitymappingid` | `alex_payplus_entitymapping` |
| `alex_payplus_synclog` | `alex_syncprofileid` | `alex_payplus_syncprofile` |
| `alex_payplus_synclog` | `alex_outboxid` | `alex_payplus_syncoutbox` |
| `alex_payplus_synclog` | `alex_syncstateid` | `alex_payplus_syncstate` |
| `alex_payplus_synclog` | `alex_entitymappingid` | `alex_payplus_entitymapping` |
| `alex_creditcard` | `alex_account` | `account` |
| `alex_creditcard` | `alex_contact` | `contact` |
| `alex_pp_hfsession` | `alex_account` | `account` |
| `alex_pp_hfsession` | `alex_contact` | `contact` |

## Table Details

### PayPlus Configuration (`alex_payplusconfiguration`)

Single configuration record for the connector and self-service behaviour.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | Configuration name. |
| `alex_environment` | Choice | PayPlus environment (Production / Sandbox). |
| `alex_setupstage` | Choice | Setup wizard stage (Connect, Terminals & pages, Validate, Done). |
| `alex_setupcompleted` | Yes/No | Setup finished. |
| `alex_configvalidated` | Yes/No | Configuration validated. |
| `alex_terminaluidref` | Text | Account-level default (fallback) PayPlus terminal UID. All runtime flows use this default when a specific terminal is not provided. It is set during the setup wizard's Validate step and mirrors the terminal record flagged with `alex_isdefault`. |
| `alex_paymentpageuidref` | Text | Account-level default (fallback) payment page UID. All runtime flows use this default when a specific page is not provided. It is set during the Validate step and mirrors the page record flagged with `alex_isdefault`. |
| `alex_paymentpages` | Multiline (JSON) | Legacy/cache list of payment pages. The authoritative discovered pages now live in the `alex_payplus_paymentpage` table. |
| `alex_lastvalidationstatus` | Choice | Last validation status. |
| `alex_lastvalidationcode` | Whole number | Last validation result/HTTP code. |
| `alex_lastvalidationmessage` | Text | Last validation message. |
| `alex_lastvalidatedon` | Date/time | Last validated on. |
| `alex_validationrequestid` | Text | Validation request id. |
| `alex_selfservice_{email\|sms\|whatsapp}_{account\|contact}` | Yes/No | Enables self-service card collection per channel and parent type. |
| `alex_selfservice_{email\|sms\|whatsapp}_{account\|contact}_expiry` | Whole number | Link validity window in days for each channel and parent type. |

### PayPlus Terminal (`alex_payplus_terminal`)

One row per PayPlus terminal discovered for the environment. Rows are populated by the **PayPlus - Import Terminals & Pages** flow, keyed by environment + terminal UID. A single default per environment is enforced by the `EnforceSingleDefaultTerminal` plugin.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_terminaluid` | Text | PayPlus terminal UUID. Natural key together with the environment. |
| `alex_merchantnumber` | Text | Merchant number. |
| `alex_legalentity` | Text | Legal entity. |
| `alex_terminaltypeid` | Whole number | Terminal type id. |
| `alex_activitytype` | Choice | Activity type (Website, Call Center, Retail, Donations, Other). |
| `alex_primarycurrency` | Choice | Primary currency (ILS, USD, EUR, GBP). |
| `alex_recurring_enabled` | Yes/No | Recurring charges enabled. |
| `alex_tokenization_enabled` | Yes/No | Tokenization enabled. |
| `alex_cvv_policy` | Choice | CVV policy (Required, Not Required, Conditional, Unknown). |
| `alex_cvv_policy_source` | Choice | CVV policy source. |
| `alex_cvv_required_j5` | Choice | CVV required for J5 completion. |
| `alex_cvv_required_recurring_init` | Choice | CVV required at recurring init. |
| `alex_threeds_policy` | Choice | 3D Secure policy (Default, On, Off, Conditional). |
| `alex_settings_verified_on` | Date/time | Settings verified on. |
| `alex_rawjson` | Multiline | Raw PayPlus terminal payload. |
| `alex_lastsyncon` | Date/time | Last synced on. |
| `alex_environment` | Choice | PayPlus environment (Production / Sandbox). |
| `alex_isdefault` | Yes/No | Default terminal for the environment. Enforced single-per-environment by the `EnforceSingleDefaultTerminal` plugin. |
| `alex_isactive` | Yes/No | Active terminal. |
| `alex_description` | Multiline | Business description (when to use). |
| `alex_configurationid` | Lookup → PayPlus Configuration | Owning configuration. |
| `alex_syncprofileid` | Lookup → PayPlus Sync Profile | Owning sync profile. |
| `alex_approvedby` | Lookup → User | Approved by. |
| `alex_name` | Text | Name. |

### PayPlus Payment Page (`alex_payplus_paymentpage`)

One row per PayPlus payment page; each page belongs to a terminal. Rows are populated by the **PayPlus - Import Terminals & Pages** flow, keyed by environment + page UID. A single default per terminal + process type is enforced by the `EnforceSingleDefaultPage` plugin.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_paymentpageuid` | Text | PayPlus payment page UUID. Natural key together with the environment. |
| `alex_terminalid` | Lookup → PayPlus Terminal | The owning terminal. |
| `alex_processtype` | Choice | Process type (Charge, Approval, Check, Token Only, Recurring). |
| `alex_purpose` | Choice | Page purpose. |
| `alex_audience` | Choice | Audience. |
| `alex_channel` | Choice | Primary channel (Website, Call Center, WhatsApp, Email, QR). |
| `alex_tokenbehavior` | Choice | Token behavior (No Token, Optional, Required, Token Only). |
| `alex_createtoken_default` | Yes/No | Create token by default. |
| `alex_cvv_inherit_terminal` | Yes/No | Inherit CVV from terminal. |
| `alex_cvv_policy_displayed` | Choice | CVV policy (displayed). |
| `alex_threeds_policy` | Choice | 3D Secure policy. |
| `alex_for_card_update` | Yes/No | For card update. |
| `alex_for_subscription` | Yes/No | For subscription. |
| `alex_openamount` | Yes/No | Open amount. |
| `alex_maxpayments` | Whole number | Max payments. |
| `alex_defaultcurrency` | Text | Default currency. |
| `alex_language` | Text | Language. |
| `alex_identification_required` | Yes/No | Identification required. |
| `alex_cashieruid` | Text | Cashier UID. |
| `alex_cashiername` | Text | Cashier name. |
| `alex_chargemethod` | Whole number | Charge method (numeric). |
| `alex_selectionpriority` | Whole number | Selection priority. |
| `alex_startdate` | Date/time | Start date. |
| `alex_enddate` | Date/time | End date. |
| `alex_valid` | Yes/No | Valid in PayPlus. |
| `alex_rawjson` | Multiline | Raw PayPlus payment page payload. |
| `alex_lastsyncon` | Date/time | Last synced on. |
| `alex_environment` | Choice | PayPlus environment (Production / Sandbox). |
| `alex_isdefault` | Yes/No | Default page for its terminal + process type. Enforced single-per (terminal + process type) by the `EnforceSingleDefaultPage` plugin. |
| `alex_isactive` | Yes/No | Active page. |
| `alex_description` | Multiline | Description for the user. |
| `alex_configurationid` | Lookup → PayPlus Configuration | Owning configuration. |
| `alex_syncprofileid` | Lookup → PayPlus Sync Profile | Owning sync profile. |
| `alex_name` | Text | Name. |

### PayPlus Sync Profile (`alex_payplus_syncprofile`)

Root of a sync package. One active profile per environment.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | Profile name. |
| `alex_environment` | Choice | Sandbox / Production. Drives connector routing in the process flow. |
| `alex_isactive` | Yes/No | Active profile. |
| `alex_defaultoperationmode` | Choice | Create only / Update only / Create and update. |
| `alex_defaultcurrencycode` | Text | Default currency code. |
| `alex_defaultlanguagecode` | Text | Default language code. |
| `alex_defaultretrycount` | Whole number | Default retry count. |
| `alex_retryintervalminutes` | Whole number | Retry interval in minutes. |
| `alex_failonmissingrequiredfield` | Yes/No | Fail when a required field is missing. |
| `alex_mappingstudiohost` | Text | Mapping Studio host URL. |

### PayPlus Entity Mapping (`alex_payplus_entitymapping`)

Maps one Dataverse source table to one PayPlus target object.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | Mapping name. |
| `alex_syncprofileid` | Lookup → Sync Profile | Parent sync profile. |
| `alex_sourcetablelogicalname` | Text | Dataverse source table logical name. |
| `alex_sourcetabledisplayname` | Text | Source table display name. |
| `alex_targetobject` | Choice | PayPlus target object (Customer, Product, Category, and more). |
| `alex_allowcreate` | Yes/No | Allow create in PayPlus. |
| `alex_allowupdate` | Yes/No | Allow update in PayPlus. |
| `alex_changehandlingmode` | Choice | Current state or stored payload. |
| `alex_coalesceupdates` | Yes/No | Collapse multiple pending updates. |
| `alex_missinguidpolicy` | Choice | Behaviour when the target UID is missing. |
| `alex_pluginstepstatus` | Choice | Registration status of the source-change plugin step. |
| `alex_isactive` | Yes/No | Active mapping. |

### PayPlus Field Mapping (`alex_payplus_fieldmapping`)

Field-level mapping between a source field and a PayPlus field.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | Field mapping name. |
| `alex_entitymappingid` | Lookup → Entity Mapping | Parent entity mapping. |
| `alex_sourcefieldlogicalname` | Text | Source field logical name. |
| `alex_sourcefielddisplayname` | Text | Source field display name. |
| `alex_targetfieldlogicalname` | Text | PayPlus target field name. |
| `alex_targetfielddisplayname` | Text | Target field display name. |
| `alex_sourcetype` | Choice | Source field, Constant, Formula, Lookup, Related record, Value mapping. |
| `alex_dataversetype` | Choice | Dataverse data type. |
| `alex_payplusdatatype` | Choice | PayPlus data type. |
| `alex_defaultvalue` | Text | Default value when source is empty. |
| `alex_nullhandling` | Choice | How to handle null values. |
| `alex_requiredforpayload` | Yes/No | Field is required in the payload. |
| `alex_transformruleid` | Lookup → Transform Rule | Optional transform applied to the value. |
| `alex_sortorder` | Whole number | Order in the payload. |
| `alex_isactive` | Yes/No | Active mapping. |

### PayPlus Filter Rule (`alex_payplus_filterrule`)

Optional sync conditions per entity mapping. Rules are evaluated with AND semantics.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | Rule name. |
| `alex_entitymappingid` | Lookup → Entity Mapping | Parent entity mapping. |
| `alex_sourcefieldlogicalname` | Text | Source field evaluated. |
| `alex_operator` | Choice | Equals, Not equals, Contains, Greater than, Less than, Empty, Not empty. |
| `alex_comparevalue` | Text | Value to compare against. |
| `alex_logicalgroup` | Text | Optional grouping label. |
| `alex_description` | Multiline | Rule description. |
| `alex_isactive` | Yes/No | Active rule. |

### PayPlus Transform Rule (`alex_payplus_transformrule`)

Reusable value transforms referenced by field mappings. Seeded idempotently by stable rule code.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | Rule name. |
| `alex_rulecode` | Text | Stable code used for idempotent seeding. |
| `alex_rulekind` | Choice | Transform kind (trim, lower, upper, phone normalize, and more). |
| `alex_outputtype` | Choice | Output data type. |
| `alex_expression` | Multiline | Transform expression. |
| `alex_parametersjson` | Multiline | Parameters as JSON. |
| `alex_description` | Multiline | Rule description. |
| `alex_isactive` | Yes/No | Active rule. |

### PayPlus Value Mapping (`alex_payplus_valuemapping`)

Explicit source-to-target value maps.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | Value mapping name. |
| `alex_syncprofileid` | Lookup → Sync Profile | Parent sync profile. |
| `alex_mappinggroup` | Text | Group name used to select the map. |
| `alex_sourcevalue` | Text | Source value. |
| `alex_targetvalue` | Text | Target value. |
| `alex_targetuid` | Text | Target UID when the map points to a PayPlus resource. |
| `alex_isdefault` | Yes/No | Default value for the group. |
| `alex_description` | Multiline | Description. |
| `alex_isactive` | Yes/No | Active mapping. |

### PayPlus Sync Outbox (`alex_payplus_syncoutbox`)

Pending outbound sync work items. Written by the source-change plugin and processed by the outbox flow.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | Work item name. |
| `alex_syncprofileid` | Lookup → Sync Profile | Owning profile. |
| `alex_entitymappingid` | Lookup → Entity Mapping | Owning mapping. |
| `alex_syncstateid` | Lookup → Sync State | Related sync state. |
| `alex_supersededbyid` | Lookup → Sync Outbox (self) | Newer item that replaces this one. |
| `alex_sourcetablelogicalname` | Text | Source table. |
| `alex_sourcerowid` | Text | Source record id. |
| `alex_sourceversionnumber` | Text | Source row version. |
| `alex_sourcemodifiedon` | Date/time | Source modified timestamp. |
| `alex_targetobject` | Choice | PayPlus target object. |
| `alex_operation` | Choice | Create, Update, Deactivate, Delete. |
| `alex_status` | Choice | Pending, Processing, Succeeded, Failed, Retry scheduled, Superseded, Skipped. |
| `alex_correlationkey` | Text | Correlation key. |
| `alex_payloadsnapshot` | Multiline | Built request payload snapshot. |
| `alex_responsesnapshot` | Multiline | Response snapshot. |
| `alex_attemptcount` | Whole number | Attempts so far. |
| `alex_maxattempts` | Whole number | Maximum attempts. |
| `alex_nextretryon` | Date/time | Next retry time. |
| `alex_lockeduntil` | Date/time | Processing lock expiry. |
| `alex_processingstartedon` | Date/time | Processing start time. |
| `alex_processedon` | Date/time | Processing completion time. |
| `alex_lastdetectedon` | Date/time | Last time the change was detected. |
| `alex_lasterror` | Multiline | Last error text. |

### PayPlus Sync State (`alex_payplus_syncstate`)

Last known PayPlus UID and status per source record. This is the correlation anchor between Dataverse and PayPlus.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | State name. |
| `alex_syncprofileid` | Lookup → Sync Profile | Owning profile. |
| `alex_entitymappingid` | Lookup → Entity Mapping | Owning mapping. |
| `alex_sourcetablelogicalname` | Text | Source table. |
| `alex_sourcerowid` | Text | Source record id. |
| `alex_correlationkey` | Text | Correlation key. |
| `alex_payplusuid` | Text | PayPlus UID of the synced resource. |
| `alex_payplusexternalnumber` | Text | PayPlus external number, when applicable. |
| `alex_lastoperation` | Choice | Last operation performed. |
| `alex_laststatus` | Choice | Last sync status. |
| `alex_lastsourceversionnumber` | Text | Last processed source version. |
| `alex_lastpayloadhash` | Text | Hash of the last payload (change detection). |
| `alex_lastsyncedon` | Date/time | Last successful sync time. |
| `alex_isactive` | Yes/No | Active state. |

### PayPlus Sync Log (`alex_payplus_synclog`)

Audit trail of sync attempts and results.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | Log entry name. |
| `alex_syncprofileid` | Lookup → Sync Profile | Owning profile. |
| `alex_outboxid` | Lookup → Sync Outbox | Related work item. |
| `alex_syncstateid` | Lookup → Sync State | Related sync state. |
| `alex_entitymappingid` | Lookup → Entity Mapping | Owning mapping. |
| `alex_eventtype` | Choice | Request, Response, Error, Retry, Skip, Validation, Info. |
| `alex_status` | Choice | Result status. |
| `alex_attemptnumber` | Whole number | Attempt number. |
| `alex_httpstatuscode` | Whole number | HTTP status code. |
| `alex_durationms` | Whole number | Duration in milliseconds. |
| `alex_payplusresultcode` | Text | PayPlus result code. |
| `alex_requestpayload` | Multiline | Request payload. |
| `alex_responsepayload` | Multiline | Response payload. |
| `alex_message` | Multiline | Log message. |
| `alex_occurredon` | Date/time | Event timestamp. |

### Credit Card (`alex_creditcard`)

Tokenized card metadata for an account or contact. No PAN or CVV is stored.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | Card record name. |
| `alex_account` | Lookup → Account | Owning account. |
| `alex_contact` | Lookup → Contact | Owning contact. |
| `alex_token` | Text | PayPlus card token. |
| `alex_paypluscustomeruid` | Text | PayPlus customer UID. |
| `alex_brand` | Choice | Card brand (Visa, Mastercard, Isracard, and more). |
| `alex_last4` | Text | Last four digits. |
| `alex_expirymonth` | Text | Expiry month. |
| `alex_expiryyear` | Text | Expiry year. |
| `alex_cardholdername` | Text | Cardholder name. |
| `alex_channel` | Choice | Capture channel (Manual, Email, SMS, WhatsApp). |
| `alex_isdefault` | Yes/No | Default card for the parent. |
| `alex_isactive` | Yes/No | Active card. |

### Card Collection Session (`alex_pp_hfsession`)

Hosted-fields / self-service card capture session used by the tokenization polling flow.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` | Text | Session name. |
| `alex_account` | Lookup → Account | Owning account. |
| `alex_contact` | Lookup → Contact | Owning contact. |
| `alex_channel` | Choice | Distribution channel (Manual, Email, SMS, WhatsApp). |
| `alex_requestid` | Text | Correlation id sent to PayPlus as `more_info`. |
| `alex_hostedfieldsuid` | Text | Hosted-fields session UID. |
| `alex_pagerequestuid` | Text | PayPlus page request UID. |
| `alex_paymentpagelink` | Text | Generated payment page link. |
| `alex_status` | Text | Session status. |
| `alex_message` | Text | Status or error message. |
| `alex_expireson` | Date/time | Session expiry. |

## Billing & Document Engine

These tables implement collection and Invoice+ document issuance. They are **independent of Dynamics 365 Sales** — the billing case is anchored to *any* source record through `alex_sourceentitylogicalname` + `alex_sourceentityid`, so a payment can be collected and a document issued with no invoice at all. When the source happens to be a Sales `invoice`, the extra Sales lookups (`alex_invoiceid`, `alex_invoicedetailid`) are populated as well.

```mermaid
erDiagram
    BILLINGCASE ||--o{ PAYMENTLINE : "collects via"
    BILLINGCASE ||--o{ RECEIPTALLOCATION : "settles via"
    BILLINGCASE ||--o{ DOCUMENT : "issues"
    PAYMENTLINE ||--o{ RECEIPTALLOCATION : "allocated by"
    PAYMENTLINE }o--o| DOCUMENT : "receipt"
    DOCUMENT ||--o{ DOCUMENTACTIONLOG : "logs"
    DOCUMENT }o--o| DOCUMENTTYPE : "typed as"
    DOCUMENT }o--o| DOCUMENT : "reverses / parent"
    ACCOUNT ||--o{ BILLINGCASE : "customer"
    CONTACT ||--o{ BILLINGCASE : "customer"
    BANK ||--o{ BANKBRANCH : "has"
    BANK ||--o{ CUSTOMERBANKACCOUNT : "at"
    BANKBRANCH ||--o{ CUSTOMERBANKACCOUNT : "at"
    ACCOUNT ||--o{ CUSTOMERBANKACCOUNT : "owns"
    CONTACT ||--o{ CUSTOMERBANKACCOUNT : "owns"

    BILLINGCASE {
        guid alex_payplusbillingcaseid PK
        string alex_sourceentitylogicalname
        string alex_sourceentityid
        decimal alex_totalamount
        decimal alex_openbalance
        choice alex_status
        choice alex_defaultflow
    }
    PAYMENTLINE {
        guid alex_paypluspaymentlineid PK
        lookup alex_billingcaseid FK
        decimal alex_amount
        choice alex_paymentmethod
        choice alex_status
        lookup alex_receiptdocumentid FK
    }
    RECEIPTALLOCATION {
        guid alex_payplusreceiptallocationid PK
        lookup alex_billingcaseid FK
        lookup alex_paymentlineid FK
        decimal alex_allocatedamount
        choice alex_status
    }
    DOCUMENT {
        guid alex_payplusdocumentid PK
        lookup alex_billingcaseid FK
        choice alex_documentrole
        string alex_documentnumber
        decimal alex_totalamount
        string alex_documentstatus
    }
```

### Billing Case (`alex_payplusbillingcase`)

The collection anchor for one source record. Amount columns are maintained as payments and allocations progress.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` / `alex_uniqueidentifier` | Text | Case name and stable key. |
| `alex_sourceentitylogicalname` | Text | Logical name of the source record (e.g. `invoice`, or any custom table). |
| `alex_sourceentityid` | Text | Id of the source record. |
| `alex_sourcedisplayname` / `alex_sourceurl` | Text | Human label and deep link back to the source. |
| `alex_accountid` / `alex_contactid` | Lookup | Customer (account or contact). |
| `alex_configurationid` | Lookup → Configuration | Owning PayPlus configuration. |
| `alex_totalamount` / `alex_vatamount` | Currency | Case total and VAT. |
| `alex_amountdue` / `alex_paidamount` / `alex_openbalance` | Currency | Due, paid, and remaining balance. |
| `alex_allocatedamount` / `alex_unallocatedamount` | Currency | Allocated vs. unallocated received funds. |
| `alex_processingamount` / `alex_pendingverificationamount` / `alex_failedamount` / `alex_futurecommitmentamount` | Currency | In-flight, awaiting verification, failed, and future-committed amounts. |
| `alex_status` | Choice | Case status (open, closed, cancelled). |
| `alex_defaultflow` | Choice | Expected document flow (e.g. tax-invoice-receipt). |
| `alex_allowpartialreceipts` / `alex_requirereceipttocloseinvoice` | Yes/No | Partial-payment and closing policies. |
| `alex_documentstatussummary` / `alex_lastissueddocument` / `alex_nextexpecteddocument` | Text | Document progress summary. |
| `alex_openedon` / `alex_closedon` / `alex_cancelledon` | Date/time | Lifecycle timestamps. |

### Payment Line (`alex_paypluspaymentline`)

One payment attempt/receipt against a billing case. Supports card, saved token, bank transfer, check (including check series), and cash, with clearing and manual bank-verification workflows.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_billingcaseid` | Lookup → Billing Case | Parent case. |
| `alex_amount` / `alex_currencycode` | Currency / Text | Payment amount and currency. |
| `alex_paymentmethod` | Choice | Card, token, bank transfer, check, cash. |
| `alex_chargemode` | Choice | How the charge is executed. |
| `alex_status` | Choice | Payment status. |
| `alex_creditcardid` | Lookup → Credit Card | Saved token used, if any. |
| `alex_cardbrand` / `alex_cardlast4` / `alex_approvalnumber` / `alex_installments` | Text / Number | Card result details. |
| `alex_customerbankaccountid` / `alex_companybankaccountid` | Lookup | Bank accounts for transfers. |
| `alex_banknumber` / `alex_branchnumber` / `alex_accountnumber` / `alex_checknumber` | Text | Bank/check identifiers. |
| `alex_clearingstatus` / `alex_clearedon` / `alex_valuedate` / `alex_depositdate` | Choice / Date | Clearing lifecycle. |
| `alex_bankverificationstatus` / `alex_verifiedamount` / `alex_verifiedon` / `alex_verifiedby` | Choice / Currency / Date / Text | Manual bank-verification. |
| `alex_receiptdocumentid` | Lookup → Document | Receipt issued for this payment. |
| `alex_requesteddocflow` / `alex_issueremainderdoc` / `alex_remainderdocflow` | Choice / Yes-No | Document flow requested for this payment. |
| `alex_idempotencykey` / `alex_externaltransactionid` / `alex_requestid` | Text | Idempotency and correlation. |
| `alex_islocked` / `alex_lockuntil` / `alex_retryblocked` | Yes-No / Date | Concurrency and retry guards. |

### Receipt Allocation (`alex_payplusreceiptallocation`)

Allocates a payment line to what it settles: a whole invoice, an invoice detail line, or a generic source line. Keeps snapshots for auditability.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_billingcaseid` | Lookup → Billing Case | Parent case. |
| `alex_paymentlineid` | Lookup → Payment Line | Payment being allocated. |
| `alex_allocatedamount` / `alex_actualallocatedamount` / `alex_proposedamount` | Currency | Proposed vs. actual allocation. |
| `alex_allocationtype` | Choice | What is being settled. |
| `alex_status` | Choice | Allocation status. |
| `alex_invoiceid` / `alex_invoicedetailid` | Lookup | Sales targets (only when the source is Sales). |
| `alex_invoicedocumentid` / `alex_receiptdocumentid` | Lookup → Document | Related PayPlus documents. |
| `alex_sourcelineid` / `alex_sourcelinenumber` / `alex_sourceitemname` | Text | Generic (non-Sales) source line. |
| `alex_openamountsnapshot` / `alex_remainingafterallocation` | Currency | Balance snapshots. |
| `alex_activatedon` / `alex_reversedon` / `alex_cancelledon` / `alex_failedon` | Date/time | Lifecycle timestamps. |

### PayPlus Document (`alex_payplusdocument`)

An Invoice+ document. This is the table the *Preview* flows and the Document Ledger / Document Preview controls read; a pending row triggers the document flow.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` / `alex_documentnumber` / `alex_uniqueidentifier` | Text | Names and numbers. |
| `alex_billingcaseid` | Lookup → Billing Case | Owning case. |
| `alex_documentrole` / `alex_documenttypecode` / `alex_documenttypeid` | Choice / Text / Lookup | Document role and type. |
| `alex_documentstatus` / `alex_businessstatus` / `alex_workbenchdocumentstatus` | Text / Choice | Status fields. |
| `alex_totalamount` / `alex_vatamount` / `alex_vatpercentage` / `alex_paidamount` / `alex_balanceamount` | Currency | Amounts. |
| `alex_currencycode` / `alex_conversionrate` | Text / Decimal | Currency. |
| `alex_accountid` / `alex_contactid` | Lookup | Customer. |
| `alex_customername` / `alex_customeremail` / `alex_customervatnumber` / `alex_customeraddress` | Text | Denormalized customer details. |
| `alex_invoiceid` / `alex_quoteid` / `alex_salesorderid` | Lookup | Sales source (only when applicable). |
| `alex_sourceentitylogicalname` / `alex_sourceentityid` / `alex_sourceurl` | Text | Generic source linkage. |
| `alex_parentdocumentid` / `alex_reversesdocumentid` / `alex_relatedinvoicedocumentid` | Lookup → Document | Document relationships. |
| `alex_payplusdocumentuuid` / `alex_transactionuid` / `alex_paymentrequestuid` | Text | PayPlus identifiers. |
| `alex_pdfurl` / `alex_copypdfurl` / `alex_documenturl` / `alex_paymentpagelink` | Text | Links. |
| `alex_requestedaction` / `alex_requestedactionstatus` / `alex_requestedchannel` / `alex_requestedlinktype` | Choice | Requested action (send/link) and channel. |
| `alex_sentbyemail` / `alex_sentbysms` / `alex_sentbywhatsapp` | Yes/No | Distribution flags. |
| `alex_terminalid` / `alex_paymentpageid` / `alex_configurationid` | Lookup | PayPlus routing. |
| `alex_environment` | Choice | Sandbox / Production. |
| `alex_itemsjson` / `alex_paymentsjson` / `alex_rawrequest` / `alex_rawresponse` | Multiline | Raw payloads. |

### Document Action Log (`alex_payplusdocumentactionlog`)

Audit trail of actions requested on a document.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_payplusdocumentid` | Lookup → Document | Target document. |
| `alex_action` | Choice | Action requested. |
| `alex_channel` / `alex_linktype` | Choice | Delivery channel and link type. |
| `alex_status` | Choice | Action status. |
| `alex_resolvedlink` | Text | Generated link. |
| `alex_requestedby` / `alex_requestedon` | Text / Date | Who/when. |
| `alex_message` / `alex_payloadjson` | Multiline | Detail and payload. |

### Document Type (`alex_payplus_documenttype`)

Imported catalog of PayPlus document types (populated by the *Import Document Types* flow).

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` / `alex_code` / `alex_typecode` | Text / Number | Type name and codes. |
| `alex_titleen` / `alex_titlehe` / `alex_payplustitle` | Text | Bilingual titles. |
| `alex_category` | Choice | Document category. |
| `alex_caninitiate` / `alex_declarable` / `alex_hidden` / `alex_isactive` | Yes/No | Policy flags. |
| `alex_configurationid` / `alex_syncprofileid` | Lookup | Owning configuration/profile. |
| `alex_environment` / `alex_source` | Choice | Environment and origin. |

### Bank (`alex_bank`) and Bank Branch (`alex_bankbranch`)

Reference data imported by the *Import Banks & Branches* flow and used by the Bank Account Wallet.

| Table | Column | Type | Explanation |
| --- | --- | --- | --- |
| `alex_bank` | `alex_name` / `alex_bankcode` | Text / Number | Bank name and code. |
| `alex_bank` | `alex_ispayplussupported` / `alex_payplusbankname` | Yes-No / Text | PayPlus support. |
| `alex_bankbranch` | `alex_bankid` | Lookup → Bank | Parent bank. |
| `alex_bankbranch` | `alex_name` / `alex_branchcode` | Text / Number | Branch name and code. |
| `alex_bankbranch` | `alex_city` / `alex_branchaddress` / `alex_zipcode` / `alex_telephone` | Text | Branch location. |

### Customer Bank Account (`alex_customerbankaccount`)

A customer's bank account, surfaced and edited by the Bank Account Wallet control.

| Column | Type | Explanation |
| --- | --- | --- |
| `alex_name` / `alex_accountholdername` | Text | Account name and holder. |
| `alex_accountid` / `alex_contactid` | Lookup | Owning customer. |
| `alex_bankid` / `alex_branchid` | Lookup | Bank and branch. |
| `alex_accountnumber` / `alex_iban` / `alex_swift` | Text | Account identifiers. |
| `alex_hasstandingorder` / `alex_standingorderreference` / `alex_standingordersince` | Yes-No / Text / Date | Standing order. |
| `alex_isdefault` / `alex_isactive` / `alex_isverified` | Yes/No | State flags. |
| `alex_paypluscustomerbankaccountuid` / `alex_syncstatus` | Text / Choice | PayPlus linkage. |

## Choice Reference

### Environment (`alex_environment`)

The `alex_environment` choice uses **two different value mappings** depending on the table. Be careful not to confuse them.

**Environment — configuration, terminal, and payment page tables** (`alex_payplusconfiguration`, `alex_payplus_terminal`, `alex_payplus_paymentpage`):

| Value | Label |
| --- | --- |
| 100000000 | Production |
| 100000001 | Sandbox |

**Environment — sync profile and sync runtime tables** (`alex_payplus_syncprofile`, `alex_payplus_syncoutbox`, `alex_payplus_syncstate`, `alex_payplus_synclog`):

| Value | Label |
| --- | --- |
| 100000000 | Sandbox |
| 100000001 | Production |

### Default operation mode (`alex_defaultoperationmode`)

| Value | Label |
| --- | --- |
| 100000000 | Create only |
| 100000001 | Update only |
| 100000002 | Create and update |

### Target object (`alex_targetobject`)

35 values covering PayPlus resources, including: Customer, Product, Category, Invoice, Quote, Transaction invoice, Order, Payment request, Purchase order, Customer bank account, Company bank account, Saved card token, Recurring payment, Recurring charge, Transaction, Transactions report, Payment page, Coupon group, Coupon, Cashier, Device, Deposit, SMS contact, SMS group, SMS message, OTP request, Invoice+ expense, Invoice+ document, Banks dictionary, Branches dictionary, Terminal, Currency, Alternative payment method, Error code, Card brand. Values run 100000000–100000034.

### Field mapping source type (`alex_sourcetype`)

| Value | Label |
| --- | --- |
| 100000000 | Source field |
| 100000001 | Constant |
| 100000002 | Formula |
| 100000003 | Lookup |
| 100000004 | Related record |
| 100000005 | Value mapping |

### Filter operator (`alex_operator`)

| Value | Label |
| --- | --- |
| 100000000 | Equals |
| 100000001 | Not equals |
| 100000002 | Contains |
| 100000003 | Greater than |
| 100000004 | Less than |
| 100000005 | Empty |
| 100000006 | Not empty |

### Transform kind (`alex_rulekind`)

| Value | Label |
| --- | --- |
| 100000000 | None |
| 100000001 | Trim whitespace |
| 100000002 | Lowercase |
| 100000003 | Uppercase |
| 100000004 | Phone normalize |
| 100000005 | GUID to text |
| 100000006 | Lookup value |
| 100000007 | Value mapping |
| 100000008 | Default value |
| 100000009 | Concatenate |
| 100000010 | Currency code |

### Outbox status (`alex_status`)

| Value | Label |
| --- | --- |
| 100000000 | Pending |
| 100000001 | Processing |
| 100000002 | Succeeded |
| 100000003 | Failed |
| 100000004 | Retry scheduled |
| 100000005 | Superseded |
| 100000006 | Skipped |

### Outbox operation (`alex_operation`)

| Value | Label |
| --- | --- |
| 100000000 | Create |
| 100000001 | Update |
| 100000002 | Deactivate |
| 100000003 | Delete |

### Sync log event type (`alex_eventtype`)

| Value | Label |
| --- | --- |
| 100000000 | Request |
| 100000001 | Response |
| 100000002 | Error |
| 100000003 | Retry |
| 100000004 | Skip |
| 100000005 | Validation |
| 100000006 | Info |

### Setup stage (`alex_setupstage`)

| Value | Label |
| --- | --- |
| 100000000 | Connect |
| 100000001 | Terminals & pages |
| 100000002 | Validate |
| 100000003 | Done |

### Card brand (`alex_brand`)

| Value | Label |
| --- | --- |
| 1 | Visa |
| 2 | Mastercard |
| 3 | Isracard |
| 4 | American Express |
| 5 | Diners |
| 6 | JCB |
| 7 | UnionPay |
| 8 | Maestro |
| 9 | Private / local |
| 10 | Other |
| 11 | Discover |

### Card / session channel (`alex_channel`)

Used by the `alex_creditcard` and `alex_pp_hfsession` tables. This is a **different** choice from the payment-page Channel below.

| Value | Label |
| --- | --- |
| 100000000 | Manual |
| 100000001 | Email |
| 100000002 | SMS |
| 100000003 | WhatsApp |

### Activity type (`alex_activitytype`) — terminal

| Value | Label |
| --- | --- |
| 100000000 | Website |
| 100000001 | Call Center |
| 100000002 | Retail |
| 100000003 | Donations |
| 100000004 | Other |

### Primary currency (`alex_primarycurrency`) — terminal

| Value | Label |
| --- | --- |
| 100000000 | ILS |
| 100000001 | USD |
| 100000002 | EUR |
| 100000003 | GBP |

### CVV policy (`alex_cvv_policy`) — terminal

| Value | Label |
| --- | --- |
| 100000000 | Required |
| 100000001 | Not Required |
| 100000002 | Conditional |
| 100000003 | Unknown |

### 3D Secure policy (`alex_threeds_policy`) — terminal and payment page

| Value | Label |
| --- | --- |
| 100000000 | Default |
| 100000001 | On |
| 100000002 | Off |
| 100000003 | Conditional |

### Process type (`alex_processtype`) — payment page

| Value | Label |
| --- | --- |
| 100000000 | Charge |
| 100000001 | Approval |
| 100000002 | Check |
| 100000003 | Token Only |
| 100000004 | Recurring |

### Purpose (`alex_purpose`) — payment page

| Value | Label |
| --- | --- |
| 100000000 | Call Center |
| 100000001 | Website |
| 100000002 | Donation |
| 100000003 | Invoice |
| 100000004 | QR |
| 100000005 | Subscription |
| 100000006 | Card Update |
| 100000007 | Event |
| 100000008 | Approval |
| 100000009 | Brand |
| 100000010 | Business Customer |
| 100000011 | Private Customer |

### Audience (`alex_audience`) — payment page

| Value | Label |
| --- | --- |
| 100000000 | New Customer |
| 100000001 | Existing Customer |
| 100000002 | Subscriber |
| 100000003 | Business |
| 100000004 | Donor |
| 100000005 | Private |

### Channel (`alex_channel`) — payment page

This is a **different** choice from the Card / session channel above.

| Value | Label |
| --- | --- |
| 100000000 | Website |
| 100000001 | Call Center |
| 100000002 | WhatsApp |
| 100000003 | Email |
| 100000004 | QR |

### Token behavior (`alex_tokenbehavior`) — payment page

| Value | Label |
| --- | --- |
| 100000000 | No Token |
| 100000001 | Optional |
| 100000002 | Required |
| 100000003 | Token Only |

## Notes

- Every table also carries the standard `statecode` (State) and `statuscode` (Status reason) columns.
- Lookup columns expose a shadow `...name` text column that mirrors the parent primary name; those helper columns are omitted above.
- No table stores PAN or CVV. Only tokens and non-sensitive card metadata are persisted.
