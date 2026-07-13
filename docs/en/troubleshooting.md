# Troubleshooting

## General Approach

1. Confirm the environment: sandbox or production.
2. Confirm the PayPlus host matches the credentials.
3. Confirm the connection reference points to the intended connection.
4. Confirm the connection was created after secure connection parameters were added.
5. Run `MyTerminals` to verify runtime access.
6. Run `ListPaymentPages` with a known `terminal_uid`.
7. Run `GeneratePaymentLink` with a complete request body.
8. Inspect run history only within approved access boundaries.
9. Do not paste real secrets into logs, tickets, screenshots, or request inspectors.

## 403 Forbidden

Possible causes:

- Invalid `api-key` or `secret-key`.
- Sandbox credentials used against production host.
- Production credentials used against sandbox host.
- Missing required request body or unsupported endpoint.
- Terminal or payment page not valid for the credential scope.

Actions:

- Verify host and environment.
- Verify the action uses the connector connection, not per-action headers.
- Test with `GeneratePaymentLink` and a complete body.
- Check PayPlus response body if available.

## 502 Bad Gateway

Possible causes:

- Upstream PayPlus failure wrapped by the connector.
- Incomplete request sent to PayPlus.
- Unsupported operation or endpoint.
- Temporary gateway issue.

Actions:

- Disable aggressive retries during validation.
- Compare with a complete `GeneratePaymentLink` request.
- Capture status code and sanitized body.
- Do not assume WAF before validating endpoint, method, body, and credentials.

## Empty Response

Possible causes:

- Unsupported PayPlus endpoint.
- Missing required body.
- PayPlus or gateway rejected request before structured error generation.

Actions:

- Confirm the endpoint is documented and enabled.
- Use a complete body for payment link validation.
- Capture headers and correlation IDs without secrets.

## Invalid Credentials

Possible causes:

- Wrong key pair.
- Old connection without secure connection parameters.
- Connection reference still points to an old connection.
- Credentials belong to another environment.

Actions:

- Recreate the Power Platform connection.
- Rebind connection references.
- Validate with sandbox first.
- Rotate credentials if they were exposed.

## Invalid `terminal_uid`

Possible causes:

- Terminal UID copied from another account.
- Terminal inactive or not available to the key pair.
- User selected the wrong terminal.

Actions:

- Run `MyTerminals` through the same connection.
- Use returned `uuid` as `terminal_uid`.
- Confirm terminal status in PayPlus.

## Payment Page List Empty

Possible causes:

- No pages exist for the selected terminal.
- Wrong terminal selected.
- Credentials lack terminal scope.
- PayPlus returned an empty `data` array.

Actions:

- Run `MyTerminals`.
- Run `ListPaymentPages` with the selected terminal.
- Confirm payment page configuration in PayPlus.
- Use manual payment page UID only when validated.

## Terminals & Pages Import Failed

Possible causes:

- The `PayPlus - Import Terminals & Pages` flow is turned off or its connection is broken.
- `MyTerminals` or `ListPaymentPages` returned an empty or invalid response.
- Environment mismatch between the configuration and the connection.

Actions:

- Confirm the flow is turned on and uses a valid connection.
- Re-run the import from the setup wizard's Terminals & pages step (or the management center re-import link).
- Verify rows appear in `alex_payplus_terminal` and `alex_payplus_paymentpage`, keyed by environment + UID.
- Remember the import is idempotent: re-running upserts by (environment + UID) and preserves business/policy fields.

## No Default Terminal Or Page

Possible causes:

- The Validate step was not completed, so no record is flagged `alex_isdefault`.
- A default was cleared and not re-selected.

Actions:

- Re-run the Validate step and pick a default terminal and its default payment page. This writes `alex_terminaluidref` / `alex_paymentpageuidref` on the configuration and marks `alex_isdefault = true`.
- Only one default terminal per environment and one default page per terminal + process type are allowed; the `EnforceSingleDefaultTerminal` and `EnforceSingleDefaultPage` plugins clear the previous default automatically.

