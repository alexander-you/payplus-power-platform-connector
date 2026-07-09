# פתרון תקלות

## גישה כללית

1. לאשר את הסביבה: Sandbox או Production.
2. לאשר שה-host של PayPlus מתאים לפרטי הגישה.
3. לאשר שה-Connection Reference מצביע ל-Connection הנכון.
4. לאשר שה-Connection נוצר לאחר הוספת secure connection parameters.
5. להריץ `MyTerminals` כדי לאמת גישה בזמן ריצה.
6. להריץ `ListPaymentPages` עם `terminal_uid` ידוע.
7. להריץ `GeneratePaymentLink` עם גוף בקשה מלא.
8. לבדוק Run history רק במסגרת הרשאות מאושרות.
9. לא להדביק סודות אמיתיים בלוגים, קריאות שירות, צילומי מסך או request inspectors.

## 403 Forbidden

סיבות אפשריות:

- `api-key` או `secret-key` שגויים.
- פרטי Sandbox מול Production host.
- פרטי Production מול Sandbox host.
- גוף בקשה חובה חסר או endpoint לא נתמך.
- מסוף או דף תשלום שאינם תקפים להיקף פרטי הגישה.

פעולות:

- לאמת host וסביבה.
- לוודא שהפעולה משתמשת ב-Connection של המחבר ולא ב-headers כקלט פעולה.
- לבדוק עם `GeneratePaymentLink` וגוף בקשה מלא.
- לבדוק את גוף תגובת PayPlus אם קיים.

## 502 Bad Gateway

סיבות אפשריות:

- כשל PayPlus upstream שנעטף על ידי המחבר.
- בקשה חסרה שנשלחה ל-PayPlus.
- פעולה או endpoint לא נתמכים.
- תקלה זמנית ב-gateway.

פעולות:

- לבטל retries אגרסיביים בזמן אימות.
- להשוות לבקשת `GeneratePaymentLink` מלאה.
- לשמור status code וגוף מסונן.
- לא להניח שמדובר ב-WAF לפני בדיקת endpoint, method, body ופרטי גישה.

## Empty response

סיבות אפשריות:

- endpoint לא נתמך ב-PayPlus.
- גוף בקשה חובה חסר.
- PayPlus או gateway דחו את הבקשה לפני יצירת שגיאת JSON מובנית.

פעולות:

- לוודא שה-endpoint מתועד ומופעל.
- להשתמש בגוף בקשה מלא לאימות קישור תשלום.
- לשמור headers ומזהי קורלציה ללא סודות.

## Invalid credentials

סיבות אפשריות:

- זוג מפתחות שגוי.
- Connection ישן ללא secure connection parameters.
- Connection Reference עדיין מצביע ל-Connection ישן.
- פרטי הגישה שייכים לסביבה אחרת.

פעולות:

- ליצור מחדש את ה-Connection ב-Power Platform.
- לקשר מחדש Connection References.
- לאמת תחילה ב-Sandbox.
- להחליף פרטי גישה אם נחשפו.

## Invalid `terminal_uid`

סיבות אפשריות:

- terminal UID הועתק מחשבון אחר.
- המסוף לא פעיל או לא זמין לזוג המפתחות.
- המשתמש בחר מסוף שגוי.

פעולות:

- להריץ `MyTerminals` דרך אותו Connection.
- להשתמש בערך `uuid` שחזר כ-`terminal_uid`.
- לאשר סטטוס מסוף ב-PayPlus.

## Payment page list empty

סיבות אפשריות:

- אין דפי תשלום למסוף שנבחר.
- נבחר מסוף שגוי.
- לפרטי הגישה אין scope מתאים למסוף.
- PayPlus החזיר מערך `data` ריק.

פעולות:

- להריץ `MyTerminals`.
- להריץ `ListPaymentPages` עם המסוף שנבחר.
- לאשר הגדרת דפי תשלום ב-PayPlus.
- להשתמש ב-payment page UID ידני רק לאחר אימות.

## Designer 409 Error fetching manifest

סיבות אפשריות:

- dropdown תלוי יושם באמצעות `x-ms-dynamic-values` כאשר פעולת המקור דורשת פרמטר.
- Action node קיים שמר cache של metadata ישן.

פעולות:

