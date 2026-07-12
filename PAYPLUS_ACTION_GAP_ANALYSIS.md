# PayPlus Connector Action Gap Analysis

Date: 2026-07-09  
Scope: current Dynamics 365 / Power Platform custom connector definitions under `_conn/apiDefinition.*.json`, compared with the official PayPlus API v1.0 reference.

## Current Implementation Status

This document started as a connector gap analysis. The current solution has since moved beyond the original five-action connector and now includes a generic Dynamics-to-PayPlus sync runtime:

| Area | Current status |
|---|---|
| Connectors | Separate PayPlus Production and PayPlus Sandbox custom connectors, both using connection-level `apiKey` and `secretKey` secure parameters injected into headers by connector policy. |
| Actions | Payment, customer, product, product category, transaction, recurring payment, saved-card charge, and Invoice+ document actions have been added to the connector definitions. |
| Runtime pattern | Dataverse plugin queues work only; Power Automate performs all PayPlus connector calls. |
| Generic sync | `alex_payplus_entitymapping` and `alex_payplus_fieldmapping` drive payload creation. The runtime is not hard-coded to Account/Contact. |
| Step registration | `alex_ReconcilePayPlusSyncSteps` creates or updates Dataverse SDK plugin steps per configured source table and message. This supports managed-solution deployment because customer-specific table steps are created in the target environment at configuration time. |
| Processing flow | `PayPlus - Process Sync Outbox` processes `alex_payplus_syncoutbox`, branches by sync profile environment, calls the Sandbox or Production connector, validates `results.status`, and stores results in Sync State / Sync Log. |
| Validation | Contact-to-Customer sync has been validated end to end with a mapping-built payload containing nested `contacts[]` and a successful PayPlus `customer_uid` response. |

Known current limitations: the payload builder supports direct fields, constants, selected transform rules, null handling, and nested target paths. Related-record lookups and value-mapping execution are intentionally treated as extension work before broad production rollout. Advanced PayPlus targets such as documents, transactions, and recurring payments should usually be handled by explicit business flows rather than automatic table sync.

## Executive Summary

The original connector was intentionally narrow and exposed only five actions:

| Current action | Route | Area | Status |
|---|---|---|---|
| `GeneratePaymentLink` | `POST /PaymentPages/generateLink` | Payments / payment pages | Existing |
| `CreateCustomer` | `POST /Customers/Add` | Customers | Existing, partial coverage |
| `TestConnection` | `GET /PaymentPages/ChargeMethods` | Payments validation | Existing |
| `RefundByTransaction` | `POST /Transactions/refundByTransactionUID` | Transactions | Existing, partial coverage |
| `CreateRecurringPayment` | `POST /RecurringPayments/add` | Recurring payments | Existing, partial coverage |

The original major gap was Invoice+. Dedicated document actions have since been added, so the remaining work is not action discovery; it is workflow hardening, exact customer-specific mapping, and connector-runtime validation in each target environment. `GeneratePaymentLink` still only covers document creation as a side effect of payment and does not replace deliberate Invoice+ workflows.

Recommendation: keep one PayPlus connector per environment for now, but add clearly grouped actions for `Transactions` and `Invoice+`. In the setup wizard, add a capability/mode selection: `Payments`, `Invoices only`, or `Payments + Invoices`.

## Design Principles

1. Do not expose the entire PayPlus API blindly. Add actions that map to real Dynamics workflows.
2. Keep payment and invoice workflows separate at the action/flow level, even if they live in one connector.
3. For invoice-only customers, do not require `payment_page_uid` and do not validate only with `PaymentPages/ChargeMethods`.
4. Prefer idempotent invoice creation by using PayPlus `unique_identifier` mapped from a Dynamics document/order/invoice id.
5. Use `api-key` and `secret-key` headers consistently on every connector operation, matching the existing connector model.

## Priority Legend

| Priority | Meaning |
|---|---|
| P0 | Required for the product to support the workflow correctly |
| P1 | Strongly recommended for production operations and supportability |
| P2 | Useful extension, but not needed for the first complete slice |
| Future | Keep out of the first scope unless a customer requires it |

---

# Transactions / Clearing

Transactions are the payment-processing surface: direct card charge, authorization, capture/charge by previous transaction, refund, cancellation, transaction lookup, and reports. This is the current connector's more mature side, but it is still incomplete.

