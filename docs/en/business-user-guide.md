# Business User Guide

## What Is A Payment Link

A payment link is a secure link to a PayPlus hosted payment page. The customer opens the link, enters card details on PayPlus, and completes the payment outside Dynamics 365 and outside Power Automate.

The business system may keep the payment request, amount, customer, payment link, PayPlus identifiers, and status. It must not keep the customer's card number or CVV.

## When To Use It

Use a payment link when a customer needs to pay remotely and the organization wants to track the request from Dynamics 365 or a Power Automate process.

Common examples:

- Service representative sends a payment request after a case or order.
- Collections team sends a link for an unpaid balance.
- Sales team sends a payment link for an order or deposit.
- Back office team creates a link from a controlled approval flow.

## Business Process

1. The user opens a Dynamics 365 record or starts an approved flow.
2. The user confirms the customer, amount, currency, payment page, and description.
3. The system creates a PayPlus payment link.
4. The link is saved on the payment request record.
5. The link is sent to the customer by email, SMS, chat, or another approved channel.
6. The customer pays on the PayPlus hosted page.
7. The system updates the request manually, by status retrieval, or by webhook if implemented.

## What The User Needs To Fill In

The exact form depends on the implementation, but the user normally supplies or confirms:

| Field | Meaning |
| --- | --- |
| Customer | The person or account expected to pay |
| Amount | The amount to collect |
| Currency | Usually ILS, unless another currency is approved |
| Payment page | The PayPlus page used for this payment scenario |
| Terminal | The PayPlus terminal, if shown by the form |
| Description or reference | Business reason, invoice, order, or case reference |
| Contact details | Email or phone if the link will be sent automatically |

## What The Customer Receives

The customer receives a link to a PayPlus payment page. The page is hosted by PayPlus and is the place where the customer enters payment card details.

The link should be sent only through approved communication channels.

## What Happens After Payment

Depending on the implementation, the system can store:

- PayPlus payment request UID.
- Payment link.
- Transaction UID.
- Payment status.
- Paid amount and currency.
- Payment date.
- Approval or voucher reference.
- Last four card digits if returned by PayPlus and approved for storage.
- Error or failure reason.

The system should not store raw card number, CVV, or full magnetic/card data.

## Expected Statuses

Recommended business statuses:

| Status | Meaning |
| --- | --- |
| Draft | The payment request was prepared but no link was created yet |
| Link Created | PayPlus returned a payment link |
| Sent | The link was sent to the customer |
| Paid | Payment completed successfully |
| Failed | Payment attempt failed or was rejected |
| Expired | Link is no longer valid |
| Cancelled | Request was cancelled by the organization |
| Refunded | Payment was refunded fully or partially |
| Pending Review | Manual support or reconciliation is required |

## What To Do If Something Fails

- Check that the customer details and amount are correct.
- Check that the payment page and terminal are correct.
- Try creating a new link only if business policy allows it.
- Do not ask the customer to send card details by email, chat, phone transcript, or free text.
- Escalate to the support or finance owner if the status is unclear.
- If a customer says they paid but Dynamics does not show it, ask support to check the PayPlus transaction status or webhook log.

## What Not To Do

- Do not type card numbers into Dynamics 365, notes, email fields, Flow inputs, or Dataverse records.
- Do not store CVV anywhere.
- Do not paste API keys or secret keys into records, comments, emails, or flow action inputs.
- Do not reuse a link for a different customer or amount.
- Do not use production links for testing.
- Do not mark a request as paid unless the payment status is confirmed.

## Terminal And Payment Page Explained

A terminal is the PayPlus merchant clearing context used for payment operations. A payment page is the customer-facing page that belongs to a terminal and defines how the payment experience behaves.

In simple terms:

- Terminal: where the payment is processed.
- Payment page: what the customer opens to pay.

An organization can have **many** terminals, and each terminal can have **many** payment pages. During setup an administrator imports all terminals and their payment pages from PayPlus into Dynamics 365, and then picks one **default terminal** and one **default payment page** that runtime processes fall back to when a specific one is not provided. Normal users may only see friendly names.

## Setup Wizard (Administrator)

An administrator completes a four-step setup wizard:

1. **Connect** — enter and validate the PayPlus connection.
2. **Terminals & pages** — fetch all terminals and their payment pages from PayPlus, preview them, and import them. Import creates a record for each terminal and payment page.
3. **Validate** — pick the default terminal and its default payment page, run a quick connection smoke-test (a sample hosted payment link), and then a mandatory import of document types. The installation cannot complete until document types are imported successfully.
4. **Done** — the management center, including an on-demand connection test for each individual payment page.

A single default terminal per environment and a single default page per terminal and process type are enforced automatically, so choosing a new default clears the previous one.

## Why Card Details Are Not Entered In Dynamics Or Flow

Dynamics 365 and Power Automate are business process systems. They are not used here as card entry screens. Asking users to enter card numbers or CVV into them would increase security and PCI risk and could expose data in run history, logs, exports, or notes.

PayPlus provides the hosted payment page so card details stay on the PayPlus side.
