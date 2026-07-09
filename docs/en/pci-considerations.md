# PCI Considerations

## Purpose

This document summarizes PCI-related considerations for the PayPlus integration with Microsoft Power Platform and Dynamics 365. It is not a formal PCI assessment. It is an implementation guide for reducing card-data exposure and identifying approval gates.

## Why Hosted Payment Page Reduces Risk

The recommended first-phase flow uses a PayPlus hosted payment page. The customer enters card details on PayPlus, not in Dynamics 365, Dataverse, Power Automate, or a custom connector input.

This reduces risk because:

- Power Platform does not collect PAN.
- Power Platform does not collect CVV.
- Flow makers do not design card-entry screens.
- Run history should contain payment metadata, not cardholder data.
- PayPlus remains the payment processing and card entry environment.

## Raw PAN And CVV Do Not Pass Through Power Platform

The connector design must not include first-phase operations that accept raw card number, full card track data, or CVV. Payment link generation should pass business and payment request fields only, such as amount, currency, customer reference, item description, terminal, and payment page UID.

## CVV Must Never Be Stored

CVV must not be stored in any form:

- Not in Dataverse.
- Not in flow variables.
- Not in environment variables.
- Not in logs.
- Not in notes, emails, comments, or approvals.
- Not in connector action inputs or outputs.

If any future PayPlus operation requires CVV for a specific use case, that operation is out of scope until a dedicated PCI review is completed.

## Power Automate Run History Risk

Power Automate can retain trigger inputs, action inputs, action outputs, variables, Compose values, and error payloads. Even when the design avoids PAN and CVV, run history may contain sensitive metadata.

Risk examples:

- Payment link values.
- Customer identifiers.
- Transaction UIDs.
- Token values.
- Error messages that echo request data.

Mitigation:

- Use secure inputs and secure outputs for sensitive actions.
- Avoid Compose actions for sensitive values.
- Limit run history access.
- Avoid storing unnecessary response payloads.
- Define retention and support access rules.

## Logging Risk

Logs may be created by flows, Dataverse plugins, custom pages, browser console output, connectors, monitoring tools, or support exports.

Logging rules:

- Do not log PAN or CVV.
- Do not log API keys or secret keys.
- Treat token values as sensitive.
- Mask customer identifiers when logs are exported outside the support boundary.
- Store only correlation IDs and non-sensitive status details when possible.

## Payment Link vs Token vs Raw Card

| Pattern | Description | PCI Impact | Phase-One Position |
| --- | --- | --- | --- |
| Payment link | Customer pays on PayPlus hosted page | Lowest exposure for Power Platform | Recommended |
| Token | PayPlus token represents a stored payment method | Sensitive, but no raw PAN if implemented correctly | Future or controlled advanced use |
| Raw card | PAN and possibly CVV are passed to an API | Highest exposure | Not allowed in phase one |

## Conditions For Considering Token-Based Charge

Token-based charge can be considered only when:

- The token is created by PayPlus or another approved PCI-scoped system.
- The connector does not accept raw PAN or CVV.
- Token values are treated as sensitive.
- Secure inputs and secure outputs are configured.
- Dataverse stores only approved token references, aliases, or metadata.
- Business, security, compliance, and PCI owners approve the scenario.
- Incident response and rotation/revocation processes are defined.

## Conditions Where Direct Card Charge Must Not Be Implemented

Direct card charge must not be implemented when any of the following are true:

- The operation requires users to type PAN into Dynamics 365 or Power Automate.
- The operation requires CVV in any flow input, variable, log, or Dataverse field.
- Run history controls are not approved.
- DLP and environment separation are not approved.
- There is no formal PCI review.
- Support users could view raw card data.
- The business requirement can be met through hosted payment link instead.

## First-Phase Recommendation

Use Hosted Payment Page as the first-phase payment pattern.

Do not implement raw direct card charge in Power Platform. Consider token-based charge later only through a dedicated design, security, and PCI approval process.

## Minimum Production Controls

- Security and PCI approval for the hosted payment page pattern.
- No connector operations that accept raw PAN or CVV.
- Secure connection parameters for PayPlus credentials.
- Secure inputs and outputs where sensitive metadata or tokens are handled.
- DLP policy applied.
- Environment separation between sandbox and production.
- Restricted run history access.
- Incident response procedure documented.