## Existing Coverage

| Action | Route | Meaning | Key fields currently modeled | Gaps |
|---|---|---|---|---|
| `GeneratePaymentLink` | `POST /PaymentPages/generateLink` | Creates a hosted PayPlus payment link for a one-time, token, refund, approval, or recurring payment flow. | `payment_page_uid`, `charge_method`, `amount`, `currency_code`, `more_info`, `initial_invoice`, callbacks, `customer`, `items` | Good first action, but it is payment-page based, not direct transaction processing. |
| `TestConnection` | `GET /PaymentPages/ChargeMethods` | Lightweight credentials/payment-page validation. | `payment_page_uid` | Payment-specific validation only. Not suitable as the only validation for invoice-only customers. |
| `RefundByTransaction` | `POST /Transactions/refundByTransactionUID` | Refunds an existing transaction by PayPlus transaction UID. | `transaction_uid`, `amount` | Missing fuller refund context and missing direct credit-card refund action. |
| `CreateRecurringPayment` | `POST /RecurringPayments/add` | Creates a recurring payment instruction. | `customer_uid`, `amount`, `currency_code` | Current schema is too minimal versus official recurring API. |

## Missing Transaction Actions

### P0 - `ChargeTransaction`

Route: `POST /Transactions/Charge`

Meaning: direct card charge / J4 transaction, without hosted payment page. Required if Dynamics should initiate a payment directly using card details or token.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `terminal_uid` | Yes | PayPlus terminal used for clearing. Should usually come from configuration, not manual flow input. |
| `cashier_uid` | Yes | PayPlus cashier. Usually configuration. |
| `amount` | Yes | Charge amount from Dynamics invoice/order/payment request. |
| `currency_code` | Yes | Usually `ILS`; should remain configurable. |
| `credit_terms` | Yes | Regular/credit/payments. Map from Dynamics payment terms if needed. |
| `use_token` | Yes | Whether to charge a saved token. |
| `token` | Conditional | Required when `use_token=true`. |
| `customer_uid` | Conditional | PayPlus customer uid; useful when charging by token or linking to a customer. |
| `customer` | Optional | Inline customer object when no `customer_uid` exists. |
| `credit_card` | Conditional | Required when not using token and doing direct charge. Sensitive; avoid storing in Dataverse. |
| `payments` | Optional | Installments/payment details. |
| `products` | Optional | Line items for invoice/payment context. |
| `initial_invoice` | Optional | Whether PayPlus should generate a document for the transaction. |
| `customer_name_invoice` | Conditional | Required in some invoice-integrated cases when no `customer_uid` exists. |
| `create_token` | Optional | Whether to return/store a card token for future charges. |
| `more_info_1`..`more_info_5` | Optional | Dynamics identifiers, correlation keys, or metadata. |
| `extra_info` | Optional | Free-form business context. |

Notes:
- This action is sensitive because it may involve card data. For most low-code Dynamics scenarios, hosted payment links are safer.
- If added, flows should avoid persisting raw card numbers/CVV anywhere in Dataverse.

### P0 - `ViewTransactions`

Route: `POST /Transactions/View`

Meaning: searches/fetches transaction records from PayPlus. Required for reconciliation, troubleshooting, and support.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `transaction_uid` | Conditional | Exact PayPlus transaction lookup. |
| `customer_uid` | Conditional | Search by PayPlus customer. |
| `fromDate` | Conditional | Start date for reconciliation window. |
| `untilDate` | Conditional | End date for reconciliation window. |
| `more_info` | Conditional | Search by Dynamics correlation key. |

Notes:
- At least one meaningful search key should be supplied.
- This should feed a Dataverse transaction log table keyed by `transaction_uid`.

### P0 - `CancelTransaction`

Route: `POST /Transactions/Cancel`

Meaning: cancels an unsettled transaction, usually same-day before deposit/cutoff. This is not the same as a refund.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `terminal_uid` | Yes | PayPlus terminal. |
| `cashier_uid` | Yes | PayPlus cashier. |
| `transaction_uid` | Yes | Original transaction to cancel. |

Notes:
- Use cancellation when settlement has not happened yet.
- Use refund after settlement/cutoff.

### P1 - `ChargeByTransactionUid`

Route: `POST /Transactions/ChargeByTransactionUID`

