# Test Plan

## Purpose

This test plan validates the PayPlus custom connector, Power Automate flows, optional Dataverse model, and production readiness controls.

## Test Environments

| Environment | Purpose |
| --- | --- |
| Development | Connector import, schema changes, unit-style validation |
| Sandbox | PayPlus sandbox runtime validation |
| Test/UAT | Business user validation and security checks |
| Production | Controlled smoke test after approval |

## Unit Tests

Unit tests are limited because this is primarily a low-code connector solution. Where custom code exists, test:

- Web resource JavaScript utility functions.
- Dataverse mapping functions.
- Payload builders.
- Status mapping helpers.
- Webhook signature validation if implemented in code.

## Connector Tests

- Validate `apiDefinition.*.json` is valid JSON.
- Validate `apiProperties.json` is valid JSON.
- Import or update the sandbox connector.
- Confirm `apiKey` and `secretKey` are connection parameters of type `securestring`.
- Confirm `setheader` policies exist for `api-key` and `secret-key`.
- Confirm no action exposes `api-key` or `secret-key` as normal action parameters.
- Confirm no action accepts raw PAN or CVV in first-phase operation schemas.
- Confirm operation IDs and display names are stable.

## Connection Tests

- Create a sandbox connection with PayPlus sandbox credentials.
- Verify the connection can run `MyTerminals`.
- Verify the connection can run `ListPaymentPages` with a valid `terminal_uid`.
- Verify the connection can run `GeneratePaymentLink` with a complete sandbox body.
- Recreate or rebind connection references and confirm flows use the expected connection.
- Confirm secure connection parameter values are not readable from normal APIs.

## Runtime Tests

- Generate a payment link with valid amount, currency, terminal, payment page, customer, and item.
- Store returned `page_request_uid` and `payment_page_link`.
- Open the link and confirm it reaches the PayPlus hosted page.
- Complete sandbox payment if test cards are available and approved.
- Retrieve or receive payment status if the implementation includes status retrieval or webhook.
- Confirm Dataverse status transitions.

## Negative Tests

| Scenario | Expected Result |
| --- | --- |
| Invalid key | PayPlus rejects the request; no payment request marked paid |
| Missing secret | Connector call fails; error is sanitized |
| Invalid terminal | `ListPaymentPages` or payment action fails with controlled message |
| Invalid payment page | Generate link fails or returns PayPlus error |
| Missing amount | Flow validation or PayPlus validation fails |
| Zero or negative amount | Request rejected before or by PayPlus |
| Invalid currency | Request rejected or mapped to supported values only |
| Sandbox key against production host | Rejected |
| Production key against sandbox host | Rejected |
| Unknown endpoint | Error handled without retry storm |

## Security Tests

- Verify API keys are not visible in action inputs.
- Verify keys are not stored in Dataverse tables.
- Verify keys are not stored in String Environment Variables.
- Verify secure inputs and outputs are enabled where sensitive values are handled.
- Verify run history does not contain PAN or CVV.
- Verify DLP policy allows only approved connectors.
- Verify production flows are owned by approved service owners.
- Verify users without payment permissions cannot create or send payment links.

## Run History Tests

Inspect a sandbox flow run and confirm:

- No raw card number appears.
- No CVV appears.
- No `api-key` value appears.
- No `secret-key` value appears.
- Tokens, if used, are masked or protected by secure inputs/outputs.
- Error payloads are sanitized before Dataverse storage.

## Dev And Prod Validation

Development:

- Use sandbox connector and sandbox PayPlus credentials.
- Use test customers and test payment pages.
- Do not use production credentials.

Production:

- Use production connector and production PayPlus credentials.
- Run a controlled smoke test after approvals.
- Confirm connection references bind to production connections.
- Confirm monitoring and incident response are active.

## PayPlus Sandbox Validation

- Confirm sandbox host: `restapidev.payplus.co.il`.
- Confirm base path: `/api/v1.0`.
- Confirm `GeneratePaymentLink` returns a hosted sandbox link with a complete body.
- Confirm test data appears in PayPlus sandbox as expected.

## 403 / 502 / WAF Scenarios

- 403 with structured JSON may indicate invalid credentials or invalid request context.
- 403 with empty body may occur for incomplete or unsupported endpoints.
- 502 from the connector can be a connector-wrapped upstream failure; inspect the actual operation and request completeness.
- Do not assume all 403 or 502 responses are WAF issues. Validate endpoint, method, required body, environment, and credentials.
- Capture Cloudflare or gateway correlation headers only when they do not expose secrets.

## Hebrew And English Data Validation

- Test Hebrew customer names.
- Test English customer names.
- Test mixed customer names only where business policy allows it.
- Test Hebrew item names and descriptions.
- Test email and phone formats.
- Confirm text renders correctly in Dynamics 365, Power Automate run history, Dataverse, and PayPlus page output.

## Known POC Results

- `setheader` policy works.
- `@connectionParameters('secretParam')` is injected into a header at runtime.
- `securestring` connection parameter works.
- Key Vault backed secret was blocked by network configuration.
- `MyTerminals` returns `uuid` values used as `terminal_uid`.
- Dependent dropdown may cause 409 in the designer when the list source requires a parameter.
- `x-ms-dynamic-values` worked for simple terminal selection.
- `x-ms-dynamic-list` resolved the dependent payment page picker pattern in the tested environment.
- Existing designer action nodes may need deletion and recreation after connector updates.

## Exit Criteria

- Sandbox payment link generation succeeds.
- No secrets are visible in run history.
- Security and PCI documents are approved.
- DLP policy is applied.
- Dataverse storage rules are accepted.
- Production connection ownership is approved.
- Troubleshooting path is documented and support owners are identified.
