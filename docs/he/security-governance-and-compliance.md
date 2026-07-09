# אבטחה, Governance ותאימות

## תחום המסמך

מסמך זה מיועד לסקירת אבטחה, סקר סיכונים, סקירת Governance, סקירת Compliance ואישור IT. הוא מתאר את מודל האבטחה עבור אינטגרציית מחבר PayPlus עם Microsoft Power Platform ו-Dynamics 365.

הפתרון משתמש בדפי תשלום מתארחים של PayPlus כנתיב התשלום הראשי. Power Platform יוצר ועוקב אחר בקשות תשלום אך אינו אוסף פרטי כרטיס גולמיים.

## סקירת מודל האבטחה

עקרון האבטחה המרכזי הוא הפרדת אחריות:

- Dynamics 365 ו-Dataverse מחזיקים רשומות עסקיות ומטא-דאטה של תשלום.
- Power Automate מתזמר בקשות וכתיבה חוזרת.
- Custom Connector קורא ל-PayPlus דרך פעולות מבוקרות.
- PayPlus מארח את דף התשלום ומעבד את פרטי הכרטיס.
- פרטי הגישה נשמרים ברמת החיבור ב-Power Platform ומוזרקים בזמן ריצה באמצעות policies.

## מיקום שמירת הסודות

`api-key` ו-`secret-key` של PayPlus נשמרים כפרמטרי חיבור של Custom Connector:

- `apiKey`: `securestring`
- `secretKey`: `securestring`

הערכים מוזנים בעת יצירת החיבור. הם אינם נשמרים כרשומות Dataverse, אינם מקודדים בתוך flows ואינם מועברים כפרמטרי פעולה רגילים.

## למה `apiKey` ו-`secretKey` מוגדרים כ-securestring connection parameters

תכנון זה משאיר את פרטי הגישה בגבול החיבור. הוא גם מתאים לאופן שבו משתמשים במחברים: בעל החיבור מזין את פרטי הגישה פעם אחת, וה-flows משתמשים ב-Connection Reference.

יתרונות:

- פרטי הגישה מוסתרים מקלטי הפעולה.
- פרטי הגישה אינם משוכפלים בין פעולות.
- פרטי הגישה אינם נשמרים כהגדרות Flow בטקסט גלוי.
- החלפת סודות מתבצעת באמצעות עדכון או יצירה מחדש של החיבור.

## למה המפתחות אינם פרמטרים בכל Action

הוספת `api-key` ו-`secret-key` לכל פעולה יוצרת סיכון מיותר:

- Makers עלולים להדביק מפתחות בתוך flows.
- מפתחות עלולים להופיע ב-Run history או בייצוא הגדרות.
- כל פעולה הייתה דורשת Secure Inputs.
- הסיכון לטעויות תפעוליות היה גבוה יותר.

גישת ה-policy מסירה שדות סוד מסכמות הפעולות העסקיות.

## למה המפתחות אינם String Environment Variables

Environment Variables מסוג String אינם מתאימים לסודות. קל יותר לצפות בהם, לייצא אותם או להשתמש בהם בצורה שגויה. לכן התכנון נמנע משמירת פרטי הגישה של PayPlus כ-String Environment Variables.

## למה Key Vault לא נבחר כברירת מחדל כרגע

נבחנה ארכיטקטורה של Secret Environment Variables מגובים ב-Key Vault. ב-POC, שליפת הסוד מ-Key Vault נחסמה כי ל-Key Vault הוגדר `publicNetworkAccess=Disabled` ולא היה נתיב רשת פרטי זמין ל-Power Platform.

ברירת המחדל הנוכחית היא secure connection parameters. ניתן לשקול Key Vault מחדש כאשר קיים תכנון רשת פרטי מאושר או החרגת Policy.

## חסם `publicNetworkAccess=Disabled`