Meaning: charges/captures against a previous approval/J5 transaction.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `transaction_uid` | Yes | Original approval transaction UID. |
| `amount` | Yes | Amount to charge, not exceeding approved amount. |
| `more_info` | Optional | Dynamics correlation key or invoice line description. |
| `cvv` | Conditional | Required only if the terminal/company setup requires it. |
| `items` | Optional | Invoice/product lines for partial charge context. |

### P1 - `ApprovalTransaction`

Route: `POST /Transactions/Approval`

Meaning: J5 authorization/approval without immediate capture. Useful for reserve-now/capture-later business flows.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `terminal_uid` | Yes | PayPlus terminal. |
| `cashier_uid` | Yes | PayPlus cashier. |
| `amount` | Yes | Approved amount. |
| `currency_code` | Yes | Currency. |
| `credit_terms` | Yes | Payment terms. |
| `use_token` | Yes | Token vs direct card flow. |
| `token` | Conditional | Required when using token. |
| `credit_card` | Conditional | Required when not using token. |
| `customer_uid` / `customer` | Optional | Customer linkage. |
| `more_info_1`..`more_info_5` | Optional | Dynamics correlation keys. |

### P1 - `CheckCardTransaction`

Route: `POST /Transactions/Check`

Meaning: J2 card check/validation without a normal charge. Useful for card validation/tokenization flows, depending on PayPlus permissions.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `terminal_uid` | Yes | PayPlus terminal. |
| `cashier_uid` | Yes | PayPlus cashier. |
| `currency_code` | Yes | Currency. |
| `use_token` | Yes | Token vs card check. |
| `token` | Conditional | Existing card token. |
| `credit_card` | Conditional | Card object if not using token. |
| `customer_uid` / `customer` | Optional | Customer linkage. |
| `create_token` | Optional | Return a reusable token if permitted. |

### P1 - `RefundByCreditCard`

Route: `POST /Transactions/Refund`

Meaning: refund by credit card details/token rather than by original transaction UID.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `terminal_uid` | Yes | PayPlus terminal. |
| `cashier_uid` | Yes | PayPlus cashier. |
| `amount` | Yes | Refund amount. |
| `currency_code` | Yes | Currency. |
| `credit_terms` | Yes | Payment terms. |
| `use_token` | Yes | Whether refund uses a token. |
| `token` | Conditional | Required if `use_token=true`. |
| `credit_card` | Conditional | Required when not using token. |
| `customer_uid` / `customer` | Optional | Customer linkage. |
| `initial_invoice` | Optional | Whether to generate refund document if Invoice+ is connected. |
| `products` | Optional | Product/refund lines. |
| `payments` | Optional | Payment/refund distribution. |
| `notes` | Optional | Support/accounting note. |
| `more_info_1`..`more_info_5` | Optional | Dynamics correlation keys. |

### P1 - `GetDocumentsByTransactionUid`

Route: `POST /Invoice/GetDocuments`

Meaning: returns documents generated for a payment transaction. This bridges clearing and accounting.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `transaction_uid` | Optional per docs, but practically needed | PayPlus transaction UID. |
| `filter` | Yes | Filter object for document selection. |

Notes:
- Although this sits under transaction reports in the PayPlus docs, it is critical for payment-to-invoice reconciliation.

### P1 - `DisablePaymentLinkRequest`

Route: `POST /PaymentPages/Disable/{page_request_uid}`

Meaning: disables/cancels an unpaid hosted payment link.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `page_request_uid` | Yes | UID returned by `GeneratePaymentLink`. |

### P1 - `ListPaymentPages`

Route: `GET /PaymentPages/list/`

Meaning: lists payment pages for a terminal. Useful for setup/admin screens and validation.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `terminal_uid` | Yes | PayPlus terminal. |
| `skip` | Optional | Paging start. |
| `take` | Optional | Page size; max per docs is 500. |

### P1 - `GetPaymentPageIpnFull`

Route: `POST /PaymentPages/ipn-full`

Meaning: fetches full IPN/payment result data by payment request, transaction, approval, voucher, or more_info. Useful when callback delivery is missed or incomplete.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `payment_request_uid` | Conditional | Payment link request UID. |
| `transaction_uid` | Conditional | PayPlus transaction UID. |
| `related_transaction` | Optional | Include related transactions. |
| `approval_num` | Optional | Search by approval number. |
| `voucher_num` | Optional | Search by voucher number. |
| `more_info` | Optional | Dynamics correlation key. |

