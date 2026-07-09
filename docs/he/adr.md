# מסמך החלטות ארכיטקטורה

מסמך זה מרכז את החלטות הארכיטקטורה המרכזיות עבור מחבר PayPlus ב-Power Platform.

## ADR-001: שימוש ב-No Auth בהגדרת המחבר

### Context

PayPlus דורש שתי כותרות בקשה: `api-key` ו-`secret-key`. מודל API Key המובנה ב-Custom Connector של Power Platform מתאים בעיקר למפתח אחד ואינו ממדל היטב שני headers נפרדים.

### Decision

להגדיר את המחבר כ-No Auth מנקודת המבט של Custom Connector. את פרטי הגישה של PayPlus יש להגדיר כפרמטרי חיבור מאובטחים ולהזריק את הכותרות הנדרשות באמצעות policies.

### Consequences

- החיבור ב-Power Platform עדיין מכיל פרטי גישה, אך הם אינם מוגדרים כמנגנון Auth מובנה.
- יוצרי Flow אינם רואים שדות מפתח בכל פעולה.
- התנהגות ההזדהות נשלטת על ידי apiProperties ו-policies.
- מתחזקי המחבר חייבים לשמר את ה-policies בפריסה.

### Alternatives Considered

- API Key Auth מובנה: נדחה כי אינו מתאים היטב לדרישת שני המפתחות של PayPlus.
- Headers כקלט בכל פעולה: נדחה כי הוא חושף סודות בסכמה ובהיסטוריית ריצות.
- שרת מתווך: נדחה לשלב עתידי בגלל עלויות תפעול, אבטחה ותחזוקה.

## ADR-002: שימוש ב-securestring connection parameters

### Context

המחבר צריך לשמור את `api-key` ואת `secret-key` של PayPlus כך שיוזנו פעם אחת לכל חיבור ויוסתרו מיוצרי Flow ומקלטי פעולה.

### Decision

להשתמש בפרמטרי חיבור מסוג `securestring` בשם `apiKey` ו-`secretKey`.

### Consequences

- פרטי הגישה מוזנים בעת יצירת החיבור.
- פרטי הגישה אינם מופיעים בכל payload של פעולה.
- בעלי החיבור מנהלים החלפת סודות באמצעות עדכון או יצירה מחדש של החיבור.
- ערכי secure אינם ניתנים לקריאה חוזרת דרך APIs רגילים של המחבר.

### Alternatives Considered

- Environment Variables מסוג String: נדחה כי אינן מתאימות לסודות.
- Secret Environment Variables מגובים ב-Key Vault: נדחה לשלב עתידי עקב חסמי רשת.
- שדות בטבלת Dataverse: נדחה כי אין לשמור סודות בטבלאות עסקיות.

## ADR-003: הזרקת Headers באמצעות Policies

### Context

PayPlus מצפה לכותרות `api-key` ו-`secret-key` בכל קריאת API.

### Decision

להשתמש ב-policies מסוג `setheader`:

- `api-key` = `@connectionParameters('apiKey')`
- `secret-key` = `@connectionParameters('secretKey')`

### Consequences

- הזרקת הכותרות מרוכזת במקום אחד.
- הפעולות נשארות נקיות ואינן חושפות פרמטרי סוד.
- ב-POC אומת שפרמטרי חיבור נפתרים בזמן ריצה בתוך policy.
- בדיקות חייבות לכלול בדיקת request inspector עם סודות דמה בלבד.

### Alternatives Considered

- הוספת headers לכל פעולה: נדחה בגלל חשיפת סודות ותחזוקה מיותרת.
- Custom code policy: לא נדרש להזרקת headers פשוטה.
- הזרקה בשרת מתווך: נדחה.

## ADR-004: לא להשתמש ב-Key Vault backed Environment Variables כברירת מחדל בשלב הנוכחי

### Context

