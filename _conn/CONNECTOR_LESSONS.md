# PayPlus Connector — לקחים לדיבוג (Runtime Errors)

מסמך קצר שמרכז את סוגי התקלות שנתקלנו בהם בפעולות ה-Connector ואיך פותרים.
עדכון אחרון: 2026-07-12.

## עקרון-על
Power Automate (OpenApiConnection) מאמת גם את **הבקשה** וגם את **התגובה** מול ה-swagger של המחבר.
PayPlus מצדה מאמתת את גוף הבקשה ומחזירה **שדה חובה חסר אחד בכל פעם**. לכן כל תיקון "פותח" את הדרישה הבאה — זו התקדמות, לא לולאה.

## ⚠️ מטמון Runtime (הכי חשוב)
`pac connector update` מעדכן את ה-Store, אבל ה-**runtime של ה-Flow ממשיך להגיש swagger ישן מהמטמון**.
אחרי כל עדכון מחבר חובה **לנקות מטמון ידנית**:
1. maker UI → פתח את המחבר (Edit) → שלב אחרון → **Update connector** (פרסום מחדש), **או**
2. מחק וצור מחדש את ה-Connection.
3. ב-Flow: מחק+הוסף מחדש את ה-Action (כדי לטעון סכימה חדשה), שמור, והרץ שוב (Resubmit).

> Web API **לא** יכול להפעיל Flow (חיבורי PayPlus בבעלות משתמש → `ConnectionAuthorizationFailed`) — הפעלה ידנית בלבד.

## סוגי תקלות שנפתרו

### 1. תגובה: Object מול Array
שגיאה: `... requires the property 'body' to be of type 'Object' but is of type 'Array'`.
דוגמה: `ViewProducts` (`GET /Products/View`) מחזיר **מערך גולמי** אבל הוגדר `ApiResult` (אובייקט).
פתרון: סכימת 200 → `{ "type":"array", "items":{ "type":"object", ... } }`. הצהר רק שדות בטוחים (string) כמו `uid`/`name`; שאר השדות עדיין מגיעים ב-body הגולמי.
(אותו דפוס כמו `MyTerminals` שמחזיר מערך.)

### 2. אי-התאמת טיפוס בתגובה
שגיאה דומה על שדה מוצהר (למשל boolean מול integer).
פתרון: התאם את הטיפוס לסכימה הרשמית של PayPlus, או הסר טיפוס מהשדה הבעייתי. תמיד אמת מול הדוקומנטציה הרשמית.

### 3. PayPlus דורש פרמטר שמסומן "אופציונלי"
דוגמה: `ViewCustomers` החזיר `422` עם `take-is-missing` — למרות ש-`take` מסומן אופציונלי בתיעוד.
פתרון: הפוך את `take` ל-`required:true` + `default:"100"`. חל כנראה על שאר endpoints מדפים (pagination).

### 4. שם שדה שגוי בגוף הבקשה
שגיאה: `missing-<path>-param` — למשל `missing-customer.name-param`.
הנתיב בשגיאה = מפתח ה-JSON שחסר. אם הערך נשלח אבל תחת מפתח אחר → **שם השדה שגוי**.
דוגמה: מסמכי Invoice+ (`/books/docs/new`) מצפים ל-`customer.name`, בעוד המחבר שלח `customer_name`.
פתרון: תוקן `DocumentCustomer.customer_name` → `name` + מיפוי ה-Flow.
> ⚠️ פיצול שמות: API של לקוחות (`ViewCustomers`/`AddCustomer`) משתמש ב-`customer_name`; API של מסמכים (Invoice+) משתמש ב-`name`. **לא לאחד.**

### 5. שדה חובה חסר לגמרי
שגיאה: `missing-totalAmount-param`.
פתרון: הוסף מיפוי חסר ל-Flow (`body/totalAmount` מ-`totalamount` של ההצעה). שדות סכום → טיפוס `number` (לא `integer`) כדי לאפשר אגורות.

## Reference (סביבה)
- Sandbox connector id: `79337094-f90a-4117-8d95-7fcef4ee4f84` — def `_conn/apiDefinition.sandbox.json`, props `_conn/sandbox/apiProperties.json`
- Prod connector id: `66e6832f-9776-4285-a07b-84b069d02015` — def `_conn/apiDefinition.prod.json`, props `_conn/prod/apiProperties.json`
- Solution: `alex_d365_payplus`
- פקודת עדכון:
  `pac connector update --connector-id <ID> --api-definition-file <DEF> --api-properties-file <PROPS> --solution-unique-name alex_d365_payplus`
- Flow "PayPlus - Create Quote" = `aa392db2-027e-f111-ab0e-7ced8d726840`; deploy: `./_poc_deploy_create_quote_flow.ps1`
