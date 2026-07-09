# מודל נתונים ב-Dataverse

## תחום המסמך

מודל נתונים זה הוא אופציונלי אך מומלץ כאשר היישום דורש מעקב תשלומים, התאמות, תמיכה, ביקורת או רשומת בקשת תשלום עסקית.

השמות הלוגיים משתמשים בקידומת ניטרלית `pp_`. בעת יישום יש להחליף אותה בקידומת Publisher של הלקוח.

## כללי שמירת נתונים

- לשמור מטא-דאטה, מזהים, סטטוסים וקישורים של תשלום כאשר הדבר מאושר.
- לא לשמור PAN.
- לא לשמור CVV.
- להתייחס לטוקנים כמידע רגיש ולשמור אותם רק לאחר אישור אבטחה.
- לא לשמור API keys או secret keys של PayPlus בטבלאות Dataverse.
- להימנע משמירת payload מלא של PayPlus אלא אם הוא מסווג, מצומצם ומוגן בהרשאות.

## טבלה: Payment Request

| מאפיין | ערך |
| --- | --- |
| שם לוגי | `pp_paymentrequest` |
| שם תצוגה באנגלית | Payment Request |
| שם תצוגה בעברית | בקשת תשלום |
| מטרה | ייצוג בקשה עסקית לגביית תשלום דרך PayPlus |

### שדות מרכזיים

| שדה | סוג | רגיש | מותר לשמור | הערות |
| --- | --- | --- | --- | --- |
| `pp_name` | טקסט | לא | כן | מספר או כותרת בקשה ידידותית |
| `pp_customerid` | Lookup | כן | כן | קישור ל-Account, Contact או טבלת לקוח |
| `pp_amount` | Currency/Decimal | לא | כן | סכום לגבייה |
| `pp_currencycode` | Choice/Text | לא | כן | ILS, USD, EUR, GBP לפי אישור |
| `pp_terminaluid` | טקסט | נמוך | כן | UUID של מסוף PayPlus, לא סוד |
| `pp_paymentpageuid` | טקסט | נמוך | כן | מזהה דף תשלום, לא סוד אך לא לפרסום מיותר |
| `pp_paymentlink` | URL | בינוני | כן | להתייחס כרגיש אם הקישור מאפשר תשלום |
| `pp_pagerequestuid` | טקסט | נמוך | כן | מזהה בקשת דף ב-PayPlus |
| `pp_status` | Choice | לא | כן | סטטוס מחזור חיים עסקי |
| `pp_expireson` | DateTime | לא | כן | תפוגת קישור אם קיימת |
| `pp_senton` | DateTime | לא | כן | מועד שליחת קישור |
| `pp_paidon` | DateTime | לא | כן | מועד השלמת תשלום |
| `pp_correlationid` | טקסט | נמוך | כן | מזהה קורלציה של Flow או עסק |
| `pp_lastmessage` | טקסט | בינוני | כן | הודעה מסוננת בלבד |

### קשרים

- הרבה Payment Requests ל-Account או Contact אחד.
- Payment Request אחד להרבה Payment Transactions.
- Payment Request אחד להרבה Payment Events / Webhook Logs.

### סטטוסים

- Draft
- Link Created
- Sent
- Paid
- Failed
- Expired
- Cancelled
- Refunded
- Pending Review

### הערות אבטחה

קישור תשלום עשוי להיות רגיש כי מי שמחזיק בו עשוי לבצע ניסיון תשלום, בהתאם להגדרות PayPlus. יש להגביל גישה למשתמשים עסקיים שזקוקים לכך.

## טבלה: Payment Transaction

| מאפיין | ערך |
| --- | --- |
| שם לוגי | `pp_paymenttransaction` |
| שם תצוגה באנגלית | Payment Transaction |
| שם תצוגה בעברית | עסקת תשלום |
| מטרה | שמירת מטא-דאטה של עסקת PayPlus לצורך התאמה ותמיכה |

### שדות מרכזיים

