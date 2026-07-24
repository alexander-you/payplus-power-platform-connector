# מדריך פקדי PCF — חיבור, שדות, טבלאות ושימוש עצמאי

> English version: [../en/pcf-controls-guide.md](../en/pcf-controls-guide.md)

מדריך זה מסביר **כיצד להוסיף כל פקד PCF של PayPlus לטופס או לעמוד, אילו properties לחבר, על אילו טבלאות הוא עובד, ומה קורה כשמשתמשים בפקד עצמאית** — ובעיקר כיצד אשף התשלום (Payment Wizard) קולט תשלום גם כשאין **חשבונית Dynamics 365 Sales**.

כל הפקדים נמצאים במרחב השמות `PayPlus` ומסופקים ב-**Solution הבסיס** (`alex_d365_payplus`). הם **אינם** דורשים Dynamics 365 Sales. המיקום הספציפי ל-Sales (על טפסי הצעת מחיר/הזמנה/חשבונית) מגיע מ-Solution ההרחבה הנפרד — ראו [integration-guide.md](integration-guide.md#the-two-solutions-and-their-dependencies).

## חמשת הפקדים במבט מהיר

| פקד | Constructor | סוג | אופן החיבור | פועל מול |
| --- | --- | --- | --- | --- |
| Mapping Studio | `PayPlus.MappingStudio` | שדה (bound) | עמודת טקסט `hostValue` | פרופיל סנכרון (`alex_payplus_syncprofile`) + כל מקור/יעד |
| Credit Card Wallet | `PayPlus.CreditCardWallet` | Dataset | Subgrid של כרטיסים | `alex_creditcard` על Account/Contact |
| Bank Account Wallet | `PayPlus.BankAccountWallet` | Dataset | Subgrid של חשבונות בנק | חשבונות בנק של הלקוח + `alex_bank`/`alex_bankbranch` |
| Payment Wizard | `PayPlus.PaymentWizard` | שדה (bound) + inputs | `hostValue` + `sourceEntity`/`sourceId` | `alex_payplusbillingcase` (כל טבלת מקור, או עצמאי) |
| Document Ledger | `PayPlus.DocumentLedger` | שדה (bound) + inputs | `hostValue` + `scope`/`recordId`/`entityLogicalName` | `alex_payplusdocument` |
| Document Preview | `PayPlus.DocumentPreview` | שדה (bound) + input | `hostValue` + `documentId` | מסמך `alex_payplusdocument` בודד |

יש שני סגנונות חיבור:

- **פקדי Dataset** (Credit Card Wallet, Bank Account Wallet) מחליפים **subgrid**. מוסיפים לטופס subgrid של טבלת היעד ומחליפים את הפקד שלו לפקד PayPlus. הפקד קורא את רשומת האב מהקשר העמוד.
- **פקדי שדה (field-bound)** (כל השאר) מחברים את ה-property החובה `hostValue` ל**עמודת טקסט של שורה בודדת**. זהו דפוס PCF סטנדרטי: העמודה המחוברת היא רק עוגן — העבודה האמיתית נעשית דרך ה-Web API וה-**input properties**. ב-**עמוד מותאם (custom page)**, שבו אין שדה טופס, מפעילים את הפקד לגמרי דרך ה-input properties.

## Mapping Studio

**מטרה.** מיפוי שדות ויזואלי בין טבלת מקור ב-Dynamics ליעד PayPlus, והפעלה/כיבוי של סנכרון רציף.

**היכן למקם.** על טופס **פרופיל הסנכרון** (`alex_payplus_syncprofile`).

| Property | שימוש | סוג | חובה | לחבר אל |
| --- | --- | --- | --- | --- |
| `hostValue` | bound | טקסט שורה בודדת | כן | עמודת טקסט בפרופיל הסנכרון (למשל עמודת מצב-המיפוי) |

**טבלאות שהוא נוגע בהן.** קורא מטא-דאטה של טבלאות/עמודות ל-מקור ויעד PayPlus הנבחרים; כותב את המיפוי והגדרות הסנכרון בחזרה לטבלאות פרופיל-הסנכרון וכללי-הטרנספורמציה. משתמש בשמירת הטופס.

**הערת עצמאות.** זהו פקד ניהול; תמיד פועל בהקשר של רשומת פרופיל אחת. אין לו וריאציה משמעותית של "ללא-Sales" כי הוא אגנוסטי לטבלת המקור — מפנים אותו לכל טבלה שרוצים לסנכרן.

## Credit Card Wallet

**מטרה.** הצגת כרטיסי PayPlus מטוקנים של לקוח כ-Wallet בסגנון Apple, עם היפוך תלת-ממד, הפעלה/השבתה, טיפול בכרטיס ברירת-מחדל וקיצורים לקליטת כרטיס חדש.

**היכן למקם.** על טופס **Account** או **Contact**, כפקד של **subgrid של `alex_creditcard`**.

| Property | שימוש | מתחבר אל |
| --- | --- | --- |
| `wallet` (dataset) | dataset | ה-subgrid של `alex_creditcard`; האב נקרא מהקשר העמוד |

**טבלאות שהוא נוגע בהן.** `alex_creditcard` (בקשר לאב account/contact). יכול גם להפעיל קליטת כרטיס (hosted fields) וסשן שירות-עצמי (`alex_pp_hfsession`).

**הערת עצמאות.** פועל על כל טבלה שמחזיקה כרטיסים. לעולם לא צריך Sales — כרטיסים שייכים ללקוחות, לא לחשבוניות.

## Bank Account Wallet

**מטרה.** הצגת חשבונות הבנק של לקוח כ-Wallet בסגנון Apple עם לוגו בנק, והוספת חשבונות דרך בוררי בנק + סניף (כולל פרטי הוראת קבע).

**היכן למקם.** על טופס **Account** או **Contact**, כפקד של **subgrid של טבלת חשבונות-הבנק של הלקוח**.

| Property | שימוש | מתחבר אל |
| --- | --- | --- |
| `accounts` (dataset) | dataset | ה-subgrid של חשבונות הבנק; האב נקרא מהקשר העמוד |

**טבלאות שהוא נוגע בהן.** טבלת חשבונות-הבנק של הלקוח, בתוספת טבלאות הייחוס `alex_bank` ו-`alex_bankbranch` (מאוכלסות ע"י flow ייבוא בנקים וסניפים).

**הערת עצמאות.** בלתי תלוי ב-Sales; זהו מידע-אב של הלקוח, לא נתוני הזמנה.

## Payment Wizard — כולל שימוש **ללא** חשבונית Sales

**מטרה.** אשף מונחה שקולט תשלום ומפיק את התוצאה החשבונאית (קבלה / חשבונית-מס-קבלה), כולל תשלום מלא או חלקי, hosted fields או טוקן שמור, שורות תשלום והקצאות קבלה.

**היכן למקם.**
- על טופס **Dynamics 365 Sales** (הצעת מחיר, הזמנה, חשבונית) — מסופק ע"י Solution ההרחבה; או
- על טופס של **כל טבלה מותאמת**; או
- על **עמוד מותאם (custom page)** ללא הקשר טופס — למשל אפליקציית גבייה שאין בה Sales כלל.

| Property | שימוש | סוג | חובה | מטרה |
| --- | --- | --- | --- | --- |
| `hostValue` | bound | טקסט שורה בודדת | כן | עמודת עוגן על הטופס המארח (כל עמודת טקסט) |
| `sourceEntity` | input | טקסט שורה בודדת | לא | שם לוגי של הרשומה שעבורה התשלום |
| `sourceId` | input | טקסט שורה בודדת | לא | מזהה אותה רשומה |

**כיצד הוא מחליט מה לחייב.** האשף בנוי סביב **תיק חיוב** (`alex_payplusbillingcase`), ולא סביב חשבונית:

1. הוא מזהה את המקור לפי `sourceEntity` / `sourceId` **אם סיפקת אותם**, אחרת קורא אוטומטית את הקשר **הטופס או העמוד** הנוכחי.
2. מוצא (או יוצר) את תיק החיוב שה-`alex_sourceentitylogicalname` + `alex_sourceentityid` שלו תואמים למקור.
3. טוען את **שורות התשלום** (`alex_paypluspaymentline`) ו**הקצאות הקבלה** (`alex_payplusreceiptallocation`) של התיק כדי לחשב את יתרת החוב.
4. **רק אם** המקור הוא במקרה חשבונית Sales (`invoice`) הוא מושך בנוסף את שורות החשבונית (`invoicedetail`). לכל מקור אחר, **תיק החיוב הוא העוגן היחיד** — לא נדרשת שום רשומת Sales.

> **זו התשובה ל"מה אם אין חשבונית Sales?"** ה-Payment Wizard לעולם אינו תלוי ב-`invoice`. תן לו כל `sourceEntity`/`sourceId` (מנוי, שכר לימוד, תיק פנייה, הזמנה מותאמת), או הצב אותו על עמוד מותאם — והוא יגבה מול תיק חיוב בדיוק אותו דבר. חשבונית ה-Sales היא מקור אופציונלי אחד מני רבים.

**טבלאות שהוא נוגע בהן.** `alex_payplusbillingcase`, `alex_paypluspaymentline`, `alex_payplusreceiptallocation`, `alex_payplusdocument` (קבלות/חשבוניות שהופקו), ונקודות-קצה של תשלום מתארח ב-PayPlus. במקור Sales הוא קורא גם `invoice` / `invoicedetail`.

**שירותים חיצוניים.** הפקד קורא ישירות לדומיינים של תשלום מתארח ב-PayPlus (פקד פרימיום).

## Document Ledger

**מטרה.** ספר-חשבונות מודע-חשבונאית ללקוח או לרשומה: סה"כ חיובים, סה"כ זיכויים, יתרה סופית, וחיפוש על פני מסמכים שהופקו.

**היכן למקם.** על טופס **חשבונית**, **Account** או **Contact**, או על **עמוד מותאם**.

| Property | שימוש | חובה | מטרה |
| --- | --- | --- | --- |
| `hostValue` | bound | כן | עמודת טקסט עוגן על הטופס |
| `scope` | input | לא | אילו מסמכים להציג (למשל רשומה אחת מול כל הלקוח) |
| `recordId` | input | לא | הרשומה לתיחום (לשימוש בעמודים מותאמים) |
| `entityLogicalName` | input | לא | השם הלוגי של אותה רשומה (לשימוש בעמודים מותאמים) |

**טבלאות שהוא נוגע בהן.** `alex_payplusdocument` (מסונן לפי scope / רשומה / לקוח).

**הערת עצמאות.** על טופס הוא קורא את הרשומה הנוכחית אוטומטית; על עמוד מותאם מעבירים `recordId` + `entityLogicalName` במפורש. אין תלות ב-Sales.

## Document Preview

**מטרה.** הצגת תצוגה מקדימה של מסמך PayPlus (Invoice+) בודד.

**היכן למקם.** על טופס **`alex_payplusdocument`**, או על **עמוד מותאם** שבו כבר ידוע מזהה המסמך.

| Property | שימוש | חובה | מטרה |
| --- | --- | --- | --- |
| `hostValue` | bound | כן | עמודת טקסט עוגן |
| `documentId` | input | לא | מסמך `alex_payplusdocument` לתצוגה (לשימוש בעמודים מותאמים) |

**טבלאות שהוא נוגע בהן.** מסמך `alex_payplusdocument` בודד. קורא לנקודות-קצה של תצוגה מקדימה ב-PayPlus (פקד פרימיום).

## טבלת מיקום מהירה

| אני רוצה… | להשתמש ב | למקם על |
| --- | --- | --- |
| להגדיר ולהפעיל סנכרון | Mapping Studio | טופס פרופיל סנכרון |
| להציג/לנהל כרטיסים שמורים | Credit Card Wallet | subgrid כרטיסים על Account/Contact |
| להציג/להוסיף חשבונות בנק | Bank Account Wallet | subgrid חשבונות בנק על Account/Contact |
| לקלוט תשלום (כל מקור) | Payment Wizard | כל טופס, או עמוד מותאם |
| להציג יתרה ומסמכים | Document Ledger | טופס חשבונית/Account/Contact, או עמוד מותאם |
| תצוגה מקדימה של מסמך אחד | Document Preview | טופס מסמך, או עמוד מותאם |

## מסמכים קשורים

- [architecture.md](architecture.md) — היכן הפקדים יושבים בפתרון הכולל
- [integration-guide.md](integration-guide.md) — בניית תהליכים עם או בלי Sales, ומודל שני ה-Solutions
- [data-model.md](data-model.md) — הטבלאות שהפקדים קוראים וכותבים
