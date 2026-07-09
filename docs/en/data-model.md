# Proposed Dataverse Data Model (Not Implemented)

## Scope

This document is a future data model proposal only. The tables described here do not currently exist in the delivered connector artifacts and are not created by this repository.

Use this document only if a later implementation decides to add Dataverse payment tracking, reconciliation, support, auditing, or a business-facing payment request record.

Logical names use a neutral `pp_` prefix. Replace it with the customer's publisher prefix during implementation.

## Data Storage Rules

- Store payment metadata, identifiers, statuses, and links when approved.
- Do not store PAN.
- Do not store CVV.
- Treat tokens as sensitive and store them only after security approval.
- Do not store PayPlus API keys or secret keys in Dataverse tables.
- Avoid storing full raw PayPlus payloads unless they are classified, minimized, and access controlled.

## Table: Payment Request

| Attribute | Value |
| --- | --- |
| Logical name | `pp_paymentrequest` |
| English display name | Payment Request |
| Hebrew display name | בקשת תשלום |
| Purpose | Represents a business request to collect payment through PayPlus |

### Key Fields

| Field | Type | Sensitive | May Store | Notes |
| --- | --- | --- | --- | --- |
| `pp_name` | Text | No | Yes | Human-readable request number or title |
| `pp_customerid` | Lookup | Yes | Yes | Lookup to Account, Contact, or customer table |
| `pp_amount` | Currency/Decimal | No | Yes | Amount requested |
| `pp_currencycode` | Choice/Text | No | Yes | ILS, USD, EUR, GBP, as approved |
| `pp_terminaluid` | Text | Low | Yes | PayPlus terminal UUID, not a secret |
| `pp_paymentpageuid` | Text | Low | Yes | Payment page UID, not a secret but should not be publicized unnecessarily |
| `pp_paymentlink` | URL | Medium | Yes | Treat as sensitive if link can be used by customer |
| `pp_pagerequestuid` | Text | Low | Yes | PayPlus page request UID |
| `pp_status` | Choice | No | Yes | Business lifecycle status |
| `pp_expireson` | DateTime | No | Yes | Link expiry if applicable |
| `pp_senton` | DateTime | No | Yes | When link was sent |
| `pp_paidon` | DateTime | No | Yes | Payment completion time |
| `pp_correlationid` | Text | Low | Yes | Flow or business correlation key |
| `pp_lastmessage` | Text | Medium | Yes | Sanitized message only |

### Relationships

- Many Payment Requests to one Account or Contact.
- One Payment Request to many Payment Transactions.
- One Payment Request to many Payment Events / Webhook Logs.

### Statuses

- Draft
- Link Created
- Sent
- Paid
- Failed
- Expired
- Cancelled
- Refunded
- Pending Review

### Security Notes

Payment link may be sensitive because anyone with the link may attempt payment depending on PayPlus settings. Restrict access to business users who need it.

## Table: Payment Transaction

| Attribute | Value |
| --- | --- |
| Logical name | `pp_paymenttransaction` |
| English display name | Payment Transaction |
| Hebrew display name | עסקת תשלום |
| Purpose | Stores PayPlus transaction metadata for reconciliation and support |

### Key Fields

| Field | Type | Sensitive | May Store | Notes |
| --- | --- | --- | --- | --- |
| `pp_name` | Text | No | Yes | Transaction display name |
| `pp_paymentrequestid` | Lookup | No | Yes | Parent payment request |
| `pp_transactionuid` | Text | Low | Yes | PayPlus transaction UID, recommended alternate key |
| `pp_pagerequestuid` | Text | Low | Yes | Link request UID |
| `pp_status` | Choice | No | Yes | Transaction status |
| `pp_amount` | Currency/Decimal | No | Yes | Paid, refunded, or attempted amount |
| `pp_currencycode` | Choice/Text | No | Yes | Currency |
| `pp_approvalnumber` | Text | Medium | Yes | Approval or voucher reference if returned |
| `pp_cardlast4` | Text | Medium | Yes, if approved | Last four only, never full PAN |
| `pp_cardbrand` | Text | Low | Yes, if approved | Brand only |
| `pp_cardexpiry` | Text | Medium | Avoid unless required | Store only if approved by policy |
| `pp_tokenreference` | Text | High | Only with approval | Token reference or alias, not raw card data |
| `pp_rawresponse` | Multiline text | High | Avoid | Use only if minimized and access controlled |
| `pp_lastcheckedon` | DateTime | No | Yes | Last reconciliation check |

### Relationships

- Many Payment Transactions to one Payment Request.
- Many Payment Events to one Payment Transaction.

### Statuses

- Pending
- Approved
- Declined
- Failed
- Cancelled
- Refunded
- Partially Refunded
- Chargeback
- Unknown

### Security Notes

Do not store full raw PayPlus responses by default. Extract only required fields. Token references require explicit approval.

## Table: Payment Provider Configuration

| Attribute | Value |
| --- | --- |
| Logical name | `pp_paymentproviderconfiguration` |
| English display name | Payment Provider Configuration |
| Hebrew display name | הגדרת ספק תשלום |
| Purpose | Stores non-secret configuration and setup state for PayPlus integration |

### Key Fields