כאשר נאכף `publicNetworkAccess=Disabled` על Key Vault, הגישה הציבורית ל-data plane נחסמת. Dataverse או Power Platform לא יכולים לפתור סודות של Environment Variables מגובים ב-Key Vault אלא אם קיים נתיב רשת פרטי מאושר, כגון Private Endpoint ושילוב נתמך.

זהו חסם Governance ורשת, לא תקלה במחבר PayPlus.

## אין שימוש ב-raw credit card או CVV

הנתיב הראשי של הפתרון אינו מקבל PAN או CVV גולמיים. הלקוחות מזינים פרטי כרטיס בדף התשלום המתארח של PayPlus.

The connector must not expose operations that accept raw PAN or CVV unless a dedicated PCI review and approval process is completed.

## שיקולי PCI

דפוס דף התשלום המתארח מצמצם חשיפה ל-PCI כי הזנת הכרטיס מתבצעת ב-PayPlus. Power Platform עדיין דורש Governance כי הוא עשוי לשמור מטא-דאטה של תשלום ולהריץ flows שמכילים מזהי לקוח, קישורי תשלום, מזהי עסקה, טוקנים או payload של סטטוס.

עמדת PCI נדרשת:

- לא לאסוף PAN ב-Power Platform.
- לא לאסוף או לשמור CVV בשום צורה.
- להתייחס לטוקנים כמידע רגיש.
- לבדוק Run history, לוגים, ייצוא וגישת תמיכה.
- לאשר את תאימות דף התשלום של PayPlus דרך מסמכי ספק.

## שיקולי Run History

Power Automate Run History יכול לשמור קלטים ופלטים של פעולות. Flows חייבים להימנע לחלוטין מפרטי כרטיס גולמיים ולהפעיל Secure Inputs ו-Secure Outputs עבור פעולות שמכילות מטא-דאטה רגיש או טוקנים.

יש לבדוק:

- קלטים של Trigger.
- קלטים ופלטים של פעולות מחבר.
- פעולות Compose.
- משתנים.
- ענפי טיפול בשגיאות.
- הערות אישור ודוא"ל.

## Secure Inputs ו-Secure Outputs

יש להשתמש ב-Secure Inputs ו-Secure Outputs כאשר מטפלים ב:

- טוקנים של PayPlus.
- מזהי לקוח אם הם מסווגים כרגישים.
- קישורי תשלום אם מדיניות הארגון מסווגת אותם כרגישים.
- הודעות שגיאה שעלולות להחזיר ערכים מהבקשה.

Secure Inputs ו-Secure Outputs מפחיתים חשיפה ב-Run history אך אינם מחליפים צמצום נתונים נכון.

## DLP Policy

יש לסווג את המחבר לפי מודל DLP של הארגון. בקרות מומלצות:

- לשייך PayPlus, Dataverse, Office 365 ומחברי תקשורת מאושרים לקבוצת Business Data מתאימה.
- לחסום מחברים לא מנוהלים או צרכניים ב-flows שמטפלים בתשלומים.
- להשתמש במדיניות נפרדת לפיתוח ולייצור.
- לבדוק מחברים המשמשים להתראות, ייצוא ולוגים.

## Least Privilege

יש ליישם Least Privilege עבור:

- Makers שיכולים לערוך את המחבר.
- בעלי Connections ל-PayPlus.
- משתמשים שיכולים להריץ flows של תשלום.
- משתמשים שיכולים לצפות ב-Run history.
- משתמשים שיכולים לקרוא טבלאות תשלום ב-Dataverse.
- מנהלים שיכולים לייצא Solutions.

## Connection Ownership

Connections בייצור צריכים להיות בבעלות Service Owner מאושר או חשבון מנהל מבוקר, בהתאם למדיניות ה-tenant. מומלץ להימנע מבעלות אישית על flows של תשלומים בייצור.

יש לתעד:

- בעל החיבור.
- בעל פרטי הגישה.
- בעל תהליך החלפת סודות.
- תהליך חירום.
- מסלול אישורים.

## הפרדת סביבות

