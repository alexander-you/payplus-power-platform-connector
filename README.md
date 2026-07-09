# PayPlus Custom Connector for Microsoft Power Platform and Dynamics 365

This repository contains the architecture, implementation guidance, governance documentation, connector artifacts, diagrams, and configuration examples for integrating PayPlus with Microsoft Power Platform and Dynamics 365.

The primary integration pattern is a Power Platform Custom Connector that lets makers and business users create PayPlus hosted payment links from Power Automate or Dynamics 365 without working directly with the PayPlus REST API.

## Purpose

The solution enables organizations using Dynamics 365, Dataverse, and Power Automate to initiate and track PayPlus payment activity in a governed, low-code way.

The first production-oriented path is hosted payment link generation. A user or flow creates a payment request, the connector calls PayPlus, PayPlus returns a hosted payment page link, and the customer pays on the PayPlus page.

The solution explicitly avoids collecting raw card details inside Dynamics 365, Dataverse, Power Automate, or custom connector action inputs.

## Intended Audience

This repository is intended for:

- Business users who create or manage payment requests.
- Power Platform makers who build flows and apps.
- Dynamics 365 administrators and solution architects.
- Security, governance, compliance, and IT teams reviewing the integration.
- Developers who maintain the custom connector definition and deployment artifacts.

## What The Solution Does

- Generates a PayPlus hosted payment page link from Power Automate or Dynamics 365.
- Stores or writes back payment identifiers such as payment request UID, transaction UID, payment status, and payment link where the implementation chooses to use Dataverse.
- Uses PayPlus as the cardholder-facing payment page.
- Keeps PayPlus API credentials at the Power Platform connection level as secure connection parameters.
- Uses connector policies to inject the `api-key` and `secret-key` headers at runtime.
- Supports separate sandbox and production connector definitions.
- Provides guidance for optional Dataverse tables, validation flows, setup flows, and future extensions.

## What The Solution Does Not Do

- It does not process raw credit card numbers inside Power Platform.
- It does not store PAN, CVV, or full card data in Dynamics 365, Dataverse, flow variables, environment variables, or logs.
- It does not replace PayPlus acquiring, settlement, risk, or merchant configuration.
- It does not replace an ERP general ledger or receivables subledger.
- It does not expose raw direct card charge operations in the first implementation phase.
- It does not assume that Key Vault backed environment variables are available in every tenant.
- It does not include real API keys, secrets, tenant IDs, connection IDs, webhook URLs, or production identifiers.

## Business User Summary

Business users do not need to understand the PayPlus API.

A typical process is:

1. The user creates a payment request from a flow, model-driven app, or Dynamics 365 process.
2. The system calls the PayPlus custom connector.
3. PayPlus returns a payment link.
4. The user sends the link to the customer, or the system sends it automatically.
5. The customer pays on the hosted PayPlus payment page.
6. The system can store the payment link, PayPlus identifiers, status, and reconciliation fields.
7. Card details remain on the PayPlus hosted page and are not stored in Dynamics 365 or Power Platform.

## Supported Scenarios

- Create a hosted payment link for a customer.
- Use PayPlus sandbox and production environments.
- Store PayPlus API credentials as secure connection parameters.
- Inject `api-key` and `secret-key` request headers through connector policies.
- Retrieve terminals and payment pages for setup or dynamic input assistance.
- Write back payment request identifiers and status values to Dataverse, if Dataverse is used.
- Validate a connection by generating a minimal PayPlus hosted payment link in sandbox or production.
- Support Hebrew and English business data where the underlying PayPlus and Dynamics fields support it.

## Not Supported In The First Phase

- Raw PAN or CVV collection in Power Automate, Dynamics 365, Dataverse, or custom connector actions.
- Direct card charge with manually entered card data.
- Browser-side calls directly to the PayPlus REST API.
- Key Vault backed environment variable secrets as the default design, due to known network access blockers in some enterprise tenants.
- A custom middleware server or proxy.
- Full invoice, receipt, settlement, or ERP posting automation unless explicitly added in a later phase.
- Production use without security, governance, PCI, run-history, DLP, and approval reviews.

## Repository Structure