### P2 - Transaction Reports

These are useful for reconciliation jobs and operational dashboards.

| Proposed action | Route | Meaning | Key fields |
|---|---|---|---|
| `GetTransactionsHistory` | `POST /TransactionReports/TransactionsHistory` | Historical transaction report. | Date range, terminal/cashier filters, paging/filter object. |
| `GetTransactionsApprovalReport` | `POST /TransactionReports/TransactionsApproval` | Approval/J5 report. | Date range, terminal/cashier filters. |
| `GetRejectedTransactions` | `POST /TransactionReports/RejectsTransactions` | Failed/rejected transactions. | Date range, terminal/cashier filters. |
| `GetCancelledTransactions` | `POST /TransactionReports/CancelledTransactions` | Cancelled transaction report. | Date range, terminal/cashier filters. |

## Recurring Payments Gaps

Recurring is related to clearing but should be treated as a submodule.

| Priority | Proposed action | Route | Meaning | Key fields |
|---|---|---|---|---|
| P1 | `UpdateRecurringPayment` | `POST /RecurringPayments/Update/{uid}` | Update existing recurring order. | `uid`, `terminal_uid`, `customer_uid`, `card_token`, `cashier_uid`, `currency_code`, `instant_first_payment`, `recurring_type`, `recurring_range`, `number_of_charges`, `start_date`, `items`, invoice/email/SMS flags. |
| P1 | `DeleteRecurringPayment` | `POST /RecurringPayments/DeleteRecurring/{uid}` | Cancel/delete recurring order. | `uid`, `terminal_uid`. |
| P1 | `ValidateRecurringPayment` | `POST /RecurringPayments/{uid}/Valid` | Mark recurring order valid/invalid. | `uid`, validity/body fields per docs. |
| P1 | `ViewRecurringPayments` | `GET /RecurringPayments/View` | Search recurring payments. | `terminal_uid`, `customer_uid`, `search`, `skip`, `take`. |
| P2 | `GetRecurringPayment` | `GET /RecurringPayments/{uid}/ViewRecurring` | Fetch one recurring order. | `uid`. |
| P2 | `GetRecurringCharges` | `GET /RecurringPayments/{uid}/ViewRecurringCharge` | List charges for recurring order. | `uid`. |
| P2 | `AddRecurringCharge` | `POST /RecurringPayments/AddRecurringCharge/{uid}` | Add a scheduled charge. | `uid`, `terminal_uid`, `card_token`, `bank_account_uid`, `company_bank_account_uid`, `charge_date`, `valid`, `items`, `extra_info`. |
| P2 | `UpdateRecurringCharge` | `POST /RecurringPayments/UpdateRecurringCharge/{charge_uid}` | Update scheduled charge. | `charge_uid`, charge fields. |
| P2 | `DeleteRecurringCharge` | `POST /RecurringPayments/DeleteRecurringCharge/{charge_uid}` | Remove scheduled charge. | `charge_uid`. |

## Token Actions Gaps

Tokens become important if Dynamics charges saved cards rather than only sending hosted payment links.

| Priority | Proposed action | Route | Meaning | Key fields |
|---|---|---|---|---|
| P1 | `AddToken` | `POST /Token/Add` | Create/save card token. | Customer/card/payment fields per token docs. |
| P1 | `CheckToken` | `GET /Token/Check/{uid}` | Validate token status. | `uid`. |
| P1 | `ViewToken` | `GET /Token/View/{uid}` | Fetch token details. | `uid`. |
| P2 | `ListTokens` | `POST /Token/List` | Search/list tokens. | Customer/search/filter fields. |
| P2 | `UpdateToken` | `POST /Token/Update/{uid}` | Update token metadata. | `uid`, metadata/status fields. |
| P2 | `RemoveToken` | `POST /Token/Remove/{uid}` | Remove token. | `uid`. |

---

# Invoice+ / Accounting Documents

Invoice+ is the main future gap. This area supports tax document creation and retrieval independently from payment processing. It is required for customers that only use PayPlus for invoices, and for customers that need proper document lifecycle and reconciliation after payment.

## Current Coverage

There is no direct Invoice+ action in the current connector.

The only related field is `initial_invoice` inside payment actions such as `GeneratePaymentLink` and PayPlus transaction APIs. That field asks PayPlus to create a document as a side effect of payment. It does not replace the dedicated Invoice+ document API.