- להשתמש ב-`x-ms-dynamic-list` לבחירת דף תשלום תלויה.
- למחוק את ה-Action השבור.
- לבצע רענון קשיח ל-Designer.
- להוסיף את ה-Action מחדש.
- להשאיר `MyTerminals` ו-`ListPaymentPages` זמינות לפתרון תקלות.

## Environment variable not found

סיבות אפשריות:

- ארכיטקטורה ישנה ציפתה ל-Environment Variables שכבר אינם קיימים.
- Import של Solution לא כלל ערכי Environment Variable.
- Flow עדיין מפנה למשתנים מיושנים.

פעולות:

- לאשר שהתכנון הנוכחי משתמש ב-secure connection parameters עבור מפתחות.
- להסיר הפניות מיושנות ל-key environment variables.
- להשאיר רק Environment Variables שאינם סודיים אם היישום דורש זאת.

## Key Vault network blocked

סיבות אפשריות:

- ל-Key Vault מוגדר `publicNetworkAccess=Disabled`.
- אין Private Endpoint או נתיב רשת מאושר ל-Power Platform.
- Azure Policy אוכף חסימת גישה ציבורית.

פעולות:

- להשתמש ב-secure connection parameters כברירת המחדל למחבר.
- לשקול Key Vault מחדש רק עם רשת פרטית מאושרת או החרגת Policy.
- לתעד את החלטת הרשת בסקירת האבטחה.

## Policy not injecting header

סיבות אפשריות:

- `policyTemplateInstances` חסר מ-`apiProperties.json`.
- שם connection parameter שגוי.
- מרכאות שגויות בביטוי.
- עדכון מחבר לא פורסם או Runtime cache מיושן.

פעולות:

- לוודא שה-policy משתמש ב-`@connectionParameters('apiKey')` וב-`@connectionParameters('secretKey')`.
- לוודא שפרמטרי החיבור נקראים בדיוק `apiKey` ו-`secretKey`.
- ליצור מחדש את ה-Connection אם runtime cache מיושן.
- להשתמש ב-request inspector רק עם סודות דמה.

## Connection parameter missing

סיבות אפשריות:

- Connection קיים נוצר לפני הוספת הפרמטרים.
- המחבר עודכן אך ה-Connection לא נוצר מחדש.
- דיאלוג ה-Connection לא קלט ערכים נדרשים.

פעולות:

- למחוק וליצור מחדש את ה-Connection.
- להזין את שני המפתחות בדיאלוג החיבור.
- לקשר מחדש Connection References.
- להריץ אימות `GeneratePaymentLink`.

## Sandbox vs Production mismatch

תסמינים:

- פרטי גישה נדחים.
- דפי תשלום לא נמצאים.
- התנהגות host לא צפויה.

פעולות:

- Sandbox host חייב להיות `restapidev.payplus.co.il`.
- Production host חייב להיות `restapi.payplus.co.il`.
- להשתמש במחברים נפרדים או Connection References מופרדים בבירור.
- לא לבדוק עם פרטי Production בפיתוח.

## Wrong PayPlus host

פעולות:

- לבדוק את שדה `host` במחבר.
- לבדוק את הסביבה שנבחרה ב-setup flow.
- לבדוק שמות Connection Reference.
- לאמת שנתיב הבסיס הוא `/api/v1.0`.

## Business level keys vs terminal scope

חלק מפעולות PayPlus עשויות לעבוד עם פרטי גישה ברמת עסק, בעוד אחרות דורשות הקשר מסוף. לדוגמה, שליפת דפי תשלום דורשת terminal UID תקין.

פעולות:

- להשתמש ב-`MyTerminals` כדי למצוא UUID של מסופים.
- להעביר `terminal_uid` כאשר נדרש.
- לאשר scope של מפתחות מול PayPlus אם פעולות מחזירות תוצאות לא עקביות.

## אימות עם request inspector באמצעות dummy secrets בלבד

Request inspection שימושי להוכחת הזרקת policy, אך אין להשתמש בסודות אמיתיים בכלי ציבורי או בלוג משותף.

שיטה בטוחה:

1. ליצור מחבר בדיקה זמני או פעולה מבודדת.
2. להשתמש בערכים כגון `dummy-api-key` ו-`dummy-secret-key`.
3. לשלוח בקשה ל-inspector endpoint אמין.
4. לוודא שה-headers קיימים.
5. למחוק את Connection הבדיקה ואת נתוני endpoint הבדיקה.

לעולם אין לשלוח פרטי PayPlus Production ל-request inspector.
