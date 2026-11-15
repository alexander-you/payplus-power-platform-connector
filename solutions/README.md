# Solutions (source)

Unpacked source of the two Dataverse solutions shipped in the [GitHub releases](https://github.com/alexander-you/payplus-power-platform-connector/releases).
Produced with `pac solution unpack --packagetype Both`, so both managed and unmanaged packages can be rebuilt from here.

| Folder | Solution | Version | Depends on |
|---|---|---|---|
| [alex_d365_payplus/src](./alex_d365_payplus/src) | Base: tables, flows, custom APIs, connectors, PCF controls, web resources, app | 1.2.2.0 | Dataverse only (no Dynamics 365 Sales) |
| [alex_d365_payplus_sales_extended_data_model/src](./alex_d365_payplus_sales_extended_data_model/src) | Sales extension: Sales lookups, Sales document flows, `Process Workbench Payment (Sales)` | 1.1.1.0 | Base + Dynamics 365 Sales |

## Build model

The two solutions are exported from **different environments**, so the Base never picks up a Sales dependency:

| Solution | Exported from | Why |
|---|---|---|
| Base | A Sales-free build environment where the Base is unmanaged | Any reference to `invoice` / `quote` / `salesorder` would fail there, so the Base stays Sales-independent |
| Sales extension | A Sales development environment where Base and extension are unmanaged | The extension needs the Sales tables |

Every release ships each solution as **managed** (install/upgrade) and **unmanaged** (development).

## Release checklist

1. Apply the change in **both** environments. For flow changes, use the scripts in [tools/flow-transforms](../tools/flow-transforms).
2. Bump the version of each changed solution.
3. Export managed and unmanaged:
   - Base: from the Sales-free build environment.
   - Extension: from the Sales environment.
4. Validate the Base package: its only missing dependencies are the standard platform ones (environment variable definition type, the default app icon, AppChannel), with no `invoice` / `invoicedetail` / `quote` / `salesorder` references.
5. Test a managed upgrade in a Sales environment: Base first, then the extension.
6. Refresh this folder from the release packages:
   ```powershell
   # copy <name>_<ver>_unmanaged.zip -> <name>.zip and <name>_<ver>_managed.zip -> <name>_managed.zip, then:
   pac solution unpack --zipfile <name>.zip --folder solutions/<name>/src --packagetype Both --allowDelete true --allowWrite true
   ```
7. Commit, tag `vX.Y.Z`, and publish a GitHub release with the four packages.

## Rebuilding a package from source

```powershell
pac solution pack --zipfile alex_d365_payplus.zip --folder solutions/alex_d365_payplus/src --packagetype Unmanaged
pac solution pack --zipfile alex_d365_payplus_managed.zip --folder solutions/alex_d365_payplus/src --packagetype Managed
```

## Known issues

- [#3](https://github.com/alexander-you/payplus-power-platform-connector/issues/3): several flows (`PayPlus HF Session`, `Send Card Link (Email/SMS/WhatsApp)`) contain a development environment URL as the default `refURL_origin`.
- [#4](https://github.com/alexander-you/payplus-power-platform-connector/issues/4): `PayPlus - Preview Invoice Document` can run twice for one update; the second run fails with `unique-identifier-exists` and marks the document as failed even though it was created in PayPlus.
