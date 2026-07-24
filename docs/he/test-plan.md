# תוכנית בדיקות

## מטרת המסמך

תוכנית בדיקות זו מאמתת את מחבר PayPlus, תהליכי Power Automate, מודל Dataverse אופציונלי ובקרות מוכנות לייצור.

## סביבות בדיקה

| סביבה | מטרה |
| --- | --- |
| Development | ייבוא מחבר, שינויי סכמה, בדיקות יחידה בסגנון Low-code |
| Sandbox | אימות ריצה מול PayPlus Sandbox |
| Test/UAT | אימות משתמשים עסקיים ובדיקות אבטחה |
| Production | Smoke test מבוקר לאחר אישור |

## Unit tests

בדיקות יחידה מוגבלות כי זהו בעיקר פתרון Low-code ומחבר. כאשר יש קוד מותאם, יש לבדוק:

- פונקציות JavaScript של Web resource.
- פונקציות מיפוי Dataverse.
- בניית payload.
- מיפוי סטטוסים.
- אימות חתימת webhook אם מיושם בקוד.

## Connector tests

- לוודא ש-`apiDefinition.*.json` הוא JSON תקין.
- לוודא ש-`apiProperties.json` הוא JSON תקין.
- לייבא או לעדכן את מחבר Sandbox.
- לוודא ש-`apiKey` ו-`secretKey` הם connection parameters מסוג `securestring`.
- לוודא שקיימים `setheader` policies עבור `api-key` ו-`secret-key`.
- לוודא שאין פעולה שחושפת `api-key` או `secret-key` כפרמטר פעולה רגיל.
- לוודא שאין פעולה בשלב הראשון שמקבלת PAN או CVV גולמיים.
- לוודא ש-operation IDs ושמות תצוגה יציבים.

## Connection tests

- ליצור Connection ל-Sandbox עם פרטי PayPlus Sandbox.
- לוודא שה-Connection מריץ `MyTerminals`.
- לוודא שה-Connection מריץ `ListPaymentPages` עם `terminal_uid` תקין.
- לוודא שה-Connection מריץ `GeneratePaymentLink` עם גוף Sandbox מלא.
- ליצור מחדש או לקשר Connection References ולאשר שה-flows משתמשים בחיבור הנכון.
- לוודא שערכי secure connection parameters אינם ניתנים לקריאה דרך APIs רגילים.

## בדיקות אשף התקנה ומסופים/עמודים

- להריץ את ה-flow ‏`PayPlus - Import Terminals & Pages` ולאשר שנוצרות רשומות ב-`alex_payplus_terminal` וב-`alex_payplus_paymentpage`, לפי סביבה + UID.
- לאשר שכל עמוד תשלום מקושר למסוף שאליו הוא שייך (`alex_terminalid`).
- להריץ את הייבוא שוב ולאשר שהוא אידמפוטנטי (upsert לפי סביבה + UID, בלי כפילויות, תוך שימור שדות עסק/מדיניות).
- רשומות חדשות נוצרות עם `alex_isdefault = false`.
- בשלב האימות, לבחור מסוף ברירת מחדל ואת עמוד ברירת המחדל שלו; לאשר ש-`alex_terminaluidref` / `alex_paymentpageuidref` נכתבים בקונפיגורציה ו-`alex_isdefault = true` נקבע על הרשומות שנבחרו.
- לנסות לקבוע מסוף ברירת מחדל שני לאותה סביבה ולאשר ש-`EnforceSingleDefaultTerminal` מנקה את ברירת המחדל הקודמת.
- לנסות לקבוע עמוד ברירת מחדל שני לאותו מסוף + סוג תהליך ולאשר ש-`EnforceSingleDefaultPage` מנקה את ברירת המחדל הקודמת.
- לאשר שייבוא סוגי המסמכים הוא שלב חובה חוסם: ההתקנה אינה מתקדמת ל-Done עד שסוגי המסמכים מיובאים בהצלחה; ייבוא שנכשל או שפג זמנו משאיר את ההתקנה בשלב האימות.
- ממרכז הניהול (שלב Done), להריץ את בדיקת החיבור לפי דרישה עבור עמוד תשלום בודד.

## Runtime tests

- ליצור קישור תשלום עם סכום, מטבע, מסוף, דף תשלום, לקוח ופריט תקינים.
- לשמור `page_request_uid` ו-`payment_page_link` שחזרו.
- לפתוח את הקישור ולאשר שהוא מוביל לדף PayPlus.
- להשלים תשלום Sandbox אם קיימים כרטיסי בדיקה מאושרים.
- לשלוף או לקבל סטטוס תשלום אם היישום כולל status retrieval או webhook.
- לוודא מעברי סטטוס ב-Dataverse.

