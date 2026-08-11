# חיבור הפתרון המותאם שלך ל‑PayPlus — ללא Dynamics 365 Sales 🇮🇱

מדריך לקוח צעד‑אחר‑צעד לחיבור **הטבלאות והתהליכים המותאמים שלך** (Custom Tables) אל **PayPlus**,
בסביבה שבה **אין** Dynamics 365 Sales. כל מה שצריך נמצא ב‑**פתרון הבסיס** (`alex_d365_payplus`) —
פתרון עצמאי לחלוטין שאינו תלוי ב‑Sales.

> **גרסה:** v1.0.0 · **מפרסם:** AlexanderYurpolsky (קידומת `alex`)
> **הורדת הפתרון:** <https://github.com/alexander-you/payplus-power-platform-connector/releases/tag/v1.0.0>
> מדריך משלים: [PAYPLUS_SETUP_GUIDE_HE.md](PAYPLUS_SETUP_GUIDE_HE.md) (התקנה ראשונית והפקת מפתחות API).

---

## למי מיועד המדריך

לקוח שיש לו **מודל נתונים משלו ב‑Dataverse** (טבלאות `contact`, `account`, או טבלאות מותאמות כמו
`new_customerproduct`) ורוצה לסנכרן אותן ל‑PayPlus — **בלי** להתקין את הרחבת ה‑Sales ובלי לגעת ב‑Flows.
כל החיבור נעשה דרך **מנוע הסנכרון** ופקד ה‑**Mapping Studio**, בהגדרה בלבד (No‑Code).

---

## איך זה עובד — בקצרה

```
טבלת המקור שלך  ──►  Entity Mapping + Field Mapping  ──►  Sync Outbox  ──►  Flow "Process Sync Outbox"  ──►  PayPlus
   (Dataverse)         (מוגדר ב‑Mapping Studio)          (תור משימות)        (מובנה בפתרון הבסיס)          (Connector)
```

- **Entity Mapping** — קובע *איזו* טבלת Dataverse מסתנכרנת לאיזה אובייקט PayPlus.
- **Field Mapping** — קובע *אילו שדות* עוברים ואיך.
- **Sync Outbox / State / Log** — תור המשימות, מצב הקורלציה (PayPlus UID) והיסטוריית ריצה.
- הכול נשלט מרשומת **Sync Profile** אחת (`alex_payplus_syncprofile`) דרך פקד ה‑Mapping Studio.

---

## דרישות מקדימות

| # | דרישה |
|---|--------|
| 1 | סביבת **Dataverse** עם הרשאת **System Administrator / Customizer**. |
| 2 | **פתרון הבסיס** `alex_d365_payplus` מותקן (Managed מומלץ). Dynamics 365 Sales **אינו נדרש**. |
| 3 | מפתחות **PayPlus API** (`api_key` + `secret_key`) ו‑**Connection** פעיל ל‑Custom Connector — ראו מדריך ההתקנה. |
| 4 | טבלת המקור שברצונך לסנכרן קיימת בסביבה (סטנדרטית או מותאמת). |

---

## שלב 1 — התקנת הבסיס בלבד

1. ייבאו את **`alex_d365_payplus_1_0_0_0_managed.zip`** בלבד (אל תייבאו את הרחבת ה‑Sales).
2. צרו **Connection** ל‑PayPlus (Prod / SandBox) וקשרו את ה‑Connection References, כמתואר במדריך ההתקנה.
3. השלימו את אשף ההגדרה (מפתחות API, מסוף).

> ✅ בסיום השלב הזה יש לך פלטפורמת PayPlus מלאה בלי שום תלות ב‑Sales.

---

## שלב 2 — יצירת Sync Profile

1. פתחו את האפליקציה המודל‑מבוססת של PayPlus.
2. עברו אל **Sync Profiles** (`alex_payplus_syncprofile`) → **New**.
3. הגדירו:
   - **Environment** — `Sandbox` לבדיקות או `Production` לפרודקשן.
   - **Is Active** — סמנו כפעיל.
4. שמרו. רשומת הפרופיל היא ה"מסך עבודה" — עליה יושב פקד ה‑**Mapping Studio**.

> ⚠️ שימו לב: בטבלת ה‑Sync Profile ערכי הסביבה **הפוכים** מטבלת ההגדרות (Sandbox=`100000000`, Production=`100000001`). ה‑UI מטפל בזה — פשוט בחרו לפי השם.

---

## שלב 3 — מיפוי הטבלה שלך (Mapping Studio)

בתוך רשומת ה‑Sync Profile, בפקד **Mapping Studio**:

1. **בחירת טבלת מקור** — בחרו את הטבלה לסנכרון (למשל `contact`, `account`, או טבלה מותאמת `new_customerproduct`).
   פעולה זו יוצרת **Entity Mapping** (`alex_payplus_entitymapping`) עם `Source Table Logical Name`.
2. **בחירת אובייקט PayPlus היעד** — למשל `Customer`.
3. **מיפוי שדות (Field Mapping)** — עבור כל שדה יעד ב‑PayPlus בחרו את שדה המקור המתאים.
   - טבלאות סטנדרטיות מקבלות **הצעות מיפוי אוטומטיות**; לטבלאות מותאמות ממפים ידנית.
   - שדות חובה של PayPlus מסומנים — ודאו שכולם ממופים.