| Field | Type | Sensitive | May Store | Notes |
| --- | --- | --- | --- | --- |
| `pp_name` | Text | No | Yes | Configuration name, often singleton |
| `pp_environment` | Choice | No | Yes | Sandbox or Production |
| `pp_defaultterminaluid` | Text | Low | Yes | Optional default terminal |
| `pp_defaultpaymentpageuid` | Text | Low | Yes | Optional default payment page |
| `pp_connectionverified` | Boolean | No | Yes | Last connection verification result |
| `pp_lastvalidationstatus` | Choice | No | Yes | Pending, Success, Failed |
| `pp_lastvalidationcode` | Integer | No | Yes | Sanitized status or error code |
| `pp_lastvalidationmessage` | Text | Medium | Yes | Sanitized only |
| `pp_lastvalidatedon` | DateTime | No | Yes | Last validation timestamp |
| `pp_setupstage` | Choice | No | Yes | Connect, Pages, Validate, Done |

### Relationships

- One configuration can be referenced by flows and setup screens.
- Avoid relating secrets to this table.

### Statuses

- Not Started
- Pending
- Success
- Failed
- Disabled

### Security Notes

Do not store `api-key`, `secret-key`, client secrets, SAS URLs, or Key Vault secret values in this table.

## Table: Payment Page Cache

| Attribute | Value |
| --- | --- |
| Logical name | `pp_paymentpagecache` |
| English display name | Payment Page Cache |
| Hebrew display name | מטמון דפי תשלום |
| Purpose | Caches PayPlus payment pages for setup and user selection |

### Key Fields

| Field | Type | Sensitive | May Store | Notes |
| --- | --- | --- | --- | --- |
| `pp_name` | Text | No | Yes | Payment page display name |
| `pp_paymentpageuid` | Text | Low | Yes | PayPlus page UID |
| `pp_terminaluid` | Text | Low | Yes | Parent terminal UID |
| `pp_terminalname` | Text | No | Yes | Friendly terminal name |
| `pp_valid` | Boolean/Choice | No | Yes | Active or valid flag from PayPlus |
| `pp_currencycode` | Text | No | Yes | Default currency if returned |
| `pp_lastrefreshedon` | DateTime | No | Yes | Cache timestamp |
| `pp_rawmetadata` | Multiline text | Medium | Avoid | Store only sanitized metadata |

### Relationships

- Many Payment Page Cache rows to one Terminal Cache row.
- Payment Requests may reference a payment page cache row.

### Statuses

- Active
- Inactive
- Unknown

### Security Notes

Payment page UID is not a secret but should be treated as operational configuration.

## Table: Terminal Cache

| Attribute | Value |
| --- | --- |
| Logical name | `pp_terminalcache` |
| English display name | Terminal Cache |
| Hebrew display name | מטמון מסופים |
| Purpose | Caches PayPlus terminal options for setup and validation |

### Key Fields

| Field | Type | Sensitive | May Store | Notes |
| --- | --- | --- | --- | --- |
| `pp_name` | Text | No | Yes | Terminal display name |
| `pp_terminaluid` | Text | Low | Yes | PayPlus terminal UUID |
| `pp_terminaltypeid` | Integer/Text | No | Yes | If returned |
| `pp_merchantnumber` | Text | Medium | Yes, if approved | May be considered sensitive by policy |
| `pp_status` | Choice/Integer | No | Yes | Active or inactive |
| `pp_lastrefreshedon` | DateTime | No | Yes | Cache timestamp |

### Relationships

- One Terminal Cache row to many Payment Page Cache rows.
- Payment Requests may reference a terminal cache row.

### Statuses

- Active
- Inactive
- Unknown

### Security Notes

Terminal UID is operational configuration, not a credential. Do not store terminal-scoped API keys here.

## Table: Payment Event / Webhook Log

| Attribute | Value |
| --- | --- |
| Logical name | `pp_paymenteventlog` |
| English display name | Payment Event / Webhook Log |
| Hebrew display name | לוג אירועי תשלום / Webhook |
| Purpose | Stores inbound payment events, status retrieval events, and processing results |

### Key Fields

| Field | Type | Sensitive | May Store | Notes |
| --- | --- | --- | --- | --- |
| `pp_name` | Text | No | Yes | Event display name |
| `pp_eventtype` | Choice/Text | No | Yes | Webhook, status pull, manual refresh |
| `pp_paymentrequestid` | Lookup | No | Yes | Related request |
| `pp_paymenttransactionid` | Lookup | No | Yes | Related transaction if known |
| `pp_eventtime` | DateTime | No | Yes | Event timestamp |
| `pp_signaturevalid` | Boolean | No | Yes | If webhook signature validation exists |
| `pp_processingstatus` | Choice | No | Yes | Received, Processed, Failed, Ignored |
| `pp_correlationid` | Text | Low | Yes | Flow or message correlation |
| `pp_sanitizedpayload` | Multiline text | High | Only if approved | Redact or avoid raw payloads |
| `pp_errormessage` | Multiline text | Medium | Yes | Sanitized failure reason |

### Relationships

- Many events to one Payment Request.
- Many events to one Payment Transaction.

### Statuses

- Received
- Signature Failed
- Processed
- Failed
- Ignored
- Duplicate

### Security Notes

Webhook payload storage must be reviewed before production. Prefer storing parsed, required fields rather than raw payloads.

## Recommended Alternate Keys

| Table | Alternate key |
| --- | --- |
| Payment Request | `pp_pagerequestuid` when available |
| Payment Transaction | `pp_transactionuid` |
| Terminal Cache | `pp_terminaluid` |
| Payment Page Cache | `pp_paymentpageuid` |
| Payment Event Log | External event ID or hash, if available |

## Open Questions

- Exact Dynamics 365 tables for customer, order, invoice, or case references must be confirmed per implementation.
- Whether to store token references depends on PCI and security approval.
- Whether webhook payloads can be stored depends on classification and retention requirements.