## Required Invoice+ Actions

### P0 - `CreateDocument`

Route: `POST /books/docs/new/{docType}`

Meaning: creates a new Invoice+ document directly. This is the core invoice-only action.

Common document types from PayPlus docs include:

| `docType` | Meaning |
|---|---|
| `inv_tax_receipt` | Tax invoice/receipt |
| `inv_tax` | Tax invoice |
| `inv_receipt` | Receipt |
| `inv_proforma` | Proforma invoice |
| `inv_refund` | Refund/credit document |
| `crt_delivery` | Delivery/shipping certificate |
| `crt_return` | Return certificate |
| `order_purchase` | Purchase order certificate |
| `purchase` | Purchase certificate |
| `dc_quote` | Quote |
| `inv_don_receipt` | Donation receipt |
| `inv_pay_request` | Payment request |

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `docType` | Yes | Document type path parameter. Map from Dynamics document type. |
| `doc_date` | Optional | Document issue date. Defaults to current date if omitted. |
| `brand_uuid` | Optional | Brand/business unit if multiple PayPlus brands exist. |
| `preview` | Optional | Preview only; no document generated. Useful before posting final document. |
| `draft` | Optional | Create draft only. Useful for approval workflows. |
| `hide_base_currency` | Optional | Hide base currency on foreign-currency documents. |
| `more_info` | Optional | Dynamics reference shown on document. |
| `close_doc` | Optional | UUID of document to close. Useful for closing proforma/payment request. |
| `cancel_doc` | Optional | UUID of document to cancel. Useful for formal cancellation flows. |
| `transaction_uuid` | Optional | PayPlus transaction UUID to link document to payment. |
| `send_document_email` | Optional | Send document by email. |
| `send_document_sms` | Optional | Send document by SMS. |
| `callback_url` | Optional | URL for successful document callback. |
| `vatType` | Optional | `vat-type-included`, `vat-type-not-included`, or `vat-type-exempt`. |
| `vat_percentage` | Optional | VAT percentage override. |
| `language` | Optional | `he` or `en`. |
| `currency_code` | Optional | Document currency, usually `ILS`. |
| `conversion_rate` | Conditional | Required/used for non-ILS if not auto-calculated. |
| `autocalculate_rate` | Optional | Auto-determine currency conversion rate. |
| `prevent_email` | Optional | Prevent email sending. |
| `unique_identifier` | Strongly recommended | Idempotency key from Dynamics invoice/order id. Prevents duplicate document creation. |
| `customer` | Yes for most flows | Customer object: name, VAT id, email, phone/address fields. |
| `tags` | Optional | Tags for cataloging/search. |
| `payments` | Conditional | Payment details if the document includes payment/receipt data. |
| `totalAmount` | Conditional | Total document amount. |
| `items` | Yes for invoice-like docs | Document lines: product/service, quantity, price, VAT behavior. |

Recommended Dynamics behavior:
- Use `unique_identifier` for every production create call.
- Store returned PayPlus document `uuid`, document number, type, status, PDF/link if returned, and callback result in Dataverse.
- Provide `preview=true` or `draft=true` as separate actions/parameters only if the business process needs approval before issuing the final document.

### P0 - `GetDocumentTypes`

Route: `GET /books/doc_types`

Meaning: returns available document types. This is also the best lightweight validation endpoint for invoice-only customers.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `language_code` | Optional | Preferred response language, e.g. `he`. |

Notes:
- For setup wizard mode `Invoices only`, use this endpoint instead of `PaymentPages/ChargeMethods`.

### P0 - `GetDocument`

Route: `GET /books/docs/get/{uuid}`

Meaning: retrieves document data by PayPlus document UUID.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `uuid` | Yes | PayPlus document UUID stored in Dataverse. |

### P0 - `GetDocumentByUniqueIdentifier`

Route: `GET /books/docs/getBy/unique_identifier/{unique_identifier}`

Meaning: retrieves a document by the idempotency/correlation key supplied at creation time.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `unique_identifier` | Yes | Dynamics invoice/order/document id used during create. |
| `brand_uuid` | Optional | Needed if multiple brands can share identifier spaces. |

Notes:
- This is critical for retry-safe flows. Before creating a document after an ambiguous failure, search by `unique_identifier` first.

### P1 - `SearchDocuments`