4. *(אופציונלי)* **Transform Rule** — המרות ערך (פורמט, איחוד שדות וכו').
5. *(אופציונלי)* **Value Mapping** — מיפוי ערכי בחירה (Choice) בין D365 ל‑PayPlus (למשל קודי מדינה/מטבע).
6. *(אופציונלי)* **Filter Rule** — סינון אילו רשומות מקור זכאיות לסנכרון.
7. הפעילו את ה‑Entity Mapping (**Is Active**).

> 💡 **המלצה לפתיחה:** התחילו במיפוי מלא אחד — `contact → Customer` — כדי לוודא שכל הרכיבים עובדים לפני הרחבה לטבלאות נוספות.

---

## שלב 4 — הפעלת זיהוי אירועים (Plugin או Polling)

יש שתי דרכים ליצור משימות סנכרון כשרשומת מקור נוצרת/מתעדכנת:

| שיטה | מתי מתאים | איך |
|------|-----------|-----|
| **Async Plugin Step** | טבלאות עם שינויים תכופים; סנכרון כמעט מיידי | ב‑Entity Mapping הגדירו **Plugin Step Status** להפעלה — נרשם Step על Create/Update של טבלת המקור. |
| **Polling** (חלופה) | טבלאות מותאמות ללא Plugin Step, או סנכרון תקופתי | ה‑Flow סורק תקופתית רשומות זכאיות ויוצר Outbox. |

בשתי השיטות, שינוי בשדה **ממופה** יוצר/מעדכן רשומת **Sync Outbox** במצב `Pending`.

---

## שלב 5 — הפעלת ה‑Flow המעבד

1. ודאו שה‑Flow **`PayPlus - Process Sync Outbox`** (מובנה בבסיס) מופעל (**Turn on**).
2. ה‑Flow קורא כל משימת Outbox, בונה payload לפי ה‑Field Mapping, מסתעף לפי סביבת הפרופיל
   (Sandbox / Production), קורא ל‑Connector המתאים, ושומר את התוצאה:
   - **PayPlus UID** נשמר ב‑**Sync State** (`alex_payplus_syncstate`) — כך רשומה קיימת מתעדכנת ולא נוצרת מחדש.
   - הצלחות/כשלים נרשמים ב‑**Sync Log** (`alex_payplus_synclog`).

### מדיניות "UID חסר" (Missing UID Policy)
כשמתעדכנת רשומה שאין לה עדיין UID ב‑PayPlus, בוחרים התנהגות ברמת ה‑Entity Mapping:

| מדיניות | התנהגות | מומלץ ל |
|---------|----------|---------|
| **Create** | יוצר רשומה חדשה ב‑PayPlus | לקוחות, מוצרים |
| **Block** | עוצר וממתין לבדיקה ידנית | מסמכים פיננסיים |
| **Failed** | מסמן ככשל לטיפול | תרחישים רגישים |

---

## שלב 6 — בדיקה קצה‑לקצה

1. צרו/עדכנו רשומה בטבלת המקור (למשל `contact` חדש שעומד בכלל הסינון).
2. ודאו שנוצרה רשומת **Sync Outbox** במצב `Pending`.
3. המתינו לריצת ה‑Flow (או הריצו ידנית) → הסטטוס עובר ל‑`Processed`.
4. ודאו שנוצר **Sync State** עם ה‑**PayPlus UID**, ורשומה מקבילה קיימת בצד PayPlus.
5. עדכנו שוב את הרשומה → מתעדכנת אותה רשומה ב‑PayPlus (לא נוצרת חדשה).

---

## שלב 7 — הרחבה לטבלאות נוספות

חזרו על **שלב 3** לכל טבלה נוספת (`account`, מוצרים, טבלאות מותאמות וכו').
כל מקור חדש הוא **Entity Mapping + Field Mapping** נוסף — **ללא שינוי ב‑Flow וללא קוד**.

---

## פתרון תקלות נפוצות

| תופעה | סיבה אפשרית | פתרון |
|--------|--------------|--------|
| לא נוצר Outbox בעדכון רשומה | השדה שעודכן אינו ממופה, או ה‑Plugin Step כבוי | בדקו Field Mapping ו‑Plugin Step Status; לחלופין הפעילו Polling. |
| Outbox נתקע ב‑`Pending` | ה‑Flow כבוי או ה‑Connection לא תקין | הפעילו את `Process Sync Outbox`; בדקו את ה‑Connection Reference. |
| נוצרות כפילויות ב‑PayPlus | חסר Sync State / קורלציה | ודאו שה‑UID נשמר; השתמשו ב‑`alex_correlationkey`. |
| שדה חובה של PayPlus ריק | לא מופה במלואו | השלימו את ה‑Field Mapping לכל שדות החובה. |
| ערך Choice לא מתקבל ב‑PayPlus | חסר Value Mapping | הגדירו Value Mapping לערכי הבחירה. |

---

## נספח — טבלאות המנוע

| טבלה | Logical Name | תפקיד |
|------|--------------|--------|
| Sync Profile | `alex_payplus_syncprofile` | הגדרות סביבה והתנהגות ברירת מחדל |
| Entity Mapping | `alex_payplus_entitymapping` | טבלת מקור ↔ אובייקט PayPlus |
| Field Mapping | `alex_payplus_fieldmapping` | מיפוי שדות |
| Filter Rule | `alex_payplus_filterrule` | זכאות רשומת מקור |
| Transform Rule | `alex_payplus_transformrule` | המרות ערך |
| Value Mapping | `alex_payplus_valuemapping` | מיפוי ערכי Choice |
| Sync Outbox | `alex_payplus_syncoutbox` | תור משימות סנכרון |
| Sync State | `alex_payplus_syncstate` | קורלציה + PayPlus UID |
| Sync Log | `alex_payplus_synclog` | היסטוריית ריצה ושגיאות |

> כל הטבלאות והפקד **Mapping Studio** כלולים בפתרון הבסיס — אין צורך ב‑Sales ואין צורך בקוד.