Secret Environment Variables מגובים ב-Key Vault הם אפשרות טובה ל-Governance ארגוני, אך ב-POC נמצא חסם רשת: `publicNetworkAccess=Disabled` ב-Key Vault מנע מ-Dataverse או Power Platform לקרוא את הסוד ללא תכנון רשת פרטי נוסף.

### Decision

לא להשתמש ב-Key Vault backed Environment Variables כדרך ברירת המחדל לשמירת פרטי הגישה של המחבר בשלב זה.

### Consequences

- הארכיטקטורה עוקפת את חסם הרשת הנוכחי של Key Vault.
- הסודות מנוהלים ברמת החיבור ב-Power Platform.
- ארגונים שדורשים Key Vault יכולים להוסיף זאת בעתיד באמצעות Private Endpoint, שילוב VNet, החרגת Policy או תבנית Middleware מנוהלת.

### Alternatives Considered

- Key Vault backed Environment Variables: נדחה עד לאישור ובדיקה של נתיב הרשת.
- Public Key Vault allowlist: נדחה כי דורש אישור אבטחה ובקרות רשת לפי tenant.
- Middleware עם Managed Identity: נדחה עד שתהיה הצדקה עסקית למורכבות.

## ADR-005: לא להוסיף שרת מתווך בשלב הראשון

### Context

שרת מתווך יכול לרכז סודות, חתימה, אימות IPN, ניסיונות חוזרים וניטור. מצד שני הוא מוסיף אירוח, ניטור, פריסה, זהות ותפעול.

### Decision

להשתמש בארכיטקטורה ממוקדת מחבר ודלת-קוד ללא שרת מתווך בשלב הראשון.

### Consequences

- יישום מהיר יותר ופחות עומס תפעולי.
- Power Platform נשארת שכבת האינטגרציה המרכזית.
- בקרות מתקדמות, כגון אימות IPN מורכב או Token Vault, עשויות לדרוש שירות עתידי.

### Alternatives Considered

- Azure Function Proxy: נדחה.
- חזית API Management: נדחה.
- Logic Apps Standard או שירות ייעודי: נדחה.

## ADR-006: Generate Payment Link הוא הנתיב הראשי

### Context

קישורי תשלום מתארחים מצמצמים Scope של PCI ומתאימים במיוחד למשתמשים עסקיים שמתחילים גבייה מתוך Dynamics 365 או Power Automate.

### Decision

להשתמש ב-`GeneratePaymentLink` כפעולת התשלום המרכזית למשתמשים.

### Consequences

- לקוחות מזינים פרטי כרטיס רק ב-PayPlus.
- Power Platform שומרת מטא-דאטה של תשלום ולא פרטי כרטיס.
- התהליך העסקי פשוט עבור שירות, גבייה ותפעול.

### Alternatives Considered

- חיוב ישיר בכרטיס גולמי: נדחה לשלב הראשון בגלל השפעת PCI.
- חיוב מבוסס טוקן: אפשרי רק כתרחיש עתידי או מתקדם עם בקרות.
- עבודה ידנית בדשבורד PayPlus: נדחה כי אינו מספק אינטגרציה ל-Dynamics.

## ADR-007: לא לממש raw credit card charge בשלב הראשון

### Context

פעולות חיוב ישיר עלולות לדרוש PAN, תוקף ו-CVV כקלט לפעולת Power Automate או כמשתנים בתהליך.

### Decision

לא לחשוף בשלב הראשון פעולות שמקבלות PAN או CVV גולמיים.

### Consequences

- Scope של PCI מצטמצם.
- Run history ולוגים של Flow אינם מכילים פרטי כרטיס גולמיים.
- חלק מתרחישי החיוב הישיר אינם נתמכים עד להשלמת סקירה ייעודית.

### Alternatives Considered

- חשיפת חיוב גולמי עם Secure Inputs: נדחה כי עדיין קיימים סיכוני Run history ושימוש שגוי.
- שימוש בדף תשלום מתארח: התקבל.
- חיוב טוקן בלבד: אפשרי תחת בקרות ייעודיות.

