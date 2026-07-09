# Custom Connector Design

## Purpose

This document describes the technical design of the PayPlus custom connector for Microsoft Power Platform.

## Auth Model

The connector is configured as No Auth in the custom connector security definition. PayPlus authentication is implemented through secure connection parameters and policies.

Reason:

- PayPlus requires two headers: `api-key` and `secret-key`.
- Built-in API Key auth is not a good fit for two independent headers.
- Per-action key inputs would expose secrets to makers and run history.

## Connection Parameters

Defined in `apiProperties.json`:

| Name | Type | Required | Clear text | Purpose |
| --- | --- | --- | --- | --- |
| `apiKey` | `securestring` | Yes | No | PayPlus API key |
| `secretKey` | `securestring` | Yes | No | PayPlus secret key |

Connection parameters are supplied when creating the Power Platform connection. They are not visible as normal operation inputs.

## Policies

The connector uses two request policies:

```json
{
  "templateId": "setheader",
  "title": "Inject api-key header",
  "parameters": {
    "x-ms-apimTemplateParameter.name": "api-key",
    "x-ms-apimTemplateParameter.value": "@connectionParameters('apiKey')",
    "x-ms-apimTemplateParameter.existsAction": "override",
    "x-ms-apimTemplate-policySection": "Request"
  }
}
```

A second policy injects `secret-key` from `@connectionParameters('secretKey')`.

The POC verified that `@connectionParameters('secretParam')` resolves at runtime inside a `setheader` policy.

## Actions

Current connector action groups include:

| Area | Operations |
| --- | --- |
| Payment pages | `GeneratePaymentLink`, `ListPaymentPages` |
| Discovery | `MyTerminals` |
| Customers | `CreateCustomer`, `UpdateCustomer`, `ViewCustomers`, `RemoveCustomer` |
| Transactions | `ViewTransactions`, `CancelTransaction`, `RefundByTransaction`, `ChargeByTransactionUid`, `ChargeSavedCard` |
| Recurring | `CreateRecurringPayment` |
| Products | `CreateProduct`, `UpdateProduct`, `ViewProducts` |
| Categories | `CreateProductCategory`, `UpdateProductCategory`, `ViewProductCategories` |

The primary business action is `GeneratePaymentLink`.

## Internal Actions

`ListPaymentPages` can be marked internal when used only to populate dropdown values. It may also be made visible for troubleshooting or setup validation.

Internal or helper operations should not expose secrets or raw card fields.

## Dynamic Dropdowns

Known pattern from POC:

- `MyTerminals` returns a bare array. Use `x-ms-dynamic-values` with `value-path` = `uuid` and `value-title` = `name_terminal`.
- `ListPaymentPages` returns a wrapped response with `data`. Use `x-ms-dynamic-list` for dependent page selection when the terminal value is needed.
- `payment_page_uid` should resolve from `ListPaymentPages` with `itemValuePath` = `uid` and `itemTitlePath` = `name`.

## Known Designer Limitation

The new Power Automate designer can return `409 Error fetching manifest` when a dependent dropdown uses `x-ms-dynamic-values` and the source operation has a required parameter.

POC result:

- Dependent dropdown through `x-ms-dynamic-values` caused 409.
- `x-ms-dynamic-list` avoided the 409 for the dependent payment page picker.
- Existing action nodes can remain broken after connector updates. Delete the action node, hard refresh, and add it again.

## Error Handling

Recommended connector and flow error handling:

- Define known success response schemas.
- Capture status code, PayPlus `results.status`, `results.code`, and `results.description` where available.
- Do not assume all PayPlus failures return structured JSON.
- Treat 403 and 502 differently during troubleshooting.
- Set retry policy carefully for validation flows so errors fail fast.
- Store sanitized failure details in Dataverse.

## Naming Conventions

Recommended naming:

| Item | Convention |
| --- | --- |
| Operation IDs | PascalCase, business oriented, e.g. `GeneratePaymentLink` |
| Connector title | `PayPlus` for production, `PayPlus Sandbox` for sandbox |
| Connection parameters | camelCase, e.g. `apiKey`, `secretKey` |
| Headers | PayPlus exact names: `api-key`, `secret-key` |
| Dataverse custom prefix | Customer or publisher prefix, e.g. `alex_` in the POC |
| Flow names | `PayPlus - <Business Purpose>` |

## Dev And Prod Endpoints

| Environment | Host | Base path |
| --- | --- | --- |
| Sandbox | `restapidev.payplus.co.il` | `/api/v1.0` |
| Production | `restapi.payplus.co.il` | `/api/v1.0` |

Keep separate connector definitions and separate connections for each environment.

## Packaging And Deployment

Typical deployment steps:

1. Store connector definition and apiProperties in source control.
2. Validate JSON syntax.
3. Import or update the connector in a development environment.
4. Create a Power Platform connection and enter PayPlus credentials.
5. Bind connection references in the solution.
6. Import flows and Dataverse components.
7. Run sandbox validation.
8. Export as managed solution for higher environments.
9. Recreate or bind environment-specific connections during import.
10. Run production validation after approval.

For PAC CLI deployments, the established pattern is to update a connector with the API definition file and API properties file.

## Testing

Test levels:

- JSON schema validation for connector files.
- Connector import or update test.
- Connection creation test.
- `MyTerminals` runtime test.
- `ListPaymentPages` runtime test with `terminal_uid`.
- `GeneratePaymentLink` sandbox test with a complete body.
- Designer test: create a fresh action node and verify dropdown behavior.
- Run history test for sensitive values.
- Negative tests for invalid key, terminal, payment page, amount, and currency.

## Open Questions

- Exact PayPlus OpenAPI schemas should be confirmed before expanding additional operations.
- Some operations may require module enablement in PayPlus.
- Token-based operations require security and PCI review before production use.