## Negative tests

| תרחיש | תוצאה צפויה |
| --- | --- |
| מפתח שגוי | PayPlus דוחה את הבקשה; אין סימון תשלום כשולם |
| secret חסר | קריאת המחבר נכשלת; השגיאה מסוננת |
| terminal שגוי | `ListPaymentPages` או פעולת תשלום נכשלת עם הודעה מבוקרת |
| payment page שגוי | יצירת קישור נכשלת או חוזרת שגיאת PayPlus |
| סכום חסר | אימות Flow או PayPlus נכשל |
| סכום אפס או שלילי | הבקשה נדחית לפני PayPlus או על ידי PayPlus |
| מטבע לא תקין | הבקשה נדחית או ממופה לערכים נתמכים בלבד |
| מפתח Sandbox מול Production | נדחה |
| מפתח Production מול Sandbox | נדחה |
| endpoint לא מוכר | שגיאה מטופלת ללא ריבוי ניסיונות לא מבוקר |

## Security tests

- לוודא ש-API keys אינם גלויים בקלטי פעולה.
- לוודא שמפתחות אינם נשמרים בטבלאות Dataverse.
- לוודא שמפתחות אינם נשמרים ב-String Environment Variables.
- לוודא ש-Secure Inputs ו-Secure Outputs מופעלים כאשר מטפלים בערכים רגישים.
- לוודא ש-Run history אינו מכיל PAN או CVV.
- לוודא ש-DLP policy מאפשר רק מחברים מאושרים.
- לוודא ש-flows בייצור בבעלות Service Owners מאושרים.
- לוודא שמשתמשים ללא הרשאות תשלום לא יכולים ליצור או לשלוח קישורים.

## Run history tests

יש לבדוק ריצת Sandbox ולוודא:

- אין מספר כרטיס גולמי.
- אין CVV.
- אין ערך `api-key`.
- אין ערך `secret-key`.
- טוקנים, אם קיימים, מוסתרים או מוגנים באמצעות Secure Inputs/Outputs.
- payload של שגיאות מסונן לפני שמירה ב-Dataverse.

## Dev and Prod validation

Development:

- להשתמש במחבר Sandbox ובפרטי PayPlus Sandbox.
- להשתמש בלקוחות ובדפי תשלום לבדיקה.
- לא להשתמש בפרטי Production.

Production:

- להשתמש במחבר Production ובפרטי PayPlus Production.
- להריץ Smoke test מבוקר לאחר אישורים.
- לוודא ש-Connection References מחוברים ל-Production Connections.
- לוודא שניטור ו-Incident Response פעילים.

## PayPlus sandbox validation

- לאשר host של Sandbox: `restapidev.payplus.co.il`.
- לאשר נתיב בסיס: `/api/v1.0`.
- לאשר ש-`GeneratePaymentLink` מחזיר קישור Sandbox מתארח עם גוף בקשה מלא.
- לאשר שנתוני בדיקה מופיעים ב-PayPlus Sandbox כמצופה.

## 403 / 502 / WAF scenarios

- 403 עם JSON מובנה עשוי להצביע על פרטי גישה שגויים או הקשר בקשה שגוי.
- 403 עם גוף ריק עשוי להופיע עבור endpoints חסרים או לא נתמכים.
- 502 מהמחבר עשוי להיות כשל upstream שנעטף על ידי המחבר; יש לבדוק פעולה, endpoint ושלמות בקשה.
- אין להניח שכל 403 או 502 הם בעיית WAF. יש לאמת endpoint, method, גוף חובה, סביבה ופרטי גישה.
- לאסוף headers של Cloudflare או gateway רק אם אינם חושפים סודות.

## Hebrew and English data validation

- לבדוק שמות לקוח בעברית.
- לבדוק שמות לקוח באנגלית.
- לבדוק שמות מעורבים רק אם המדיניות העסקית מאפשרת.
- לבדוק שמות ותיאורי פריטים בעברית.
- לבדוק פורמטי דוא"ל וטלפון.
- לוודא שהטקסט מוצג נכון ב-Dynamics 365, Power Automate Run history, Dataverse ופלט דף PayPlus.

## תוצאות POC ידועות