```text
.
├── README.md
├── README.he.md
├── connector/
│   ├── apiDefinition.prod.json
│   ├── apiDefinition.sandbox.json
│   ├── prod/apiProperties.json
│   └── sandbox/apiProperties.json
├── docs/
│   ├── en/
│   ├── he/
│   └── diagrams/
├── samples/
│   ├── config/
│   └── payloads/
├── power-automate/
│   └── flows/
└── webresources/
```

## Quick Start

1. Review the architecture and security documents before importing anything into a tenant.
2. Import or update the custom connector from `connector/apiDefinition.sandbox.json` and `connector/sandbox/apiProperties.json` in a development environment.
3. Create a Power Platform connection for the connector and enter the PayPlus `api-key` and `secret-key` in the connection dialog.
4. Test with sandbox credentials and a sandbox payment page.
5. Build a flow that calls `GeneratePaymentLink` with amount, currency, terminal, payment page UID, customer, and item data.
6. Store only non-card payment metadata in Dataverse.
7. Repeat the deployment pattern for production after approval.

## Prerequisites

- Microsoft Power Platform environment with permission to create or update custom connectors.
- Dynamics 365 or Dataverse environment, if payment records are stored in Dataverse.
- PayPlus sandbox credentials for development and testing.
- PayPlus production credentials for production rollout.
- PayPlus terminal and payment page configuration.
- Power Platform DLP policy review.
- Approval from security, governance, and compliance teams before production use.

## Supported Environments

| Environment | PayPlus Host | Use |
| --- | --- | --- |
| Sandbox | `restapidev.payplus.co.il` | Development and validation |
| Production | `restapi.payplus.co.il` | Live payment operations |

Both connector definitions use the PayPlus API base path `/api/v1.0`.

## Core Documents

| Topic | English | Hebrew |
| --- | --- | --- |
| Architecture | [docs/en/architecture.md](docs/en/architecture.md) | [docs/he/architecture.md](docs/he/architecture.md) |
| Architecture decisions | [docs/en/adr.md](docs/en/adr.md) | [docs/he/adr.md](docs/he/adr.md) |
| Business user guide | [docs/en/business-user-guide.md](docs/en/business-user-guide.md) | [docs/he/business-user-guide.md](docs/he/business-user-guide.md) |
| Security and compliance | [docs/en/security-governance-and-compliance.md](docs/en/security-governance-and-compliance.md) | [docs/he/security-governance-and-compliance.md](docs/he/security-governance-and-compliance.md) |
| PCI considerations | [docs/en/pci-considerations.md](docs/en/pci-considerations.md) | [docs/he/pci-considerations.md](docs/he/pci-considerations.md) |
| Custom connector design | [docs/en/custom-connector-design.md](docs/en/custom-connector-design.md) | [docs/he/custom-connector-design.md](docs/he/custom-connector-design.md) |
| Data model | [docs/en/data-model.md](docs/en/data-model.md) | [docs/he/data-model.md](docs/he/data-model.md) |
| Test plan | [docs/en/test-plan.md](docs/en/test-plan.md) | [docs/he/test-plan.md](docs/he/test-plan.md) |
| Troubleshooting | [docs/en/troubleshooting.md](docs/en/troubleshooting.md) | [docs/he/troubleshooting.md](docs/he/troubleshooting.md) |
| Assumptions and open questions | [docs/en/assumptions-and-open-questions.md](docs/en/assumptions-and-open-questions.md) | [docs/he/assumptions-and-open-questions.md](docs/he/assumptions-and-open-questions.md) |

## Key Security Position

The connector does not process card payments inside Power Platform. It redirects the customer to a PayPlus hosted payment page. The connector must not expose operations that accept raw PAN or CVV unless a dedicated PCI review and approval process is completed.

## Assumptions And Open Questions

- Exact PayPlus response schemas should be confirmed against the official OpenAPI or sandbox responses before expanding connector coverage.
- Webhook/IPN handling is implementation-dependent and must be reviewed for signature validation, replay protection, logging, and failure handling.
- Dataverse tables are proposed in this repository but should be aligned with the customer's Dynamics 365 data model.
- Token-based charging may be considered later only under a dedicated security and PCI review.

## Confidentiality

This repository intentionally contains no real secrets, no real API keys, no real connection IDs, no tenant-specific webhook URLs, and no customer payment data.
