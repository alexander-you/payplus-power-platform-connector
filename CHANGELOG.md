# Changelog / יומן שינויים

Installable packages for every version are on the [Releases](https://github.com/alexander-you/payplus-power-platform-connector/releases) page.
Solution source (unpacked Dataverse solutions, PCF controls, web resources, flow transform tools) is on the
[`solution`](https://github.com/alexander-you/payplus-power-platform-connector/tree/solution) branch.

חבילות ההתקנה של כל גרסה נמצאות בעמוד ה-[Releases](https://github.com/alexander-you/payplus-power-platform-connector/releases).
קוד המקור של הפתרון נמצא בענף [`solution`](https://github.com/alexander-you/payplus-power-platform-connector/tree/solution).

| Version | Base | Sales extension | Changes |
|---|---|---|---|
| [v1.2.2](https://github.com/alexander-you/payplus-power-platform-connector/releases/tag/v1.2.2) | 1.2.2.0 | 1.1.1.0 | Hosted-fields charges use the billing case currency (`alex_pp_hfsession.alex_currencycode`, ILS when empty) instead of a fixed ILS. PaymentWizard 0.1.24. |
| [v1.2.1](https://github.com/alexander-you/payplus-power-platform-connector/releases/tag/v1.2.1) | 1.2.1.0 | 1.1.1.0 | Workbench receipts keep negative source lines (discounts) when all lines add up to the payment. |
| [v1.2.0](https://github.com/alexander-you/payplus-power-platform-connector/releases/tag/v1.2.0) | 1.2.0.0 | 1.1.0.0 | Fix: Payment Workbench failed to load on a clean v1.1.0 install. Billing source mapping (Mapping Studio) in the Base. Workbench receipts: VAT type from configuration, items from source lines, conversion rate saved to `alex_conversionrate`, `close_doc` for the latest `inv_proforma`. |
| [v1.1.0](https://github.com/alexander-you/payplus-power-platform-connector/releases/tag/v1.1.0) | 1.1.0.0 | 1.0.0.0 | Base includes the Payment Workbench and Document Preview custom pages. PaymentWizard 0.1.23. **Superseded by v1.2.0.** |
| [v1.0.0](https://github.com/alexander-you/payplus-power-platform-connector/releases/tag/v1.0.0) | 1.0.0.0 | 1.0.0.0 | First release: Sales-independent Base and optional Sales extension. |

## Upgrading

1. Import the **Base** managed package (`alex_d365_payplus_<version>_managed.zip`). Upgrades are in place, with no data loss.
2. With Dynamics 365 Sales only: then import the **Sales extension** managed package.
3. Make sure the PayPlus flows are on, and remove any unmanaged layers you added on top of PayPlus flows.

## שדרוג

1. לייבא את חבילת **הבסיס** המנוהלת (`alex_d365_payplus_<version>_managed.zip`). השדרוג הוא במקום, בלי איבוד נתונים.
2. רק אם מותקן Dynamics 365 Sales: לייבא אחריו את חבילת **הרחבת Sales** המנוהלת.
3. לוודא שה-flows של PayPlus פעילים, ולהסיר שכבות לא מנוהלות שהוספתם מעל flows של PayPlus.