Route: `GET /books/docs/list`

Meaning: searches Invoice+ documents by multiple criteria.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `skip` | Optional | Paging start. |
| `take` | Conditional | Required if `skip` is specified. |
| `search` | Optional | Free-text search. |
| `more_info` | Optional | Dynamics reference. |
| `number` | Optional | Document number. |
| `transaction_uuid` | Optional | Linked PayPlus transaction. |
| `currency_code` | Optional | Currency filter. |
| `customer` | Optional | PayPlus customer UUID. |
| `fromDate` | Optional | Start date. |
| `toDate` | Optional | End date. |
| `dateType` | Optional | `doc_date` or `creation_date`. |
| `brand_uuid` | Optional | Brand filter. |
| `types` | Optional | Document type list. |
| `statuses` | Optional | `CLOSED`, `OPEN`, `CANCELLED`. |
| `minAmount` | Optional | Minimum amount. |
| `maxAmount` | Optional | Maximum amount. |
| `tags` | Optional | Tag filter. |
| `paymentTypes` | Optional | Payment method filters. |
| `external_id` | Optional | Search by transaction `more_info` / external id. |

### P1 - `GetDocumentByNumber`

Route: `GET /books/docs/getBy/number/{number}/{series}`

Meaning: retrieves a document by formal document number and series/prefix.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `number` | Yes | Numerical part of document number. |
| `series` | Yes | Alphabetical prefix/series if applicable. |

### P1 - `GetDocumentsByTransactionUid`

Route: `POST /Invoice/GetDocuments`

Meaning: fetches documents related to a PayPlus transaction. This belongs in both Transactions and Invoice+ because it connects payment to tax document output.

Recommended fields:

| Field | Required | Meaning / Dynamics mapping |
|---|---:|---|
| `transaction_uid` | Optional per docs, but practically important | PayPlus transaction UID. |
| `filter` | Yes | Filter object for returned documents. |

### P1 - `CreateDocumentPreview`

Route: `POST /books/docs/new/{docType}` with `preview=true`

Meaning: preview a document without issuing it.

Recommended fields:
- Same as `CreateDocument`, but set `preview=true`.

Notes:
- This can be a separate action for low-code clarity, or a parameter on `CreateDocument`.
- For Power Automate users, a separate action may reduce accidental final document creation.

### P1 - `CreateDraftDocument`

Route: `POST /books/docs/new/{docType}` with `draft=true`

Meaning: creates a draft document without final issuance.

Recommended fields:
- Same as `CreateDocument`, but set `draft=true`.

Notes:
- Same implementation route as `CreateDocument`; the decision is UX/API clarity rather than technical necessity.

## Invoice+ Expenses Actions

Expenses are accounting-related but are probably future scope unless the Dynamics solution is meant to manage supplier expenses too.

| Priority | Proposed action | Route | Meaning | Key fields |
|---|---|---|---|---|
| Future | `CreateExpense` | `POST /expenses` | Submit a new expense record/file. | `number`, `doc_date`, `subcategory_id`, `amount`, `amount_includes_vat`, `vat_percentage`, `description`, `currency_code`, `supplier_name`, `supplier_uid`, `doc_file`. |
| Future | `UpdateExpense` | `PUT /books/expenses/{uuid}` | Update expense record or file. | `uuid`, supplier fields, number/date/category/amount/VAT/description/currency/file, `delete_file`. |
| Future | `DeleteExpense` | `DELETE /books/expenses/{uuid}` | Delete expense record. | `uuid`. |
| Future | `GetExpense` | `GET /books/expenses/{uuid}` | Retrieve one expense record. | `uuid`. |
| Future | `SearchExpenses` | `GET /books/expenses` | Search expense records. | `skip`, `take`, `search`. |

## Invoice+ Reports / Misc

| Priority | Proposed action | Route | Meaning | Key fields |
|---|---|---|---|---|
| P2 | `CreateMovementsJournalJob` | `POST /delayed-jobs/create-new-job/movementsJournal` | Creates an async accounting movements report job. | Date range and report filters per PayPlus docs. |
| Future | `SendOtpSms` | `POST /otp/send` | Send one-time pin through SMS. | Recipient/OTP fields. |
| Future | `SendOtpEmail` | `POST /otp/send-forEmail` | Send one-time pin through email. | Recipient/OTP fields. |
| Future | `VerifyOtp` | `POST /otp/verify` | Validate OTP. | OTP verification fields. |

