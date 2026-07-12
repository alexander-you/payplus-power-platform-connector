# PayPlus Invoice+ Connector Actions

Date: 2026-07-11  
Scope: actions that should exist in the PayPlus custom connector for invoices, receipts, quotes, proforma documents, credit documents, delivery documents, and invoice-only customers.

Primary API reviewed: `POST /api/v1.0/books/docs/new/{docType}` - Create new document.

## Summary

PayPlus Invoice+ uses one central creation endpoint for many accounting document types:

```http
POST /api/v1.0/books/docs/new/{docType}
```

The `docType` path parameter decides whether the document is a tax invoice, receipt, tax invoice/receipt, quote, proforma invoice, credit/refund document, delivery certificate, payment request, and so on.

For the connector, there are two good implementation options:

| Option | Recommendation | Reason |
|---|---|---|
| One generic `CreateDocument` action with `docType` input | Required | Covers the full PayPlus API and future document types. |
| Separate friendly actions per common document type | Recommended | Easier for Power Automate makers: `CreateQuote`, `CreateTaxInvoiceReceipt`, etc. Each action can call the same API route with a fixed `docType`. |

My recommendation: implement both. Add one generic `CreateDocument` action for complete API coverage, and add friendly wrapper actions for the common business documents.

## Shared Create Document Input Model

These fields are relevant to all create-document actions that call `POST /books/docs/new/{docType}`.

| Input field | Required | Meaning |
|---|---:|---|
| `docType` | Yes for generic action | PayPlus document type, such as `inv_tax_receipt`, `inv_tax`, `dc_quote`. In friendly actions this should be fixed by the action. |
| `doc_date` | Optional | Document issue date in `YYYY-MM-DD`. If omitted, PayPlus uses current date. |
| `brand_uuid` | Optional | Brand/business identity in PayPlus, if the account has multiple brands. |
| `preview` | Optional | If `true`, PayPlus returns a preview and does not issue a real document. |
| `draft` | Optional | If `true`, creates a draft rather than a final issued document. |
| `hide_base_currency` | Optional | Hide base currency on foreign-currency documents. Usually relevant when document currency is not ILS. |
| `more_info` | Optional | Free reference that appears on the document. Use for Dynamics record number/reference. |
| `unique_identifier` | Strongly recommended | Idempotency/correlation key. Use Dynamics invoice/quote/order id to prevent duplicate documents. |
| `close_doc` | Optional | UUID of an existing document to close with the new document. Useful when converting payment request/proforma to final document. |
| `cancel_doc` | Optional | UUID of an existing document to cancel with the new document. |
| `transaction_uuid` | Optional | PayPlus transaction UUID to link the document to a payment. |
| `send_document_email` | Optional | Send document email after creation. |
| `send_document_sms` | Optional | Send document SMS after creation. |
| `callback_url` | Optional | URL PayPlus calls after successful document creation. |
| `vatType` | Optional | `vat-type-included`, `vat-type-not-included`, or `vat-type-exempt`. |
| `vat_percentage` | Optional | VAT percentage override. If omitted, PayPlus account settings are used. |
| `language` | Optional | `he` or `en`. |
| `currency_code` | Optional | Document currency, usually `ILS`. |
| `conversion_rate` | Conditional | Conversion rate for non-ILS documents if not using automatic calculation. |
| `autocalculate_rate` | Optional | Ask PayPlus to determine conversion rate automatically. |
| `prevent_email` | Optional | Prevent email sending even if account defaults normally send. |
| `customer` | Usually required | Customer object: name, VAT number/id, email, phone, address fields. |
| `tags` | Optional | List of tags for search/reporting. Useful for Dynamics source labels. |
| `payments` | Conditional | Payment rows for receipt/payment documents. Required when the document represents payment received. |
| `totalAmount` | Conditional | Total document amount. Useful as a validation/control field. |
| `items` | Usually required | Document line items: description/product, quantity, price, VAT behavior. |

## Shared Create Document Output Model

PayPlus docs show a `200` response for successful document creation. The exact response object should be treated as PayPlus-owned and should be stored as raw JSON in addition to mapped columns.

