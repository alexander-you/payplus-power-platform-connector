# Architecture Decision Record

This document records the main architecture decisions for the PayPlus Power Platform connector.

## ADR-001: Use No Auth In The Connector Definition

### Context

PayPlus requires two request headers: `api-key` and `secret-key`. The built-in API Key authentication model for Power Platform custom connectors is designed around a single API key and does not cleanly model two independent headers.

### Decision

Define the connector as No Auth from the custom connector authentication perspective. Model PayPlus credentials as secure connection parameters and inject the required headers with policies.

### Consequences

- The Power Platform connection still carries credentials, but they are not represented as standard connector auth.
- Flow makers do not see key fields on each action.
- Authentication behavior is controlled by connector properties and policies.
- Connector maintainers must preserve the policies during deployment.

### Alternatives Considered

- Built-in API Key auth: rejected because it does not model the two-key PayPlus requirement well.
- Per-action header inputs: rejected because it exposes secrets in action schemas and run history.
- Middleware service: deferred because it adds hosting, operations, and security overhead.

## ADR-002: Use Securestring Connection Parameters

### Context

The connector needs to store PayPlus `api-key` and `secret-key` in a way that is entered once per connection and hidden from makers and action inputs.

### Decision

Use `securestring` connection parameters named `apiKey` and `secretKey`.

### Consequences

- Credentials are provided during connection creation.
- Credentials are not present in each action payload.
- Connection owners must manage credential rotation by updating or recreating the connection.
- Secure values are not readable back through normal connector APIs.

### Alternatives Considered

- String environment variables: rejected because they are not appropriate for secrets.
- Secret environment variables backed by Key Vault: deferred due to network access blockers.
- Dataverse table fields: rejected because secrets should not be stored in business data tables.

## ADR-003: Inject Headers With Policies

### Context

PayPlus expects headers named `api-key` and `secret-key` on API calls.

### Decision

Use `setheader` policies:

- `api-key` = `@connectionParameters('apiKey')`
- `secret-key` = `@connectionParameters('secretKey')`

### Consequences

- Header injection is centralized.
- Actions remain clean and do not expose credential parameters.
- POC verified that connection parameters resolve at runtime in policy expressions.
- Testing must include a request inspection step with dummy secrets only.

### Alternatives Considered

- Add headers to every action: rejected due to secret exposure and maintenance overhead.
- Custom code policy: not required for simple header injection.
- Middleware injection: deferred.

## ADR-004: Do Not Use Key Vault Backed Environment Variables For The Current Default

### Context

Key Vault backed secret environment variables are attractive for enterprise governance, but the POC encountered a network governance blocker: Key Vault `publicNetworkAccess=Disabled` prevented Dataverse or Power Platform from resolving the secret value without additional private networking design.

### Decision

Do not use Key Vault backed environment variables as the default connector credential storage approach for this phase.

### Consequences

- The architecture avoids the current Key Vault network blocker.
- Secrets are managed at the Power Platform connection level.
- Organizations that require Key Vault can add it later with private endpoint, VNet integration, policy exemption, or a managed middleware pattern.

### Alternatives Considered

- Key Vault backed environment variables: deferred until the network path is approved and tested.
- Public Key Vault allowlist: deferred because it requires security approval and tenant-specific network controls.
- Custom middleware with managed identity: deferred until business value justifies the added surface.

## ADR-005: Do Not Introduce A Middleware Server In Phase One

### Context

A middleware service could centralize secrets, request signing, IPN validation, retries, and observability. It also introduces hosting, monitoring, deployment, identity, and operational responsibilities.

### Decision

Use a connector-centric low-code architecture without a middleware server for the first phase.

### Consequences

- Faster implementation and lower operational burden.
- Power Platform remains the primary integration layer.
- Advanced controls such as complex IPN validation or token vaulting may require a future service.

### Alternatives Considered

- Azure Function proxy: deferred.
- API Management facade: deferred.
- Logic Apps Standard or custom service: deferred.