יש להשתמש בסביבות ופרטי גישה נפרדים:

| סביבה | מטרה | סוג פרטי גישה |
| --- | --- | --- |
| Development | פיתוח ובדיקות יחידה | PayPlus Sandbox |
| Test/UAT | אימות עסקי | PayPlus Sandbox או merchant בדיקות מבוקר |
| Production | תשלומים חיים | PayPlus Production |

אין להשתמש בפרטי ייצור בסביבת פיתוח.

## Secret Rotation

הליך החלפת סודות:

1. קבלת פרטי גישה חדשים דרך תהליך PayPlus מאושר.
2. עדכון או יצירה מחדש של Connection במחבר.
3. קישור מחדש של Connection References אם נוצר חיבור חדש.
4. הרצת אימות ב-Sandbox או אימות ייצור מבוקר.
5. השבתת פרטי הגישה הישנים.
6. תיעוד ההחלפה בלוג תפעולי.

## Auditing and Monitoring

תחומי ביקורת מומלצים:

- שינויי הגדרת המחבר.
- יצירת Connections ושינוי בעלות.
- שינויי Flow וייבוא Solutions.
- יצירת בקשות תשלום.
- עדכוני סטטוס תשלום.
- קריאות PayPlus שנכשלו.
- נפח חריג או כשלים חוזרים.
- עקיפות ידניות.

## Incident Response

תהליך תגובה לאירוע צריך להגדיר:

- איך משביתים flows של תשלום.
- איך מחליפים פרטי גישה של PayPlus.
- מי פונה ל-PayPlus.
- איך מזהים בקשות תשלום מושפעות.
- איך משמרים לוגים בלי לחשוף מידע רגיש.
- איך מעדכנים אבטחה, Compliance, כספים ובעלי תהליך עסקי.

## Known Residual Risks

| סיכון | מענה |
| --- | --- |
| קישור תשלום עשוי לעבור הלאה | תפוגה, בקרות עסקיות, הגדרות PayPlus ואימות לקוח לפי צורך |
| Run history עשוי לחשוף מטא-דאטה | צמצום נתונים, Secure Inputs/Outputs והרשאות צפייה מוגבלות |
| בעל Connection יכול להשפיע על יכולת תשלום | בעלות מבוקרת ותהליך החלפת סודות מתועד |
| בחירת סביבה שגויה | מחברים נפרדים, שמות ברורים ואימות לפני ייצור |
| טוקנים עשויים להיות רגישים | טיפול בטוקנים כסודות או מידע רגיש והגבלת גישה |
| רגרסיות Designer במחבר | בדיקות רגרסיה ליצירת פעולה לאחר שינוי מחבר |

## Required Controls Before Production

- אישור אבטחה הושלם.
- סקירת Compliance הושלמה.
- עמדת PCI אושרה.
- DLP Policy אושר והוחל.
- בעל Connection בייצור אושר.
- תהליך החלפת סודות תועד.
- Run history נבדק.
- הרשאות Dataverse נבדקו.
- תהליך סטטוס קישור תשלום נבדק.
- תהליך כשל ו-Rollback נבדק.
- אין פעולות שחושפות PAN או CVV גולמיים.

## Approval Checklist

| בקרה | בעלים | סטטוס |
| --- | --- | --- |
| אישור ארכיטקטורה | ארכיטקטורת פתרונות | Pending |
| אישור מודל אבטחה | אבטחה | Pending |
| אישור עמדת PCI | Compliance / בעל PCI | Pending |
| אישור DLP Policy | Power Platform Governance | Pending |
| אישור פרטי גישה לייצור | PayPlus / בעלים פיננסי | Pending |
| אישור בעלות Connection | IT Operations | Pending |
| סקירת Run history | מנהל Power Platform | Pending |
| סקירת הרשאות Dataverse | מנהל Dynamics | Pending |
| בדיקת Incident Response | Security Operations | Pending |
| אישור Go-live | בעל תהליך עסקי | Pending |