## ADR-008: טיפול ב-`terminal_uid` כבחירה עסקית נדרשת

### Context

UUID של מסופי PayPlus מוחזר על ידי `MyTerminals` ונדרש לפעולות כגון שליפת דפי תשלום. ב-POC אומת כי `GET /MyTerminals` מחזיר ערכי UUID המשמשים כ-`terminal_uid`.

### Decision

להתייחס ל-`terminal_uid` כקלט או כערך קונפיגורציה מרכזי כאשר PayPlus דורש הקשר של מסוף.

### Consequences

- תהליכי הגדרה יכולים לאפשר למנהל לבחור מסוף מתאים.
- רשימת דפי תשלום יכולה להסתנן לפי מסוף.
- יש לשמור רק מזהי מסוף שאושרו לשימוש עסקי.

### Alternatives Considered

- קידוד קשיח של terminal UID: נדחה למעט דוגמאות מבוקרות.
- שמירת terminal UID כפרמטר חיבור: נבדק ונזנח משיקולי חוויית משתמש.
- הקלדה ידנית בכל פעולה: נדחה כי מועד לטעויות.

## ADR-009: טיפול מפורש במגבלות dropdown

### Context

Designer של Power Automate עלול להיכשל עם שגיאת Manifest 409 כאשר dropdown תלוי מיושם באמצעות `x-ms-dynamic-values` ומקור הרשימה דורש פרמטר.

### Decision

לתעד את המגבלה ולהשתמש בדפוס היציב שנמצא ב-POC:

- `x-ms-dynamic-values` עבור dropdown פשוט של מסוף.
- `x-ms-dynamic-list` עבור רשימת דפי תשלום תלויה כאשר נדרש.
- שמירת פעולות Discovery עצמאיות לצורך בדיקה ופתרון תקלות.

### Consequences

- חוויית Designer טובה יותר בלי לחסום הוספת פעולה.
- בדיקות רגרסיה חייבות לכלול יצירת Action חדש ב-Designer.
- לאחר עדכון מחבר ייתכן שיהיה צורך למחוק ולהוסיף מחדש פעולות קיימות.

### Alternatives Considered

- שימוש ב-`x-ms-dynamic-values` תלוי: נדחה בגלל שגיאות 409 חוזרות.
- הפיכת כל השדות לטקסט חופשי: אפשרות fallback, אך פחות נוחה.
- אשף הגדרה לשליפת אפשרויות: מתאים לתרחישי הגדרת מנהל.

## ADR-010: תנאים להוספת חיוב מבוסס טוקן בעתיד

### Context

חיוב מבוסס טוקן נמנע מ-PAN גולמי אך עדיין כולל התנהגות תשלום רגישה וטיפול בטוקנים.

### Decision

ניתן להוסיף או להפעיל חיוב מבוסס טוקן רק כאשר כל התנאים מתקיימים:

- הטוקן נוצר ונשמר על ידי PayPlus או רכיב מאושר שנמצא ב-Scope PCI מתאים.
- אין פעולה במחבר שמקבלת PAN או CVV גולמיים.
- Secure Inputs ו-Secure Outputs מופעלים היכן שנדרש.
- Dataverse שומר רק מזהה טוקן או כינוי מאושר, לעולם לא פרטי כרטיס גולמיים.
- צוותי אבטחה, Compliance ובעלי התהליך העסקי מאשרים את התרחיש.
- מוגדרים ניטור, ביקורת וטיפול באירועים.

### Consequences

- חיוב טוקן נשאר אפשרי בלי לפתוח נתיב כרטיס גולמי.
- ערכי טוקן מטופלים כרגישים.
- עדיין נדרש מסלול אישור ייעודי.

### Alternatives Considered

- חיוב ישיר גולמי: נדחה.
- דף תשלום מתארח בלבד: ברירת המחדל לשלב הראשון.
- Token Vault ב-Middleware: אפשרות עתידית לבקרות מחמירות יותר.
