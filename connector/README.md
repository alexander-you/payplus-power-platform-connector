# Connector Artifacts

This folder contains custom connector artifacts for PayPlus.

## Files

| File | Purpose |
| --- | --- |
| `apiDefinition.sandbox.json` | Sandbox connector OpenAPI definition |
| `apiDefinition.prod.json` | Production connector OpenAPI definition |
| `sandbox/apiProperties.json` | Sandbox connector connection parameters and policies |
| `prod/apiProperties.json` | Production connector connection parameters and policies |

## Security Notes

- These files must not contain real `api-key` or `secret-key` values.
- Credentials belong in the Power Platform connection dialog.
- `apiProperties.json` contains policy expressions, not secret values.
- Review changes to operation schemas for accidental PAN or CVV inputs.

## Deployment Note

Use the environment-specific API definition and API properties together. Keep sandbox and production connections separate.
