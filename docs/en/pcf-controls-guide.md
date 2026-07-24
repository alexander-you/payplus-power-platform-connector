# PCF Controls Guide — Binding, Fields, Tables, and Standalone Use

> Hebrew version: [../he/pcf-controls-guide.md](../he/pcf-controls-guide.md)

This guide explains **how to add each PayPlus PCF control to a form or page, which properties to bind, which tables it works against, and what happens when a control is used on its own** — most importantly, how the Payment Wizard collects a payment even when there is **no Dynamics 365 Sales invoice**.

All controls live in the `PayPlus` namespace and are shipped in the **base solution** (`alex_d365_payplus`). They do **not** require Dynamics 365 Sales. The Sales-specific placement (on quote/order/invoice forms) is delivered by the separate extension solution — see [integration-guide.md](integration-guide.md#the-two-solutions-and-their-dependencies).

## The Five Controls at a Glance

| Control | Constructor | Type | How it binds | Works against |
| --- | --- | --- | --- | --- |
| Mapping Studio | `PayPlus.MappingStudio` | Field (bound) | `hostValue` text column | Sync profile (`alex_payplus_syncprofile`) + any source/target |
| Credit Card Wallet | `PayPlus.CreditCardWallet` | Dataset | Card subgrid | `alex_creditcard` on Account/Contact |
| Bank Account Wallet | `PayPlus.BankAccountWallet` | Dataset | Bank-account subgrid | Customer bank accounts + `alex_bank`/`alex_bankbranch` |
| Payment Wizard | `PayPlus.PaymentWizard` | Field (bound) + inputs | `hostValue` + `sourceEntity`/`sourceId` | `alex_payplusbillingcase` (any source table, or standalone) |
| Document Ledger | `PayPlus.DocumentLedger` | Field (bound) + inputs | `hostValue` + `scope`/`recordId`/`entityLogicalName` | `alex_payplusdocument` |
| Document Preview | `PayPlus.DocumentPreview` | Field (bound) + input | `hostValue` + `documentId` | A single `alex_payplusdocument` |

Two binding styles are used:

- **Dataset controls** (Credit Card Wallet, Bank Account Wallet) replace a **subgrid**. You add a subgrid of the target table to a form and switch its control to the PayPlus control. The control reads the parent record from the page context.
- **Field-bound controls** (all the others) bind their required `hostValue` property to a **single-line text column**. This is a standard PCF pattern: the bound column is only an anchor — the control does its real work through the Web API and its **input properties**. On a **custom page** (where there is no form field), you drive the control entirely through the input properties instead.

## Mapping Studio

**Purpose.** Visual field mapping between a Dynamics source table and a PayPlus target, plus turning continuous sync on and off.

**Where to place it.** On the **Sync Profile** form (`alex_payplus_syncprofile`).

| Property | Usage | Type | Required | Bind to |
| --- | --- | --- | --- | --- |
| `hostValue` | bound | Single line text | Yes | A text column on the sync profile (e.g. the mapping-state column) |

**Tables it touches.** Reads Dynamics table/column metadata for the chosen source and PayPlus target; writes the mapping and sync settings back to the sync-profile and transform-rule tables. Uses the model-driven form save.

**Standalone note.** It is an administration control; it always runs in the context of one sync profile record. It has no meaningful "no-Sales" variation because it is source-table-agnostic by design — you point it at whatever table you want to sync.

## Credit Card Wallet

**Purpose.** Show the tokenized PayPlus cards of a customer as an Apple-style wallet, with 3D flip, activate/deactivate, default-card handling, and shortcuts to capture a new card.

**Where to place it.** On an **Account** or **Contact** form, as the control for a **subgrid of `alex_creditcard`**.

| Property | Usage | Binds to |
| --- | --- | --- |
| `wallet` (dataset) | dataset | The `alex_creditcard` subgrid; parent is read from the page context |

**Tables it touches.** `alex_creditcard` (related to the parent account/contact). It can also trigger card capture (hosted fields) and self-service collection sessions (`alex_pp_hfsession`).

**Standalone note.** Works on any table that owns cards. It never needs Sales — cards belong to accounts/contacts, not to invoices.

## Bank Account Wallet

**Purpose.** Show a customer's bank accounts as an Apple-style wallet with bank logos, and add new accounts through bank + branch pickers (including standing-order details).

**Where to place it.** On an **Account** or **Contact** form, as the control for a **subgrid of the customer bank-account table**.

| Property | Usage | Binds to |
| --- | --- | --- |
| `accounts` (dataset) | dataset | The bank-account subgrid; parent is read from the page context |

**Tables it touches.** The customer bank-account table plus the `alex_bank` and `alex_bankbranch` reference tables (populated by the *Import Banks & Branches* flow).

**Standalone note.** Independent of Sales; it is customer master-data, not order data.

## Payment Wizard — including use **without** a Sales invoice

**Purpose.** A guided wizard that collects a payment and issues the accounting outcome (receipt / tax-invoice-receipt), handling full or partial payment, hosted fields or a saved token, payment lines, and receipt allocations.

**Where to place it.**
- On a **Dynamics 365 Sales** form (quote, order, invoice) — delivered by the extension solution; or
- On **any custom table's** form; or
- On a **custom page** (no form context) — for example a collections app that has no Sales at all.

| Property | Usage | Type | Required | Purpose |
| --- | --- | --- | --- | --- |
| `hostValue` | bound | Single line text | Yes | Anchor column on the host form (any text column) |
| `sourceEntity` | input | Single line text | No | Logical name of the record the payment is *for* |
| `sourceId` | input | Single line text | No | Id of that record |

**How it decides what to charge.** The wizard is built around a **billing case** (`alex_payplusbillingcase`), not around an invoice:

1. It resolves the source as `sourceEntity` / `sourceId` **if you supply them**, otherwise it reads the current **form or page context** automatically.
2. It finds (or creates) the billing case whose `alex_sourceentitylogicalname` + `alex_sourceentityid` match that source.
3. It loads the case's **payment lines** (`alex_paypluspaymentline`) and **receipt allocations** (`alex_payplusreceiptallocation`) to compute what is still owed.
4. **Only if** the source happens to be a Sales `invoice` does it additionally pull the invoice's own lines (`invoicedetail`). For every other source, the **billing case is the sole anchor** — no Sales record is required.

> **This is the answer to "what if there is no Sales invoice?"** The Payment Wizard never depends on `invoice`. Give it any `sourceEntity`/`sourceId` (a membership, a tuition record, a case, a custom order), or drop it on a custom page, and it collects against a billing case just the same. The Sales invoice is one optional source among many.

**Tables it touches.** `alex_payplusbillingcase`, `alex_paypluspaymentline`, `alex_payplusreceiptallocation`, `alex_payplusdocument` (issued receipts/invoices), and PayPlus hosted-payment endpoints. On a Sales source it also reads `invoice` / `invoicedetail`.

**External services.** The control calls PayPlus hosted-payment domains directly (it is a premium control).

## Document Ledger

**Purpose.** An accounting-aware ledger for a customer or record: total charges, total credits, final balance, and search across issued documents.

**Where to place it.** On an **Invoice**, **Account**, or **Contact** form, or on a **custom page**.

| Property | Usage | Required | Purpose |
| --- | --- | --- | --- |
| `hostValue` | bound | Yes | Anchor text column on the host form |
| `scope` | input | No | Which set of documents to show (e.g. one record vs. the whole customer) |
| `recordId` | input | No | The record to scope to (use on custom pages) |
| `entityLogicalName` | input | No | Logical name of that record (use on custom pages) |

**Tables it touches.** `alex_payplusdocument` (filtered by scope / record / customer).

**Standalone note.** On a form it reads the current record automatically; on a custom page you pass `recordId` + `entityLogicalName` explicitly. No Sales dependency.

## Document Preview

**Purpose.** Render a preview of a single PayPlus (Invoice+) document.

**Where to place it.** On the **`alex_payplusdocument`** form, or on a **custom page** where you already know the document id.

| Property | Usage | Required | Purpose |
| --- | --- | --- | --- |
| `hostValue` | bound | Yes | Anchor text column |
| `documentId` | input | No | The `alex_payplusdocument` to preview (use on custom pages) |

**Tables it touches.** A single `alex_payplusdocument`. Calls PayPlus preview endpoints (premium control).

## Placement Cheatsheet

| I want to… | Use | Put it on |
| --- | --- | --- |
| Configure & activate sync | Mapping Studio | Sync Profile form |
| Show/manage saved cards | Credit Card Wallet | Account/Contact card subgrid |
| Show/add bank accounts | Bank Account Wallet | Account/Contact bank-account subgrid |
| Collect a payment (any source) | Payment Wizard | Any form, or a custom page |
| Show a balance & documents | Document Ledger | Invoice/Account/Contact form, or custom page |
| Preview one document | Document Preview | Document form, or custom page |

## Related Documents

- [architecture.md](architecture.md) — where the controls sit in the overall solution
- [integration-guide.md](integration-guide.md) — building processes with or without Sales, and the two-solution model
- [data-model.md](data-model.md) — the tables these controls read and write
