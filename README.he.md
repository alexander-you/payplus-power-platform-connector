# מחבר PayPlus עבור Microsoft Power Platform ו-Dynamics 365

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

## תרחישים שאינם נתמכים בשלב הראשון

- איסוף PAN או CVV ב-Power Automate, Dynamics 365, Dataverse או פעולות המחבר.
- חיוב ישיר של כרטיס שהוזן ידנית.
- קריאות מהדפדפן ישירות ל-REST API של PayPlus.
- שימוש ב-Key Vault backed Environment Variables כברירת מחדל, עקב חסמי רשת ידועים בחלק מסביבות Enterprise.
- שרת מתווך או Proxy.
- אוטומציה מלאה של חשבוניות, קבלות, הפקדות או רישום ERP, אלא אם תתווסף בשלב עתידי.
- שימוש בייצור ללא בדיקות אבטחה, Governance, PCI, Run history, DLP ואישורים נדרשים.

## מבנה הריפו

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

## התחלה מהירה

1. קראו את מסמכי הארכיטקטורה והאבטחה לפני ייבוא רכיבים לסביבה.
2. ייבאו או עדכנו את המחבר מתוך `connector/apiDefinition.sandbox.json` ו-`connector/sandbox/apiProperties.json` בסביבת פיתוח.
3. צרו Connection למחבר והזינו בדיאלוג החיבור את `api-key` ואת `secret-key` של PayPlus.
4. בדקו תחילה עם פרטי Sandbox ודף תשלום Sandbox.
5. בנו Flow שקורא ל-`GeneratePaymentLink` עם סכום, מטבע, מסוף, מזהה דף תשלום, לקוח ופריטים.
6. שמרו ב-Dataverse רק מטא-דאטה שאינו פרטי כרטיס.
7. לאחר אישור, חזרו על תהליך הפריסה עבור ייצור.

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
| הנחות ושאלות פתוחות | [docs/en/assumptions-and-open-questions.md](docs/en/assumptions-and-open-questions.md) | [docs/he/assumptions-and-open-questions.md](docs/he/assumptions-and-open-questions.md) |

## עמדת אבטחה מרכזית

המחבר אינו מעבד כרטיסים בתוך Power Platform. הוא מפנה את הלקוח לדף תשלום מתארח של PayPlus. אין לחשוף במחבר פעולות שמקבלות PAN או CVV גולמיים, אלא אם הושלם תהליך סקירה ואישור PCI ייעודי.

## הנחות ושאלות פתוחות

- יש לאמת סכמות תגובה מדויקות מול OpenAPI רשמי או תגובות Sandbox לפני הרחבת כיסוי המחבר.
- טיפול ב-webhook או IPN תלוי יישום ודורש בדיקת חתימה, מניעת Replay, לוגים וטיפול בכשל.
- חיוב מבוסס טוקן עשוי להישקל בעתיד רק לאחר סקירת אבטחה ו-PCI ייעודית.

## סודיות

הריפו אינו מכיל סודות אמיתיים, מפתחות API אמיתיים, מזהי חיבור אמיתיים, כתובות webhook אמיתיות או נתוני תשלום של לקוחות.