## ADR-006: Make Generate Payment Link The Primary Path

### Context

Hosted payment links reduce PCI scope and are the most suitable path for business users who initiate collection from Dynamics 365 or Power Automate.

### Decision

Use `GeneratePaymentLink` as the main user-facing payment operation.

### Consequences

- Customers enter card details only in PayPlus.
- Power Platform stores payment metadata rather than card data.
- The business process is easy for service, collection, and operations users.

### Alternatives Considered

- Direct raw card charge: rejected for phase one due to PCI impact.
- Token-based charge: allowed only as a future or controlled advanced scenario.
- Manual PayPlus dashboard process: rejected as it does not provide Dynamics integration.

## ADR-007: Do Not Implement Raw Credit Card Charge In Phase One

### Context

Raw card charge operations could require PAN, expiry, and CVV in Power Automate action inputs or flow variables.

### Decision

Do not expose operations that accept raw PAN or CVV in phase one.

### Consequences

- PCI scope is reduced.
- Flow run history and logs do not carry raw card data.
- Some direct-charge scenarios are intentionally unsupported until a dedicated review is completed.

### Alternatives Considered

- Expose raw charge with secure inputs: rejected because run-history and maker misuse risks remain.
- Use hosted payment page: accepted.
- Use token-only charge: possible under dedicated controls.

## ADR-008: Treat `terminal_uid` As A Required Business Selection

### Context

PayPlus terminal UUIDs are returned by `MyTerminals` and are required for operations such as listing payment pages. The POC confirmed that `GET /MyTerminals` returns UUID values used as `terminal_uid`.

### Decision

Use `terminal_uid` as a first-class input or configuration value where PayPlus requires terminal context.

### Consequences

- Setup flows can let the admin select the correct terminal.
- Payment page lists can be filtered by terminal.
- Flows should store only terminal identifiers that are approved for business use.

### Alternatives Considered

- Hard-code terminal UID: rejected except for controlled examples.
- Store terminal UID as a connection parameter: tested and abandoned for user experience reasons.
- Ask users to type terminal UID manually every time: rejected as error-prone.

## ADR-009: Handle Dropdown Limitations Explicitly

### Context

The Power Automate designer can fail with 409 manifest errors when dependent dropdowns are implemented with `x-ms-dynamic-values` and the source operation requires a parameter.

### Decision

Document the limitation and use the stable pattern discovered in the POC:

- Use `x-ms-dynamic-values` for simple terminal dropdowns.
- Use `x-ms-dynamic-list` for dependent payment page lists when needed.
- Keep standalone discovery actions available for troubleshooting.

### Consequences

- Designers get better usability without blocking action insertion.
- Regression testing must include creating a fresh action node in the designer.
- Existing action nodes may need deletion and recreation after connector updates.

### Alternatives Considered

- Use dependent `x-ms-dynamic-values`: rejected due to reproducible 409 errors.
- Make all fields plain text: accepted as fallback, but less usable.
- Use a setup wizard to retrieve options: useful for admin setup scenarios.

## ADR-010: Conditions For Token-Based Charge In The Future

### Context

Token-based charge avoids raw PAN but still introduces sensitive payment behavior and token handling.

### Decision

Token-based charge may be added or enabled only when all of the following are true:

- The token is created and stored by PayPlus or an approved PCI-scoped component.
- No raw PAN or CVV is accepted by connector actions.
- Flow secure inputs and secure outputs are enabled where needed.
- Dataverse stores only approved token references or aliases, never raw card data.
- Security, compliance, and business owners approve the scenario.
- Monitoring, auditing, and incident handling are defined.

### Consequences

- Token charging remains possible without opening the raw card path.
- Token values must be treated as sensitive.
- A dedicated approval path is still required.

### Alternatives Considered

- Raw direct charge: rejected.
- Hosted payment link only: default phase-one position.
- Middleware token vault: future option for stricter controls.
