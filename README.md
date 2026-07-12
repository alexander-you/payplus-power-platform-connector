# PayPlus Custom Connector for Microsoft Power Platform and Dynamics 365

**Language / שפה:** [English](#english) | [עברית](#hebrew)

<a id="english"></a>

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

## Capabilities

The full Dynamics 365 solution is built on four capability pillars. This repository focuses on the connector and its documentation; the sync engine, plugins, and PCF controls are delivered as part of the broader Dynamics 365 solution.

- **Connector and hosted payment**: typed PayPlus actions and hosted payment link generation.
- **Continuous sync engine**: configuration-driven, outbox-based synchronization of Dataverse records (customers, products, categories) to PayPlus, with field mapping, transforms, filters, and value maps.
- **PCF controls**: Mapping Studio (visual field mapping and sync activation) and Credit Card Wallet (tokenized card management).
- **Card tokenization and self-service**: hosted-fields tokenization, self-service card collection over email, SMS, and WhatsApp, and polling-based tokenization detection.
- **Document generation**: PayPlus Invoice+ / Books actions for tax documents such as invoices, receipts, and credit documents.

See [docs/en/architecture.md](docs/en/architecture.md) for the full architecture, tables, and diagrams.

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

## Repository Structure

```text
.
├── README.md
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
| Business user guide | [docs/en/business-user-guide.md](docs/en/business-user-guide.md) | [docs/he/business-user-guide.md](docs/he/business-user-guide.md) |
| Security and compliance | [docs/en/security-governance-and-compliance.md](docs/en/security-governance-and-compliance.md) | [docs/he/security-governance-and-compliance.md](docs/he/security-governance-and-compliance.md) |
| PCI considerations | [docs/en/pci-considerations.md](docs/en/pci-considerations.md) | [docs/he/pci-considerations.md](docs/he/pci-considerations.md) |
| Custom connector design | [docs/en/custom-connector-design.md](docs/en/custom-connector-design.md) | [docs/he/custom-connector-design.md](docs/he/custom-connector-design.md) |
| Test plan | [docs/en/test-plan.md](docs/en/test-plan.md) | [docs/he/test-plan.md](docs/he/test-plan.md) |
| Troubleshooting | [docs/en/troubleshooting.md](docs/en/troubleshooting.md) | [docs/he/troubleshooting.md](docs/he/troubleshooting.md) |
| Assumptions | [docs/en/assumptions.md](docs/en/assumptions.md) | [docs/he/assumptions.md](docs/he/assumptions.md) |

## Key Security Position

The connector does not process card payments inside Power Platform. It redirects the customer to a PayPlus hosted payment page. The connector must not expose operations that accept raw PAN or CVV unless a dedicated PCI review and approval process is completed.

## Confidentiality

This repository intentionally contains no real secrets, no real API keys, no real connection IDs, no tenant-specific webhook URLs, and no customer payment data.

---

<a id="hebrew"></a>

<div dir="rtl">

# מחבר PayPlus עבור Microsoft Power Platform ו-Dynamics 365

**שפה / Language:** [עברית](#hebrew) | [English](#english)

ריפו זה מכיל מסמכי ארכיטקטורה, הנחיות יישום, מסמכי אבטחה ותאימות, קבצי מחבר, תרשימים ודוגמאות קונפיגורציה עבור אינטגרציה בין PayPlus לבין Microsoft Power Platform ו-Dynamics 365.

דפוס האינטגרציה המרכזי הוא Custom Connector ב-Power Platform שמאפשר למשתמשים עסקיים וליוצרי תהליכים ליצור קישורי תשלום של PayPlus מתוך Power Automate או Dynamics 365, בלי לעבוד ישירות מול REST API.

## מטרת הפתרון

הפתרון מאפשר לארגונים שמשתמשים ב-Dynamics 365, Dataverse ו-Power Automate ליזום ולעקוב אחר פעולות תשלום מול PayPlus בצורה מנוהלת, מאובטחת ודלת-קוד.

הנתיב הראשי לשלב הראשון הוא יצירת קישור תשלום מתארח. המשתמש או התהליך יוצר בקשת תשלום, המחבר קורא ל-PayPlus, PayPlus מחזיר קישור לדף תשלום, והלקוח משלם בדף PayPlus.

הפתרון נמנע במפורש מאיסוף פרטי כרטיס אשראי גולמיים בתוך Dynamics 365, Dataverse, Power Automate או קלטים של פעולות במחבר.

## למי הפתרון מיועד

- משתמשים עסקיים שיוצרים או מנהלים בקשות תשלום.
- יוצרי פתרונות ב-Power Platform שבונים תהליכים ואפליקציות.
- מנהלי Dynamics 365 וארכיטקטי פתרונות.
- צוותי אבטחה, Governance, Compliance ו-IT שבוחנים את הפתרון.
- מפתחים שמתחזקים את הגדרת המחבר ואת artifacts הפריסה.

## מה הפתרון עושה

- יוצר קישור לדף תשלום מתארח של PayPlus מתוך Power Automate או Dynamics 365.
- מאפשר שמירה או כתיבה חוזרת של מזהים כגון מזהה בקשת תשלום, מזהה עסקה, סטטוס וקישור תשלום, כאשר היישום משתמש ב-Dataverse.
- משתמש ב-PayPlus כדף התשלום שבו הלקוח מזין את פרטי הכרטיס.
- שומר את פרטי הגישה ל-PayPlus ברמת החיבור ב-Power Platform כפרמטרים מאובטחים.
- משתמש ב-policies של המחבר כדי להזריק בזמן ריצה את הכותרות `api-key` ו-`secret-key`.
- תומך בהגדרות נפרדות לסביבת בדיקות ולסביבת ייצור.
- מספק הנחיות לטבלאות Dataverse אופציונליות, תהליכי אימות, תהליכי הגדרה והרחבות עתידיות.

## יכולות

הפתרון המלא ב-Dynamics 365 בנוי על ארבעה עמודי יכולת. ריפו זה מתמקד במחבר ובתיעוד שלו; מנוע הסנכרון, הפלאגינים ופקדי ה-PCF מסופקים כחלק מפתרון ה-Dynamics 365 הרחב.

- **מחבר ותשלום מתארח**: פעולות PayPlus טיפוסיות ויצירת קישור תשלום מתארח.
- **מנוע סנכרון רציף**: סנכרון מבוסס-הגדרות ו-Outbox של רשומות Dataverse (לקוחות, מוצרים, קטגוריות) ל-PayPlus, עם מיפוי שדות, טרנספורמציות, מסננים ומיפויי ערכים.
- **פקדי PCF**: Mapping Studio (מיפוי שדות ויזואלי והפעלת סנכרון) ו-Credit Card Wallet (ניהול כרטיסים מטוקנים).
- **טוקניזציה ושירות עצמי**: טוקניזציה ב-Hosted Fields, איסוף כרטיס בשירות עצמי באימייל, SMS ו-WhatsApp, וזיהוי טוקניזציה מבוסס-Polling.
- **הפקת מסמכים**: פעולות PayPlus Invoice+ / Books למסמכי מס כגון חשבוניות, קבלות ומסמכי זיכוי.

ראו [docs/he/architecture.md](docs/he/architecture.md) לארכיטקטורה המלאה, הטבלאות והדיאגרמות.

## מה הפתרון לא עושה

- אינו מעבד מספרי כרטיס אשראי גולמיים בתוך Power Platform.
- אינו שומר PAN, CVV או פרטי כרטיס מלאים ב-Dynamics 365, Dataverse, משתני Flow, Environment Variables או לוגים.
- אינו מחליף את PayPlus בתחום סליקה, הפקדה, ניהול סיכונים או הגדרות מסוף.
- אינו מחליף ERP, ספר ראשי או מערכת ניהול חייבים.
- אינו חושף פעולות חיוב ישיר עם פרטי כרטיס גולמיים בשלב הראשון.
- אינו מניח ש-Key Vault backed Environment Variables זמינים בכל tenant.
- אינו כולל שרת מתווך או Proxy ייעודי.
- אינו כולל מפתחות אמיתיים, סודות, מזהי tenant, מזהי חיבור, כתובות webhook אמיתיות או מזהי ייצור.

## הסבר למשתמש העסקי

אין צורך להבין API של PayPlus.

תהליך טיפוסי:

1. המשתמש יוצר בקשת תשלום מתוך Flow, אפליקציית Model-driven או תהליך ב-Dynamics 365.
2. המערכת קוראת למחבר PayPlus.
3. PayPlus מחזיר קישור תשלום.
4. המשתמש שולח את הקישור ללקוח, או שהמערכת שולחת אותו אוטומטית.
5. הלקוח משלם בדף התשלום המתארח של PayPlus.
6. המערכת יכולה לשמור קישור תשלום, מזהי PayPlus, סטטוס ושדות התאמה.
7. פרטי הכרטיס נשארים בדף PayPlus ואינם נשמרים ב-Dynamics 365 או Power Platform.

## תרחישים נתמכים

- יצירת קישור תשלום מתארח עבור לקוח.
- שימוש בסביבת Sandbox ובסביבת Production של PayPlus.
- שמירת פרטי הגישה ל-PayPlus כפרמטרים מאובטחים ברמת החיבור.
- הזרקת הכותרות `api-key` ו-`secret-key` באמצעות policies של המחבר.
- שליפת מסופים ודפי תשלום לצורך הגדרה או סיוע בבחירת ערכים.
- כתיבה חוזרת של מזהי בקשת תשלום וסטטוסים ל-Dataverse, אם נעשה בו שימוש.
- אימות חיבור באמצעות יצירת קישור תשלום מינימלי בסביבת בדיקות או ייצור.
- תמיכה בנתונים עסקיים בעברית ובאנגלית כאשר השדות ב-PayPlus וב-Dynamics תומכים בכך.

## מבנה הריפו

<div dir="ltr">

```text
.
├── README.md
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

</div>

## דרישות מקדימות

- סביבת Microsoft Power Platform עם הרשאה ליצור או לעדכן Custom Connectors.
- Dynamics 365 או Dataverse, אם שומרים רשומות תשלום ב-Dataverse.
- פרטי גישה לסביבת Sandbox של PayPlus לפיתוח ובדיקות.
- פרטי גישה לייצור של PayPlus לפני עליה לאוויר.
- מסוף ודף תשלום מוגדרים ב-PayPlus.
- סקירת DLP של Power Platform.
- אישור צוותי אבטחה, Governance ו-Compliance לפני ייצור.

## סביבות נתמכות

| סביבה | Host של PayPlus | שימוש |
| --- | --- | --- |
| Sandbox | `restapidev.payplus.co.il` | פיתוח ואימות |
| Production | `restapi.payplus.co.il` | פעילות תשלום חיה |

שתי הגדרות המחבר משתמשות בנתיב API בסיסי `/api/v1.0`.

## מסמכים מרכזיים

| נושא | אנגלית | עברית |
| --- | --- | --- |
| ארכיטקטורה | [docs/en/architecture.md](docs/en/architecture.md) | [docs/he/architecture.md](docs/he/architecture.md) |
| מדריך משתמש עסקי | [docs/en/business-user-guide.md](docs/en/business-user-guide.md) | [docs/he/business-user-guide.md](docs/he/business-user-guide.md) |
| אבטחה ותאימות | [docs/en/security-governance-and-compliance.md](docs/en/security-governance-and-compliance.md) | [docs/he/security-governance-and-compliance.md](docs/he/security-governance-and-compliance.md) |
| שיקולי PCI | [docs/en/pci-considerations.md](docs/en/pci-considerations.md) | [docs/he/pci-considerations.md](docs/he/pci-considerations.md) |
| תכנון המחבר | [docs/en/custom-connector-design.md](docs/en/custom-connector-design.md) | [docs/he/custom-connector-design.md](docs/he/custom-connector-design.md) |
| תוכנית בדיקות | [docs/en/test-plan.md](docs/en/test-plan.md) | [docs/he/test-plan.md](docs/he/test-plan.md) |
| פתרון תקלות | [docs/en/troubleshooting.md](docs/en/troubleshooting.md) | [docs/he/troubleshooting.md](docs/he/troubleshooting.md) |
| הנחות | [docs/en/assumptions.md](docs/en/assumptions.md) | [docs/he/assumptions.md](docs/he/assumptions.md) |

## עמדת אבטחה מרכזית

המחבר אינו מעבד כרטיסים בתוך Power Platform. הוא מפנה את הלקוח לדף תשלום מתארח של PayPlus. אין לחשוף במחבר פעולות שמקבלות PAN או CVV גולמיים, אלא אם הושלם תהליך סקירה ואישור PCI ייעודי.

## סודיות

הריפו אינו מכיל סודות אמיתיים, מפתחות API אמיתיים, מזהי חיבור אמיתיים, כתובות webhook אמיתיות או נתוני תשלום של לקוחות.

</div>