---

# Customer and Master Data Gaps

These are shared by both Transactions and Invoice+.

## Customers

The connector currently has only `CreateCustomer`. It should be expanded because both payment and invoice workflows need customer lifecycle support.

| Priority | Proposed action | Route | Meaning | Key fields |
|---|---|---|---|---|
| P0 | `UpdateCustomer` | `POST /Customers/Update/{uid}` | Update a PayPlus customer from Dynamics account/contact changes. | `uid`, `email`, `customer_name`, `paying_vat`, `vat_number`, `customer_number`, `notes`, `phone`, `contacts`, address fields, `subject_code`, `communication_email`. |
| P0 | `ViewCustomers` | `GET /Customers/View` | Search PayPlus customers. | `uuid`, `vat_number`, `email`, `skip`, `take`. |
| P1 | `RemoveCustomer` | `POST /Customers/Remove/{customer_uid}` | Remove/deactivate customer in PayPlus. | `customer_uid`. |

Recommended Dynamics mapping:
- Store PayPlus `customer_uid` on a mapping table keyed by Dynamics Account/Contact id.
- Use `vat_number`, `email`, and/or `customer_number` to avoid duplicate customers.
- Use `subject_code` only for a short numeric ERP/accounting subject code. Do not map a Dataverse GUID to `subject_code`; PayPlus rejects values longer than 15 digits.

## Banks / Bank Accounts

Relevant if recurring payments include MASAV/bank debit flows.

| Priority | Proposed action | Route | Meaning | Key fields |
|---|---|---|---|---|
| P2 | `AddCustomerBankAccount` | `POST /Banks/CreateCustomerBankAccount` | Add bank account for a customer. | Customer uid, bank/branch/account fields. |
| P2 | `UpdateCustomerBankAccount` | `POST /Banks/UpdateCustomerBankAccount/{uid}` | Update customer bank account. | Bank account uid and bank details. |
| P2 | `RemoveCustomerBankAccount` | `POST /Banks/RemoveCustomerBankAccount/{bank_account_uid}` | Remove customer bank account. | `bank_account_uid`. |
| P2 | `ViewCustomerBankAccounts` | `GET /Banks/CustomerBankAccounts/{customer_uid}` | List customer bank accounts. | `customer_uid`. |
| P2 | `GetCompanyBankAccounts` | `GET /Banks/CompanyBankAccounts` | List company bank accounts. | Optional filters per docs. |

## Products and Categories

Useful if Dynamics should sync item catalog data into PayPlus for consistent invoice lines.

| Priority | Proposed action | Route | Meaning | Key fields |
|---|---|---|---|---|
| P2 | `CreateProductCategory` | `POST /Categories/Add` | Create product category. | Category name/code/status fields. |
| P2 | `UpdateProductCategory` | `POST /Categories/Update/{uid}` | Update product category. | `uid`, category fields. |
| P2 | `ViewProductCategories` | `GET /Categories/View` | Search categories. | Search/paging fields. |
| P2 | `CreateProduct` | `POST /Products/Add` | Create product/service. | SKU/name/price/VAT/category fields. |
| P2 | `UpdateProduct` | `POST /Products/Update/{uid}` | Update product/service. | `uid`, product fields. |
| P2 | `ViewProducts` | `GET /Products/View` | Search products. | Search/paging fields. |

## Dictionary / Lookup Actions

These are helpful for setup screens and validation lists, not necessarily required as first connector actions.

| Priority | Proposed action | Route | Meaning |
|---|---|---|---|
| P1 | `GetCurrencies` | Dictionary route from docs | Currency choices for transactions/documents. |
| P1 | `GetBrands` | Dictionary route from docs | PayPlus brands for `brand_uuid`. |
| P1 | `GetMyTerminals` | Dictionary route from docs | Terminals for `terminal_uid`. |
| P1 | `GetMyCashier` | Dictionary route from docs | Cashier uid for transaction actions. |
| P2 | `GetBanks` | Dictionary route from docs | Israeli bank list. |
| P2 | `GetBranches` | Dictionary route from docs | Bank branches. |
| P2 | `GetTerminalTypes` | Dictionary route from docs | Terminal metadata. |
| P2 | `GetClearingCompanies` | Dictionary route from docs | Clearing company metadata. |
| P2 | `GetIssuerCompanies` | Dictionary route from docs | Issuer company metadata. |
| P2 | `GetAlternativeMethods` | Dictionary route from docs | Alternative payment methods. |
| P2 | `GetErrorCodes` | Dictionary route from docs | Error-code lookup for support messages. |

