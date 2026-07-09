# Security, Governance, And Compliance

## Scope

This document is written for security review, risk assessment, governance review, compliance review, and IT approval. It describes the security model for the PayPlus custom connector integration with Microsoft Power Platform and Dynamics 365.

The solution uses PayPlus hosted payment pages as the primary payment path. Power Platform creates and tracks payment requests but does not collect raw card data.

## Security Model Overview

The main security principle is separation of responsibilities:

- Dynamics 365 and Dataverse hold business records and payment metadata.
- Power Automate orchestrates requests and write-back.
- The custom connector calls PayPlus through controlled actions.
- PayPlus hosts the cardholder payment page and processes card data.
- Credentials are stored at the Power Platform connection level and injected at runtime by connector policies.

## Where Secrets Are Stored

PayPlus `api-key` and `secret-key` are stored as Power Platform custom connector connection parameters:

- `apiKey`: `securestring`
- `secretKey`: `securestring`

These values are entered when the connection is created. They are not stored as Dataverse rows, not hard-coded in flows, and not passed as normal action parameters.

## Why `apiKey` And `secretKey` Are Securestring Connection Parameters

This design keeps credentials at the connection boundary. It also aligns with how makers use connectors: the connection owner supplies credentials once, and flows use the connection reference.

Benefits:

- Credentials are hidden from action inputs.
- Credentials are not repeated across actions.
- Credentials are not stored in normal flow definitions as plain text.
- Rotation is handled by updating or recreating the connection.

## Why Keys Are Not Parameters On Every Action

Putting `api-key` and `secret-key` on every action would create avoidable risk:

- Makers could paste keys into flows.
- Keys could appear in run history or exported definitions.
- Every action would need secure input configuration.
- Operational mistakes would be more likely.

The connector policy approach removes credential fields from business action schemas.

## Why Keys Are Not String Environment Variables

String environment variables are not appropriate for secrets. They can be easier to view, export, or misuse. The design therefore avoids storing PayPlus credentials as String Environment Variables.

## Why Key Vault Was Not Selected For The Current Default

A Key Vault backed Environment Variable design was evaluated. In the POC, Key Vault secret resolution was blocked because the Key Vault had `publicNetworkAccess=Disabled` and the required Power Platform private network path was not available.

The current default therefore uses secure connection parameters. Key Vault can be reconsidered when the customer has an approved private networking design or policy exception.

## `publicNetworkAccess=Disabled` Blocker

When `publicNetworkAccess=Disabled` is enforced on a Key Vault, public data-plane access is blocked. Dataverse or Power Platform cannot resolve Key Vault backed environment variable secrets unless the environment has an approved private network route, such as private endpoint and supported integration.

This is a governance constraint, not a PayPlus connector bug.

## No Raw Credit Card Or CVV

The primary solution path does not accept raw PAN or CVV. Customers enter card details on the PayPlus hosted payment page.

The connector must not expose operations that accept raw PAN or CVV unless a dedicated PCI review and approval process is completed.

## PCI Considerations

The hosted payment page pattern reduces PCI exposure because card entry occurs in PayPlus. Power Platform still needs governance because it may store payment metadata and may run flows that contain customer identifiers, payment links, transaction IDs, tokens, or status payloads.

Required PCI posture:

- Do not collect PAN in Power Platform.
- Do not collect or store CVV in any form.
- Treat payment tokens as sensitive.
- Review run history, logging, exports, and support access.
- Confirm PayPlus hosted page compliance through vendor documentation.

## Run History Considerations

Power Automate run history can retain action inputs and outputs. Flows must avoid raw card data entirely and should enable secure inputs and secure outputs for actions that contain sensitive payment metadata or token values.

Review:

- Trigger inputs.
- Connector action inputs and outputs.
- Compose actions.
- Variables.
- Error handling branches.
- Approval comments and emails.

## Secure Inputs And Secure Outputs