| שדה | סוג | רגיש | מותר לשמור | הערות |
| --- | --- | --- | --- | --- |
| `pp_name` | טקסט | לא | כן | שם תצוגה לעסקה |
| `pp_paymentrequestid` | Lookup | לא | כן | בקשת תשלום אב |
| `pp_transactionuid` | טקסט | נמוך | כן | מזהה עסקה ב-PayPlus, מומלץ כ-Alternate Key |
| `pp_pagerequestuid` | טקסט | נמוך | כן | מזהה בקשת קישור |
| `pp_status` | Choice | לא | כן | סטטוס עסקה |
| `pp_amount` | Currency/Decimal | לא | כן | סכום ששולם, זוכה או נוסה |
| `pp_currencycode` | Choice/Text | לא | כן | מטבע |
| `pp_approvalnumber` | טקסט | בינוני | כן | אסמכתת אישור או שובר אם חזרה |
| `pp_cardlast4` | טקסט | בינוני | כן, אם אושר | ארבע ספרות אחרונות בלבד, לעולם לא PAN מלא |
| `pp_cardbrand` | טקסט | נמוך | כן, אם אושר | מותג כרטיס בלבד |
| `pp_cardexpiry` | טקסט | בינוני | עדיף להימנע | לשמור רק אם אושר במדיניות |
| `pp_tokenreference` | טקסט | גבוה | רק באישור | מזהה או כינוי טוקן, לא פרטי כרטיס |
| `pp_rawresponse` | Multiline text | גבוה | עדיף להימנע | רק אם מצומצם ומוגן בהרשאות |
| `pp_lastcheckedon` | DateTime | לא | כן | בדיקת התאמה אחרונה |

### קשרים

- הרבה Payment Transactions ל-Payment Request אחד.
- הרבה Payment Events ל-Payment Transaction אחד.

### סטטוסים

- Pending
- Approved
- Declined
- Failed
- Cancelled
- Refunded
- Partially Refunded
- Chargeback
- Unknown

### הערות אבטחה

לא לשמור כברירת מחדל תגובות PayPlus מלאות. יש לחלץ רק שדות נדרשים. שמירת טוקנים דורשת אישור מפורש.

## טבלה: Payment Provider Configuration

| מאפיין | ערך |
| --- | --- |
| שם לוגי | `pp_paymentproviderconfiguration` |
| שם תצוגה באנגלית | Payment Provider Configuration |
| שם תצוגה בעברית | הגדרת ספק תשלום |
| מטרה | שמירת קונפיגורציה שאינה סודית ומצב הגדרה של PayPlus |

### שדות מרכזיים

| שדה | סוג | רגיש | מותר לשמור | הערות |
| --- | --- | --- | --- | --- |
| `pp_name` | טקסט | לא | כן | שם הגדרה, לרוב רשומה יחידה |
| `pp_environment` | Choice | לא | כן | Sandbox או Production |
| `pp_defaultterminaluid` | טקסט | נמוך | כן | מסוף ברירת מחדל אופציונלי |
| `pp_defaultpaymentpageuid` | טקסט | נמוך | כן | דף תשלום ברירת מחדל אופציונלי |
| `pp_connectionverified` | Boolean | לא | כן | תוצאת אימות חיבור אחרונה |
| `pp_lastvalidationstatus` | Choice | לא | כן | Pending, Success, Failed |
| `pp_lastvalidationcode` | Integer | לא | כן | קוד סטטוס או שגיאה מסונן |
| `pp_lastvalidationmessage` | טקסט | בינוני | כן | מסונן בלבד |
| `pp_lastvalidatedon` | DateTime | לא | כן | מועד אימות אחרון |
| `pp_setupstage` | Choice | לא | כן | Connect, Pages, Validate, Done |

### קשרים

- הגדרה אחת יכולה לשמש flows ומסכי הגדרה.
- אין לקשר סודות לטבלה זו.

### סטטוסים

- Not Started
- Pending
- Success
- Failed
- Disabled

### הערות אבטחה

לא לשמור בטבלה זו `api-key`, `secret-key`, client secrets, SAS URLs או ערכי Key Vault secrets.

## טבלה: Payment Page Cache

| מאפיין | ערך |
| --- | --- |
| שם לוגי | `pp_paymentpagecache` |
| שם תצוגה באנגלית | Payment Page Cache |
| שם תצוגה בעברית | מטמון דפי תשלום |
| מטרה | שמירת מטמון של דפי תשלום מ-PayPlus לצורך הגדרה ובחירה |

### שדות מרכזיים

| שדה | סוג | רגיש | מותר לשמור | הערות |
| --- | --- | --- | --- | --- |
| `pp_name` | טקסט | לא | כן | שם דף תשלום |
| `pp_paymentpageuid` | טקסט | נמוך | כן | UID של דף PayPlus |
| `pp_terminaluid` | טקסט | נמוך | כן | UID של מסוף האב |
| `pp_terminalname` | טקסט | לא | כן | שם מסוף ידידותי |
| `pp_valid` | Boolean/Choice | לא | כן | דגל פעיל או תקף מ-PayPlus |
| `pp_currencycode` | טקסט | לא | כן | מטבע ברירת מחדל אם חוזר |
| `pp_lastrefreshedon` | DateTime | לא | כן | מועד רענון מטמון |
| `pp_rawmetadata` | Multiline text | בינוני | עדיף להימנע | לשמור רק מטא-דאטה מסונן |

