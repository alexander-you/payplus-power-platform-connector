# Flow transforms

Repeatable, idempotent changes to the PayPlus cloud flows. A transform is a Node.js script that reads a flow's
`clientdata` JSON and writes the changed version. Running it on an already-changed flow makes no further changes.

| Transform | Flow(s) | Change | Release |
|---|---|---|---|
| [workbench-receipt-fixes.js](./workbench-receipt-fixes.js) | `PayPlus - Process Workbench Payment`, `... (Sales)` | VAT type from `alex_document_vat_mode`; receipt items from mapped source lines (including negative discount lines); conversion rate saved to `alex_conversionrate`; `close_doc` for the latest `inv_proforma` | 1.2.0, 1.2.1 |
| [hfsession-currency.js](./hfsession-currency.js) | `PayPlus HF Session` | `GeneratePaymentLink` currency from `alex_pp_hfsession.alex_currencycode` (ILS when empty) | 1.2.2 |

## Applying a transform

Requirements: Azure CLI signed in (`az login`) and Node.js.

**Environment with working connections** (for example the Sales development environment). The script backs up,
saves and re-activates each flow, and rolls back if activation fails:

```powershell
./Apply-FlowTransform.ps1 -Org https://<env>.crm4.dynamics.com -Transform hfsession-currency.js -FlowNames 'PayPlus HF Session'
./Apply-FlowTransform.ps1 -Org https://<env>.crm4.dynamics.com -Transform workbench-receipt-fixes.js `
    -FlowNames 'PayPlus - Process Workbench Payment','PayPlus - Process Workbench Payment (Sales)' -ValidateOnly
```

**Sales-free build environment** (connection references without connections, so the flow cannot be saved through
the API). The script goes through a temporary transport solution, then deletes it:

```powershell
./Push-FlowTransformViaTransport.ps1 -Org https://<build-env>.crm4.dynamics.com -WorkflowId <workflow guid> -Transform hfsession-currency.js
```

## Testing a transform offline

```powershell
node hfsession-currency.js flow.before.json flow.after.json
node hfsession-currency.js flow.after.json flow.again.json   # must report "Already patched"
```