Use secure inputs and secure outputs when handling:

- PayPlus tokens.
- Customer identifiers if classified as sensitive.
- Payment links if internal policy treats them as sensitive.
- Error payloads that may echo request values.

Secure inputs and outputs reduce visibility in run history but do not replace good data minimization.

## DLP Policy

The connector should be classified according to the organization's Power Platform DLP model. Recommended controls:

- Place PayPlus, Dataverse, Office 365, and approved communication connectors in a compatible business data group.
- Block unmanaged or consumer connectors from flows that handle payment processes.
- Use separate policies for development and production.
- Review connectors used for notifications, exports, and logging.

## Least Privilege

Apply least privilege to:

- Makers who can edit the connector.
- Owners of PayPlus connections.
- Users who can run payment flows.
- Users who can view flow run history.
- Users who can read Dataverse payment tables.
- Administrators who can export solutions.

## Connection Ownership

Production connections should be owned by an approved service owner or controlled administrator account, according to tenant policy. Avoid personal ownership for production payment flows.

Document:

- Connection owner.
- Credential owner.
- Rotation owner.
- Break-glass process.
- Approval trail.

## Environment Separation

Use separate environments and credentials:

| Environment | Purpose | Credential Type |
| --- | --- | --- |
| Development | Build and unit validation | PayPlus sandbox |
| Test/UAT | Business validation | PayPlus sandbox or controlled test merchant |
| Production | Live payments | PayPlus production |

Do not reuse production credentials in development.

## Secret Rotation

Rotation procedure:

1. Obtain new PayPlus credentials through the approved PayPlus process.
2. Update or recreate the Power Platform connector connection.
3. Rebind connection references if a new connection is created.
4. Run validation in sandbox or controlled production validation.
5. Disable old credentials.
6. Record the rotation in the operational log.

## Auditing And Monitoring

Recommended audit areas:

- Connector definition changes.
- Connection creation and ownership changes.
- Flow changes and solution imports.
- Payment request creation.
- Payment status updates.
- Failed PayPlus calls.
- Unusual volume or repeated failures.
- Manual overrides.

## Incident Response

Incident response should define:

- How to disable payment flows.
- How to rotate PayPlus credentials.
- Who contacts PayPlus.
- How to identify affected payment requests.
- How to preserve logs without exposing sensitive data.
- How to notify security, compliance, finance, and business owners.

## Known Residual Risks

| Risk | Mitigation |
| --- | --- |
| Payment links may be forwarded | Expiration, business controls, PayPlus settings, customer verification where required |
| Flow run history may expose metadata | Data minimization, secure inputs/outputs, restricted run history access |
| Connection owner can affect payment capability | Controlled ownership and documented rotation process |
| Wrong environment selected | Separate connectors, clear naming, validation before production |
| Token values may be sensitive | Treat tokens as secrets or sensitive data and avoid broad access |
| Connector designer regressions | Regression test action creation after connector changes |

## Required Controls Before Production

- Security approval completed.
- Compliance review completed.
- PCI position approved.
- DLP policy approved and applied.
- Production connection owner approved.
- Credential rotation process documented.
- Run history settings reviewed.
- Dataverse access roles reviewed.
- Payment link status process tested.
- Failure and rollback process tested.
- No raw PAN or CVV operations exposed.

## Approval Checklist

| Control | Owner | Status |
| --- | --- | --- |
| Architecture approved | Solution architecture | Pending |
| Security model approved | Security | Pending |
| PCI position approved | Compliance / PCI owner | Pending |
| DLP policy approved | Power Platform governance | Pending |
| Production credentials approved | PayPlus / finance owner | Pending |
| Connection ownership approved | IT operations | Pending |
| Run history reviewed | Power Platform admin | Pending |
| Dataverse roles reviewed | Dynamics admin | Pending |
| Incident response tested | Security operations | Pending |
| Go-live approval | Business owner | Pending |