### קשרים

- הרבה Payment Page Cache ל-Terminal Cache אחד.
- Payment Requests יכולים להפנות לרשומת Payment Page Cache.

### סטטוסים

- Active
- Inactive
- Unknown

### הערות אבטחה

Payment page UID אינו סוד, אך הוא קונפיגורציה תפעולית שיש לנהל בזהירות.

## טבלה: Terminal Cache

| מאפיין | ערך |
| --- | --- |
| שם לוגי | `pp_terminalcache` |
| שם תצוגה באנגלית | Terminal Cache |
| שם תצוגה בעברית | מטמון מסופים |
| מטרה | שמירת אפשרויות מסוף של PayPlus לצורך הגדרה ואימות |

### שדות מרכזיים

| שדה | סוג | רגיש | מותר לשמור | הערות |
| --- | --- | --- | --- | --- |
| `pp_name` | טקסט | לא | כן | שם תצוגה למסוף |
| `pp_terminaluid` | טקסט | נמוך | כן | UUID של מסוף PayPlus |
| `pp_terminaltypeid` | Integer/Text | לא | כן | אם חוזר |
| `pp_merchantnumber` | טקסט | בינוני | כן, אם אושר | עשוי להיחשב רגיש לפי מדיניות |
| `pp_status` | Choice/Integer | לא | כן | פעיל או לא פעיל |
| `pp_lastrefreshedon` | DateTime | לא | כן | מועד רענון מטמון |

### קשרים

- Terminal Cache אחד להרבה Payment Page Cache.
- Payment Requests יכולים להפנות לרשומת Terminal Cache.

### סטטוסים

- Active
- Inactive
- Unknown

### הערות אבטחה

Terminal UID הוא קונפיגורציה תפעולית ולא Credential. אין לשמור כאן API keys ברמת מסוף.

## טבלה: Payment Event / Webhook Log

| מאפיין | ערך |
| --- | --- |
| שם לוגי | `pp_paymenteventlog` |
| שם תצוגה באנגלית | Payment Event / Webhook Log |
| שם תצוגה בעברית | לוג אירועי תשלום / Webhook |
| מטרה | שמירת אירועי תשלום נכנסים, אירועי שליפת סטטוס ותוצאות עיבוד |

### שדות מרכזיים

| שדה | סוג | רגיש | מותר לשמור | הערות |
| --- | --- | --- | --- | --- |
| `pp_name` | טקסט | לא | כן | שם תצוגה לאירוע |
| `pp_eventtype` | Choice/Text | לא | כן | Webhook, status pull, manual refresh |
| `pp_paymentrequestid` | Lookup | לא | כן | בקשה קשורה |
| `pp_paymenttransactionid` | Lookup | לא | כן | עסקה קשורה אם ידועה |
| `pp_eventtime` | DateTime | לא | כן | זמן האירוע |
| `pp_signaturevalid` | Boolean | לא | כן | אם קיים אימות חתימת webhook |
| `pp_processingstatus` | Choice | לא | כן | Received, Processed, Failed, Ignored |
| `pp_correlationid` | טקסט | נמוך | כן | קורלציה של Flow או הודעה |
| `pp_sanitizedpayload` | Multiline text | גבוה | רק אם אושר | לצמצם או להימנע מ-payload גולמי |
| `pp_errormessage` | Multiline text | בינוני | כן | סיבת כשל מסוננת |

### קשרים

- הרבה אירועים ל-Payment Request אחד.
- הרבה אירועים ל-Payment Transaction אחד.

### סטטוסים

- Received
- Signature Failed
- Processed
- Failed
- Ignored
- Duplicate

### הערות אבטחה

שמירת payload של webhook חייבת לעבור סקירה לפני ייצור. עדיף לשמור שדות מפוענחים ונדרשים במקום payload גולמי.

## Alternate Keys מומלצים

| טבלה | Alternate key |
| --- | --- |
| Payment Request | `pp_pagerequestuid` כאשר זמין |
| Payment Transaction | `pp_transactionuid` |
| Terminal Cache | `pp_terminaluid` |
| Payment Page Cache | `pp_paymentpageuid` |
| Payment Event Log | מזהה אירוע חיצוני או hash, אם קיים |

## שאלות פתוחות

- יש לאשר את טבלאות Dynamics 365 המדויקות עבור לקוחות, הזמנות, חשבוניות או פניות בכל יישום.
- שמירת מזהי טוקן תלויה באישור PCI ואבטחה.
- שמירת payload של webhook תלויה בדרישות סיווג ושמירת מידע.