For Dynamics, every create-document action should expose/map at least these output concepts when present:

| Output field / concept | Meaning |
|---|---|
| `success` / `status` / `code` | Whether PayPlus accepted and created/previewed the document. |
| `description` / `message` | Human-readable PayPlus response text. |
| `document_uuid` / `uuid` | PayPlus document UUID. Store this on the Dataverse document log. |
| `document_number` / `number` | Formal document number. Needed for finance users and reconciliation. |
| `series` | Document series/prefix, used by get-by-number API. |
| `docType` / `type` | Type of created document. |
| `status` | Document lifecycle status, such as open/closed/cancelled, when returned. |
| `pdf_url` / document link | Link/file reference if PayPlus returns one. |
| `raw_response` | Full PayPlus JSON response, stored for support and future mapping. |

## Recommended Connector Actions

| Priority | Action name in connector | PayPlus API name / route | Essence | Input - what user/flow sends | Output - what flow receives |
|---|---|---|---|---|---|
| P0 | `CreateDocument` | `POST /books/docs/new/{docType}` | Generic Invoice+ document creation for every supported `docType`. This is the core API action. | Headers `api-key`, `secret-key`; path `docType`; body with `doc_date`, `brand_uuid`, `preview`, `draft`, `more_info`, `unique_identifier`, `customer`, `items`, `payments`, `totalAmount`, VAT/currency/email/callback fields. | PayPlus result/status, document UUID, document number/series/type/status when returned, document link/PDF when returned, raw response. |
| P0 | `CreateTaxInvoiceReceipt` | `POST /books/docs/new/inv_tax_receipt` | Creates a tax invoice/receipt. Common for immediate payment where invoice and receipt are one document. | Same body as `CreateDocument`, but `docType` is fixed to `inv_tax_receipt`. Usually requires `customer`, `items`, and `payments`. Use `unique_identifier` from Dynamics invoice/payment id. | Created tax invoice/receipt identifiers: UUID, number, series, status/link when returned, raw response. |
| P0 | `CreateTaxInvoice` | `POST /books/docs/new/inv_tax` | Creates a tax invoice without necessarily recording receipt/payment. Useful for invoice-before-payment scenarios. | Same body model, fixed `docType=inv_tax`. Usually requires `customer` and `items`; `payments` may be omitted depending on business process. | Created invoice UUID, invoice number, series, status/link when returned, raw response. |
| P0 | `CreateReceipt` | `POST /books/docs/new/inv_receipt` | Creates a receipt for payment received. Useful when invoice exists separately or payment is recorded independently. | Same body model, fixed `docType=inv_receipt`. Usually requires `customer` and `payments`; `items` may depend on PayPlus/account rules. | Created receipt UUID, receipt number, series, status/link when returned, raw response. |
| P0 | `CreateQuote` | `POST /books/docs/new/dc_quote` | Creates a quote/proposal document. Relevant to CRM quote flow before sale/payment. | Same body model, fixed `docType=dc_quote`. Usually requires `customer`, `items`, currency/VAT, optional `valid-until` only if PayPlus supports it in body/account model, `unique_identifier` from Dynamics Quote id. | Created quote UUID, quote number, series/status/link when returned, raw response. |
| P0 | `CreateProformaInvoice` | `POST /books/docs/new/inv_proforma` | Creates a proforma invoice. Useful for demand/proforma before final tax invoice. | Same body model, fixed `docType=inv_proforma`. Usually requires `customer`, `items`, `totalAmount`, VAT/currency fields, `unique_identifier`. | Created proforma UUID, number, series/status/link when returned, raw response. |
| P0 | `CreatePaymentRequest` | `POST /books/docs/new/inv_pay_request` | Creates a payment request document. Useful for invoice-only or pay-later process without hosted payment page. | Same body model, fixed `docType=inv_pay_request`. Usually requires `customer`, `items`, amount/currency/VAT, optional email/SMS flags. | Created payment request UUID, number, series/status/link when returned, raw response. |
| P1 | `CreateCreditDocument` | `POST /books/docs/new/inv_refund` | Creates refund/credit document. Used for accounting credit, cancellation, or refund documentation. | Same body model, fixed `docType=inv_refund`. Usually includes `customer`, credited `items`, amount, optional `cancel_doc` or `transaction_uuid`, `unique_identifier`. | Created credit document UUID, number, series/status/link when returned, raw response. |
| P1 | `CreateDeliveryCertificate` | `POST /books/docs/new/crt_delivery` | Creates delivery/shipping certificate. Useful for goods shipment before invoice. | Same body model, fixed `docType=crt_delivery`. Usually requires `customer`, delivery items, optional tags/more_info. | Created delivery certificate UUID, number, series/status/link when returned, raw response. |
| P1 | `CreateReturnCertificate` | `POST /books/docs/new/crt_return` | Creates return certificate for returned goods. | Same body model, fixed `docType=crt_return`. Usually requires `customer`, returned items, optional `cancel_doc`/`more_info`. | Created return certificate UUID, number, series/status/link when returned, raw response. |
| P2 | `CreateDonationReceipt` | `POST /books/docs/new/inv_don_receipt` | Creates donation receipt, only if nonprofit/donation process is in scope. | Same body model, fixed `docType=inv_don_receipt`. Requires customer/donor and donation amount/items according to PayPlus account rules. | Created donation receipt UUID, number, series/status/link when returned, raw response. |
| P2 | `CreatePurchaseOrderCertificate` | `POST /books/docs/new/order_purchase` | Creates purchase order certificate. More relevant if purchasing/procurement is managed via PayPlus. | Same body model, fixed `docType=order_purchase`; supplier/customer and items as PayPlus expects. | Created purchase order certificate UUID, number, series/status/link when returned, raw response. |
| P2 | `CreatePurchaseCertificate` | `POST /books/docs/new/purchase` | Creates purchase certificate. Future scope unless supplier-side accounting is needed. | Same body model, fixed `docType=purchase`; supplier/customer and items as PayPlus expects. | Created purchase certificate UUID, number, series/status/link when returned, raw response. |
| P0 | `GetDocumentTypes` | `GET /books/doc_types` | Returns available PayPlus document types. Also the best lightweight validation action for invoice-only customers. | Query `language_code` optional, e.g. `he`; headers `api-key`, `secret-key`. | List of document types and labels/metadata returned by PayPlus. |
| P0 | `GetDocument` | `GET /books/docs/get/{uuid}` | Retrieves a document by PayPlus document UUID. | Path `uuid`; headers. | Full document data for that UUID, including status/number/customer/items/payments/link if returned. |
| P0 | `GetDocumentByUniqueIdentifier` | `GET /books/docs/getBy/unique_identifier/{unique_identifier}` | Retrieves document by the idempotency key used at creation. Critical for retry-safe Dynamics flows. | Path `unique_identifier`; optional query `brand_uuid`; headers. | Matching document data if found. Use to detect duplicates after timeout/ambiguous failure. |
| P1 | `SearchDocuments` | `GET /books/docs/list` | Searches documents for reconciliation, support, and sync jobs. | Query fields: `skip`, `take`, `search`, `more_info`, `number`, `transaction_uuid`, `currency_code`, `paypal_transaction_id`, `customer`, `fromDate`, `toDate`, `dateType`, `brand_uuid`, `types`, `statuses`, `minAmount`, `maxAmount`, `tags`, `paymentTypes`, `external_id`; headers. | List/page of documents matching filters, including document metadata and totals/status when returned. |
| P1 | `GetDocumentByNumber` | `GET /books/docs/getBy/number/{number}/{series}` | Retrieves formal document by number and series/prefix. Useful for finance users who search by printed document number. | Path `number`, path `series`; headers. | Matching document data. |
| P1 | `CreateDocumentPreview` | `POST /books/docs/new/{docType}` with `preview=true` | Produces a preview without issuing a real document. Useful before final posting. | Same as `CreateDocument`, but `preview=true`. Can be generic or per doc type. | Preview response/document preview data; no final document should be generated. |
| P1 | `CreateDraftDocument` | `POST /books/docs/new/{docType}` with `draft=true` | Creates draft document for approval flow before final issuing. | Same as `CreateDocument`, but `draft=true`. | Draft document response, draft UUID/status if returned. |
| P1 | `CancelDocumentWithNewDocument` | `POST /books/docs/new/{docType}` with `cancel_doc` | Creates a document that cancels a previous document. Best represented as a guided action to avoid misuse. | `docType` for the cancelling/credit document, `cancel_doc` previous PayPlus document UUID, customer/items/amount as needed, `unique_identifier`. | New cancellation/credit document data and raw PayPlus response. |
| P1 | `CloseDocumentWithNewDocument` | `POST /books/docs/new/{docType}` with `close_doc` | Creates a document that closes another document, e.g. close proforma/payment request with final invoice/receipt. | `docType`, `close_doc` previous document UUID, customer/items/payments as needed, `unique_identifier`. | New closing document data and raw PayPlus response. |
| P1 | `GetDocumentsByTransactionUid` | `POST /Invoice/GetDocuments` | Retrieves documents linked to a PayPlus payment transaction. This bridges clearing and accounting. | Body `transaction_uid`, `filter`; headers. | Documents associated with the transaction. Useful after payment/refund to sync tax documents back to Dynamics. |