## Document Types Import Blocks Setup Completion

Symptoms:

- The Validate step does not advance to Done.
- Setup stays on Validate because the document-types import failed or timed out.

Possible causes:

- The document-types import is a mandatory, blocking step; the installation cannot complete until it succeeds.
- The import flow is off, or its connection is broken.
- The flow used an invalid inline `filter()` expression.

Actions:

- Confirm the document-types import flow is turned on and its connection is valid, then click Run validation again.
- Power Automate has no `filter()` expression function; use a **Filter array (Query)** action to filter arrays.

## Designer 409 Error Fetching Manifest

Possible causes:

- Dependent dropdown implemented with `x-ms-dynamic-values` where the source operation requires a parameter.
- Existing action node cached old connector metadata.

Actions:

- Use `x-ms-dynamic-list` for dependent payment page selection.
- Delete the broken action node.
- Hard refresh the designer.
- Add the action again.
- Keep `MyTerminals` and `ListPaymentPages` available for troubleshooting.

## Environment Variable Not Found

Possible causes:

- Old architecture expected environment variables that no longer exist.
- Solution import missed environment variable values.
- Flow still references obsolete variables.

Actions:

- Confirm current design uses secure connection parameters for keys.
- Remove obsolete references to key environment variables.
- Keep only non-secret environment variables if required by the implementation.

## Key Vault Network Blocked

Possible causes:

- Key Vault has `publicNetworkAccess=Disabled`.
- No approved private endpoint or network path exists for Power Platform.
- Azure Policy forces public access disabled.

Actions:

- Use secure connection parameters for the connector default design.
- Revisit Key Vault only with approved private networking or policy exception.
- Document the network decision in the security review.

## Policy Not Injecting Header

Possible causes:

- `policyTemplateInstances` missing from `apiProperties.json`.
- Wrong connection parameter name.
- Wrong quotes in expression.
- Connector update did not publish or runtime cache is stale.

Actions:

- Confirm policy value uses `@connectionParameters('apiKey')` and `@connectionParameters('secretKey')`.
- Confirm connection parameters are named exactly `apiKey` and `secretKey`.
- Recreate the connection if runtime cache is stale.
- Use request inspector only with dummy secrets.

## Connection Parameter Missing

Possible causes:

- Existing connection was created before parameters were added.
- Connector was updated but connection was not recreated.
- Connection dialog did not capture required values.

Actions:

- Delete and recreate the connection.
- Enter both keys in the connection dialog.
- Rebind connection references.
- Run `GeneratePaymentLink` validation.

## Sandbox Vs Production Mismatch

Symptoms:

- Credentials rejected.
- Payment pages not found.
- Unexpected host behavior.

Actions:

- Sandbox host must be `restapidev.payplus.co.il`.
- Production host must be `restapi.payplus.co.il`.
- Use separate connectors or clearly separated connection references.
- Do not test with production credentials in development.

## Wrong PayPlus Host

Actions:

- Check connector `host` field.
- Check selected environment in setup flow.
- Check connection reference naming.
- Validate the base path is `/api/v1.0`.

## Business-Level Keys Vs Terminal Scope

Some PayPlus operations may work with business-level credentials while others require terminal context. For example, listing payment pages requires a valid terminal UID.

Actions:

- Use `MyTerminals` to discover terminal UUIDs.
- Pass `terminal_uid` when required.
- Confirm key scope with PayPlus if operations return inconsistent results.

## Verify With Request Inspector Using Dummy Secrets Only

Request inspection is useful for proving policy injection, but never use real secrets in public tools or shared logs.

Safe method:

1. Create a temporary test connector or isolated test action.
2. Use dummy values such as `dummy-api-key` and `dummy-secret-key`.
3. Send a request to a trusted inspector endpoint.
4. Confirm headers are present.
5. Delete the test connection and test endpoint data.

Never send production PayPlus credentials to a request inspector.
