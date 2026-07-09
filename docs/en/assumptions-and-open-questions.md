# Assumptions And Open Questions

## Assumptions

- Power Platform custom connector creation and update permissions are available in the target environment.
- PayPlus sandbox and production credentials are issued by PayPlus through the customer's approved process.
- PayPlus payment pages and terminals are configured before production validation.
- The first production scenario uses hosted payment pages, not raw card entry.
- Dataverse is used only when the implementation needs tracking, audit, setup state, or write-back.
- Connector credentials are entered in the Power Platform connection dialog and are not committed to source control.

## Open Questions

- Which Dynamics 365 app is the final system of record for payment requests: Sales, Customer Service, Finance, Business Central, or another Dataverse app?
- Which exact table should own the payment request: Account, Contact, Invoice, Order, Case, or a custom table?
- Will payment status be updated by webhook/IPN, scheduled polling, manual refresh, or a combination?
- Which PayPlus modules are enabled for the merchant account: payment pages, recurring payments, Invoice+, tokenization, products, or categories?
- Which PayPlus fields are mandatory for the customer's terminal and payment page configuration?
- Are payment links considered sensitive under the customer's internal classification policy?
- Are PayPlus token references allowed to be stored in Dataverse?
- What is the required retention period for payment event logs?
- What is the production owner for the connector connections and credential rotation?
- What DLP policy group should contain the PayPlus custom connector?

## API Schema Caution

Do not add or document unverified PayPlus fields as guaranteed behavior. When the official OpenAPI schema is missing or unclear, validate the field in PayPlus sandbox and record the result before exposing it to business users.