- `setheader` policy עובד.
- `@connectionParameters('secretParam')` מוזרק ל-header בזמן ריצה.
- `securestring` connection parameter עובד.
- Key Vault backed secret נחסם בגלל network configuration.
- `MyTerminals` מחזיר ערכי `uuid` המשמשים כ-`terminal_uid`.
- dependent dropdown עלול לגרום 409 ב-designer כאשר מקור הרשימה דורש פרמטר.
- `x-ms-dynamic-values` עבד לבחירת מסוף פשוטה.
- `x-ms-dynamic-list` פתר את דפוס בחירת דף התשלום התלויה בסביבה שנבדקה.
- Action nodes קיימים ב-Designer עשויים לדרוש מחיקה והוספה מחדש לאחר עדכון מחבר.

## בדיקות קליטת תשלום ומסמכים

בדיקות אלו מכסות את מנוע החיוב, הפקת המסמכים והתאמת התשלומים. הן חלות **עם או בלי** Dynamics 365 Sales — רוב הבדיקות משתמשות בתיק גבייה המעוגן לכל רשומת מקור.

### Payment Wizard (תיק גבייה)

- **עצמאי, ללא חשבונית Sales.** מקמו את Payment Wizard על עמוד מותאם (או טופס של טבלה מותאמת), העבירו `sourceEntity`/`sourceId` שאינם חשבונית, וודאו שהוא יוצר `alex_payplusbillingcase` לפי `alex_sourceentitylogicalname` + `alex_sourceentityid` ומציג את יתרת החוב הנכונה ללא שום רשומת Sales.
- **מקור חשבונית Sales.** פתחו את האשף על חשבונית וודאו שהוא מקשר את תיק הגבייה לחשבונית וטוען שורות `invoicedetail`.
- **תשלום מלא.** גבו את מלוא הסכום וודאו ששורת תשלום (`alex_paypluspaymentline`) נוצרת, ש-`alex_paidamount`/`alex_openbalance` של התיק מתעדכנים, ושזרימת המסמך המבוקשת מפיקה קבלה / חשבונית-מס-קבלה.
- **תשלום חלקי.** עם `alex_allowpartialreceipts = true`, גבו סכום חלקי וודאו שיתרת החוב משקפת את היתרה ושהתיק נשאר פתוח.
- **טוקן שמור.** חייבו בכרטיס שמור (`alex_creditcard`) וודאו שהאשף אינו מטפל בנתוני כרטיס גולמיים.
- **Idempotency.** חזרו על חיוב עם אותו `alex_idempotencykey` וודאו שאין שורת תשלום כפולה או חיוב כפול.

### שיוך קבלה

- ודאו ששורת תשלום מייצרת שורות `alex_payplusreceiptallocation` שסכומן שווה לסכום המשויך.
- עבור מקור Sales, ודאו שהשיוכים מכוונים ל-`alex_invoiceid` / `alex_invoicedetailid`; עבור מקור לא-Sales, ודאו ששדות המקור הגנריים `alex_sourcelineid` בשימוש במקום זאת.

### הפקת מסמכים (זרימות Preview)

- צרו רשומת `alex_payplusdocument` ממתינה וודאו שהזרימה התואמת (`PayPlus - Preview Invoice/Quote/Sales Order Document`) קולטת אותה, קוראת ל-PayPlus, וכותבת בחזרה `alex_documentnumber`, `alex_pdfurl` וסטטוס.
- ודאו שפקד Document Preview מציג את המסמך שהופק ו-Document Ledger מציג את היתרה המעודכנת.
- שלחו את המסמך במייל/SMS/WhatsApp וודאו ששורת `alex_payplusdocumentactionlog` מתעדת את הפעולה והערוץ.

### התאמת תשלומים

- הריצו `PayPlus - Poll Invoice Payments` וודאו שתשלומים חיצוניים מותאמים לתיק הגבייה, שורות התשלום מתעדכנות, וסטטוסי הסליקה/האימות עוברים.

### בדיקות smoke לפקדי PCF

- Credit Card Wallet ו-Bank Account Wallet נטענים, מוסיפים ומגדירים ברירת מחדל כראוי על Account/Contact.
- בוררי הבנק/סניף ב-Bank Account Wallet מאוכלסים מ-`alex_bank` / `alex_bankbranch`.
- השפה נגזרת מהגדרת המשתמש ב-Dynamics (עברית RTL / אנגלית LTR) ללא מתג ידני.

## Exit criteria

- יצירת קישור תשלום ב-Sandbox מצליחה.
- סודות אינם גלויים ב-Run history.
- מסמכי אבטחה ו-PCI מאושרים.
- DLP policy מוחל.
- כללי שמירת Dataverse מאושרים.
- בעלות Production Connection מאושרת.
- נתיב פתרון תקלות מתועד ובעלי תמיכה מוגדרים.