---

# Recommended Implementation Roadmap

## Phase 1 - Complete the Core Product

Add the minimum actions needed for a production-ready Dynamics payment and invoice flow:

1. `GetDocumentTypes`
2. `CreateDocument`
3. `GetDocument`
4. `GetDocumentByUniqueIdentifier`
5. `SearchDocuments`
6. `ViewTransactions`
7. `CancelTransaction`
8. `GetDocumentsByTransactionUid`
9. `UpdateCustomer`
10. `ViewCustomers`

## Phase 2 - Strengthen Payments

Add direct and operational payment actions:

1. `ChargeTransaction`
2. `ChargeByTransactionUid`
3. `ApprovalTransaction`
4. `RefundByCreditCard`
5. `DisablePaymentLinkRequest`
6. `GetPaymentPageIpnFull`
7. Transaction report actions

## Phase 3 - Recurring and Tokenization

Add only if the business requires recurring billing or saved-card flows:

1. Recurring update/delete/view/charge actions
2. Token add/check/view/list/update/remove actions
3. Bank account actions if MASAV/bank recurring is in scope

## Phase 4 - Invoice+ Advanced Accounting

Add supplier expense and accounting-reporting capabilities:

1. Expense create/update/delete/get/search
2. Movements journal report job
3. Additional dictionary actions

---

# Connector Split Recommendation

Recommendation: do not create two separate custom connectors at this stage.

Use one PayPlus connector per environment:

| Connector | Host | Purpose |
|---|---|---|
| PayPlus Production | `restapi.payplus.co.il` | Production API calls. |
| PayPlus Sandbox | `restapidev.payplus.co.il` | Staging/sandbox API calls. |

Reasoning:

1. Payments and Invoice+ share the same API version, base path, host model, and `api-key` / `secret-key` headers.
2. Many real workflows cross the boundary: payment creates invoice, refund creates credit document, transaction lookup retrieves documents.
3. Separate connectors would duplicate connection references, environment variables, Key Vault mapping, setup wizard logic, and solution dependencies.
4. Power Automate makers can still experience the connector as grouped actions using clear operation names and descriptions.

When to reconsider splitting:

1. If PayPlus confirms invoice-only customers use a different API product, credentials, permission model, or base host.
2. If licensing/support requires a separately installable `PayPlus Invoice+` package.
3. If the connector grows too large for makers and needs a simpler low-code UX.

Current best model:

| Layer | Recommendation |
|---|---|
| Custom connector | One PayPlus connector per environment. |
| Power Automate flows | Separate payment, invoice, tokenization, and generic sync-outbox flows. Every PayPlus connector call must branch between Sandbox and Production connection references. |
| Dataverse tables | Sync Profile, Entity Mapping, Field Mapping, Outbox, Sync State, Sync Log, plus dedicated transaction/document/card tables where the business workflow needs them. |
| Wizard | Capability mode: `Payments`, `Invoices only`, `Payments + Invoices`. |
| Validation | Payments: use a complete `GeneratePaymentLink` probe, not `PaymentPages/ChargeMethods`. Invoice-only: validate with an Invoice+ read/list action when credentials permit it. |
| Managed solution | Package the generic engine. Create customer-table plugin steps at runtime through `alex_ReconcilePayPlusSyncSteps`, based on active mappings. |

---

# Historical Egress Finding

Earlier tests appeared to show PayPlus-side blocking from Power Platform/Azure egress:

- Custom connector calls returned `502 BadGateway`.
- Raw Power Automate HTTP calls returned `403` with Cloudflare/Express headers and empty body.
- Direct tests showed valid and invalid keys receiving equivalent blocking behavior.

That diagnosis was superseded. The root issue was incomplete or unsupported PayPlus requests such as `PaymentPages/ChargeMethods`. Complete `GeneratePaymentLink` requests and Customer create/update calls through the custom connector have succeeded. The current operational risk is connector runtime cache: after changing OpenAPI schemas, Power Automate may continue to use stale connector metadata until the connector is republished in Maker Portal or the connection is recreated.
