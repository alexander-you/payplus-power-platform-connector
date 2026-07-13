# Power Automate Flow Patterns

This folder documents recommended flow patterns. Tenant-specific flow JSON exports can contain environment IDs, connection reference IDs, or other implementation-specific values, so reusable templates should be sanitized before committing.

## Validate PayPlus Connection

Purpose:

- Triggered by setup or admin validation.
- Calls `GeneratePaymentLink` with a minimal complete sandbox or production request.
- Stores validation status, code, message, and timestamp in Dataverse.

Important controls:

- Use the custom connector, not raw HTTP, for connector validation.
- Use connection references for sandbox and production.
- Set retry policy to fail fast during validation.
- Store sanitized errors only.

## Fetch PayPlus Options

Purpose:

- Retrieves terminals through `MyTerminals`.
- Retrieves payment pages through `ListPaymentPages` for a selected terminal.
- Supports setup wizard or admin configuration screens.

Important controls:

- Do not store API keys in Dataverse.
- Store only terminal and payment page metadata.
- Handle empty lists and invalid terminal responses.

## Import Terminals & Pages

Purpose:

- Named `PayPlus - Import Terminals & Pages`.
- Reads the PayPlus terminals (`MyTerminals`) and their payment pages (`ListPaymentPages`) through the connector.
- Upserts rows into the `alex_payplus_terminal` and `alex_payplus_paymentpage` Dataverse tables, keyed by environment + UID.
- New records get `alex_isdefault = false` initially; the default is chosen later in the setup wizard's Validate step.
- Runs during setup (Terminals & pages step) and can be re-run to refresh the catalog.

Important controls:

- Upsert by (environment + UID); do not overwrite business/policy fields on re-import.
- Link each payment page to its owning terminal (`alex_terminalid`).
- Two plugins keep defaults consistent: `EnforceSingleDefaultTerminal` (one default terminal per environment) and `EnforceSingleDefaultPage` (one default page per terminal + process type).

## Import Document Types

Purpose:

- Imports PayPlus document types into Dataverse. Runs as a mandatory, blocking step at the end of setup validation.

Important controls:

- Power Automate has no `filter()` expression function; use a **Filter array (Query)** action to filter arrays. An earlier version of this flow used an invalid inline `filter()` expression and was fixed to use a Filter array action.

## Generate Payment Link

Purpose:

- Creates a PayPlus hosted payment page link for a business record.
- Writes `page_request_uid`, `payment_page_link`, status, and correlation data back to Dataverse.

Important controls:

- Do not collect raw card data.
- Do not store CVV.
- Use secure outputs if payment links or tokens are classified as sensitive.
- Use sandbox flows until production approval is complete.
