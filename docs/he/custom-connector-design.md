# תכנון Custom Connector

## מטרת המסמך

מסמך זה מתאר את התכנון הטכני של מחבר PayPlus עבור Microsoft Power Platform.

## Auth model

המחבר מוגדר כ-No Auth בהגדרת האבטחה של Custom Connector. ההזדהות מול PayPlus מיושמת באמצעות פרמטרי חיבור מאובטחים ו-policies.

סיבות:

- PayPlus דורש שתי כותרות: `api-key` ו-`secret-key`.
- API Key Auth מובנה אינו מתאים היטב לשני headers עצמאיים.
- מפתחות כקלט לכל פעולה יחשפו סודות ל-Makers ול-Run history.

## Connection parameters

מוגדרים ב-`apiProperties.json`:

| שם | סוג | חובה | טקסט גלוי | מטרה |
| --- | --- | --- | --- | --- |
| `apiKey` | `securestring` | כן | לא | מפתח API של PayPlus |
| `secretKey` | `securestring` | כן | לא | מפתח סודי של PayPlus |

פרמטרי החיבור מוזנים בעת יצירת ה-Connection ב-Power Platform. הם אינם מופיעים כקלטים רגילים של פעולה.

## Policies

המחבר משתמש בשני request policies:

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

Policy נוסף מזריק `secret-key` מתוך `@connectionParameters('secretKey')`.

ב-POC אומת כי `@connectionParameters('secretParam')` נפתר בזמן ריצה בתוך `setheader` policy.

## Actions

קבוצות הפעולות הקיימות במחבר כוללות:

| תחום | פעולות |
| --- | --- |
| דפי תשלום | `GeneratePaymentLink`, `ListPaymentPages` |
| Discovery | `MyTerminals` |
| לקוחות | `CreateCustomer`, `UpdateCustomer`, `ViewCustomers`, `RemoveCustomer` |
| עסקאות | `ViewTransactions`, `CancelTransaction`, `RefundByTransaction`, `ChargeByTransactionUid`, `ChargeSavedCard` |
| הוראות קבע | `CreateRecurringPayment` |
| מוצרים | `CreateProduct`, `UpdateProduct`, `ViewProducts` |
| קטגוריות | `CreateProductCategory`, `UpdateProductCategory`, `ViewProductCategories` |

הפעולה העסקית המרכזית היא `GeneratePaymentLink`.

## Internal actions

ניתן לסמן את `ListPaymentPages` כ-internal כאשר היא משמשת רק למילוי ערכי dropdown. ניתן גם להשאיר אותה גלויה לצורך פתרון תקלות או אימות הגדרה.

פעולות עזר או internal לא צריכות לחשוף סודות או שדות כרטיס גולמיים.

## Dynamic dropdowns

דפוס שאומת ב-POC:

- `MyTerminals` מחזיר מערך ישיר. להשתמש ב-`x-ms-dynamic-values` עם `value-path` = `uuid` ו-`value-title` = `name_terminal`.
- `ListPaymentPages` מחזיר תגובה עטופה עם `data`. להשתמש ב-`x-ms-dynamic-list` לבחירת דף תשלום תלויה כאשר נדרש ערך מסוף.
- `payment_page_uid` צריך להיפתר מתוך `ListPaymentPages` עם `itemValuePath` = `uid` ו-`itemTitlePath` = `name`.

## Known designer limitation

Designer החדש של Power Automate עלול להחזיר `409 Error fetching manifest` כאשר dropdown תלוי משתמש ב-`x-ms-dynamic-values` ומקור הרשימה דורש פרמטר.

תוצאת POC:

- dropdown תלוי באמצעות `x-ms-dynamic-values` גרם ל-409.
- `x-ms-dynamic-list` מנע את ה-409 עבור בחירת דף התשלום התלויה.
- Action nodes קיימים עלולים להישאר שבורים לאחר עדכון מחבר. יש למחוק את ה-Action, לבצע רענון קשיח ולהוסיף אותו מחדש.

## Error handling

המלצות לטיפול בשגיאות במחבר וב-flows:

- להגדיר סכמות תגובה מוכרות להצלחה.
- לשמור status code, וכן `results.status`, `results.code`, `results.description` של PayPlus כאשר הם קיימים.
- לא להניח שכל כשל PayPlus מחזיר JSON מובנה.
- להבחין בין 403 ל-502 בזמן פתרון תקלות.
- להגדיר retry policy בזהירות ב-flows של אימות כדי להיכשל מהר.
- לשמור פרטי כשל מסוננים ב-Dataverse.

## Naming conventions

המלצות שמות:

| פריט | Convention |
| --- | --- |
| Operation IDs | PascalCase עסקי, לדוגמה `GeneratePaymentLink` |
| כותרת מחבר | `PayPlus` לייצור, `PayPlus Sandbox` לבדיקה |
| Connection parameters | camelCase, לדוגמה `apiKey`, `secretKey` |
| Headers | שמות PayPlus המדויקים: `api-key`, `secret-key` |
| קידומת Dataverse | קידומת לקוח או Publisher, לדוגמה `alex_` ב-POC |
| שמות Flow | `PayPlus - <Business Purpose>` |

## Dev/Prod endpoints

| סביבה | Host | נתיב בסיס |
| --- | --- | --- |
| Sandbox | `restapidev.payplus.co.il` | `/api/v1.0` |
| Production | `restapi.payplus.co.il` | `/api/v1.0` |

יש לשמור הגדרות מחבר ו-Connections נפרדים לכל סביבה.

## כיצד לארוז ולפרוס

שלבי פריסה טיפוסיים:

1. לשמור את הגדרת המחבר ואת apiProperties ב-source control.
2. לאמת תקינות JSON.
3. לייבא או לעדכן את המחבר בסביבת פיתוח.
4. ליצור Connection ולהזין פרטי PayPlus.
5. לקשר Connection References ב-Solution.
6. לייבא flows ורכיבי Dataverse.
7. להריץ אימות Sandbox.
8. לייצא Managed Solution לסביבות גבוהות יותר.
9. ליצור או לקשר Connections לפי סביבה בזמן import.
10. להריץ אימות Production לאחר אישור.

בפריסה עם PAC CLI, הדפוס הוא עדכון מחבר עם קובץ API definition וקובץ API properties.

## כיצד לבדוק

רמות בדיקה:

- אימות JSON לקבצי המחבר.
- בדיקת import או update למחבר.
- בדיקת יצירת Connection.
- בדיקת ריצה של `MyTerminals`.
- בדיקת ריצה של `ListPaymentPages` עם `terminal_uid`.
- בדיקת `GeneratePaymentLink` ב-Sandbox עם גוף בקשה מלא.
- בדיקת Designer: יצירת Action חדש ואימות התנהגות dropdowns.
- בדיקת Run history לערכים רגישים.
- בדיקות שליליות למפתח שגוי, מסוף שגוי, דף תשלום שגוי, סכום ומטבע.

## שאלות פתוחות

- יש לאשר סכמות OpenAPI מדויקות של PayPlus לפני הרחבת פעולות נוספות.
- פעולות מסוימות עשויות לדרוש מודול פעיל ב-PayPlus.
- פעולות מבוססות טוקן דורשות סקירת אבטחה ו-PCI לפני שימוש בייצור.
