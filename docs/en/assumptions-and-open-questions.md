# Assumptions

## Assumptions

- Power Platform custom connector creation and update permissions are available in the target environment.
- PayPlus sandbox and production credentials are issued by PayPlus through the customer's approved process.
- PayPlus payment pages and terminals are configured before production validation.
- The first production scenario uses hosted payment pages, not raw card entry.
- Dataverse is used only when the implementation needs tracking, audit, setup state, or write-back.
- Connector credentials are entered in the Power Platform connection dialog and are not committed to source control.

## API Schema Caution

Do not add or document unverified PayPlus fields as guaranteed behavior. When the official OpenAPI schema is missing or unclear, validate the field in PayPlus sandbox and record the result before exposing it to business users.
