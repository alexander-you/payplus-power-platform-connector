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

## Generate Payment Link

Purpose:

- Creates a PayPlus hosted payment page link for a business record.
- Writes `page_request_uid`, `payment_page_link`, status, and correlation data back to Dataverse.

Important controls:

- Do not collect raw card data.
- Do not store CVV.
- Use secure outputs if payment links or tokens are classified as sensitive.
- Use sandbox flows until production approval is complete.