## Recommended Minimal Set for First Invoice+ Connector Release

If we want the first version to stay focused and still support real invoice/quote work, include these first:

| Order | Action | Why |
|---:|---|---|
| 1 | `GetDocumentTypes` | Validates invoice-only credentials and confirms available document types. |
| 2 | `CreateDocument` | Full generic coverage for all PayPlus document types. |
| 3 | `CreateTaxInvoiceReceipt` | Most common paid invoice document. |
| 4 | `CreateTaxInvoice` | Common invoice-before-payment flow. |
| 5 | `CreateReceipt` | Payment received without combined tax invoice/receipt. |
| 6 | `CreateQuote` | CRM quote/proposal flow. |
| 7 | `CreateProformaInvoice` | Proforma-before-final-document flow. |
| 8 | `CreateCreditDocument` | Credit/refund/cancellation accounting flow. |
| 9 | `GetDocument` | Retrieve by stored UUID. |
| 10 | `GetDocumentByUniqueIdentifier` | Retry/idempotency protection. |
| 11 | `SearchDocuments` | Reconciliation and support. |

## Suggested Dataverse Mapping

Every create action should write a row to a PayPlus document log table.

| Dataverse field | Source / meaning |
|---|---|
| `alex_sourceentitylogicalname` | Source table, e.g. quote, invoice, salesorder. |
| `alex_sourceentityid` | Source row id. |
| `alex_uniqueidentifier` | Value sent to PayPlus `unique_identifier`. |
| `alex_payplusdocumentuuid` | PayPlus returned document UUID. |
| `alex_documenttype` | PayPlus `docType`. |
| `alex_documentnumber` | Returned formal document number. |
| `alex_series` | Returned series/prefix. |
| `alex_status` | PayPlus document status. |
| `alex_totalamount` | Total amount sent/returned. |
| `alex_currencycode` | Currency. |
| `alex_customeruid` | PayPlus customer UUID if used/returned. |
| `alex_transactionuuid` | Linked PayPlus transaction UUID, if any. |
| `alex_documenturl` | PDF/document link if returned. |
| `alex_rawrequest` | Request JSON, excluding secrets. |
| `alex_rawresponse` | Full PayPlus response JSON. |
| `alex_lastsyncstatus` | Success/failed/pending. |
| `alex_lastsyncmessage` | Error/support message. |

## Notes for Connector Design

1. The headers remain the same as the current connector model: `api-key` and `secret-key` as explicit operation parameters.
2. For invoice-only setup validation, use `GetDocumentTypes`, not `PaymentPages/ChargeMethods`.
3. `unique_identifier` should be mandatory in our connector actions even if PayPlus marks it optional. It protects Dynamics from duplicate documents.
4. The connector should expose `raw_response` because PayPlus response fields may vary by `docType`, preview, draft, and account settings.
5. For Power Automate maker UX, friendly actions are better than requiring every maker to know `dc_quote`, `inv_tax_receipt`, etc.
