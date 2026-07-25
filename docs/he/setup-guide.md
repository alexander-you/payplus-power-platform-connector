# מדריך הגדרה והפעלה — PayPlus ל‑Dynamics 365 / Dataverse 🇮🇱

מדריך צעד‑אחר‑צעד להתקנה, חיבור והפעלה של אינטגרציית **PayPlus ⇄ Microsoft Dynamics 365**,
כולל **איתור והפקת מפתחות ה‑API בצד PayPlus**.

> **גרסה:** v1.0.0 · **מפרסם (Publisher):** AlexanderYurpolsky (קידומת `alex`)
> **הורדת הפתרונות (Release):** <https://github.com/alexander-you/payplus-power-platform-connector/releases/tag/v1.0.0>

---

## תוכן עניינים
1. [דרישות מקדימות](#1-דרישות-מקדימות)
2. [צד PayPlus — איתור והפקת מפתחות ה‑API](#2-צד-payplus--איתור-והפקת-מפתחות-ה-api)
3. [ייבוא הפתרונות ל‑Dynamics 365](#3-ייבוא-הפתרונות-ל-dynamics-365)
4. [יצירת חיבור (Connection) וקישור Connection References](#4-יצירת-חיבור-connection-וקישור-connection-references)
5. [אשף ההגדרה (Setup Wizard) בתוך D365](#5-אשף-ההגדרה-setup-wizard-בתוך-d365)
6. [הפעלת ה‑Flows](#6-הפעלת-ה-flows)
7. [ייבוא נתוני ייחוס](#7-ייבוא-נתוני-ייחוס-מסופים-עמודים-בנקים-סוגי-מסמכים)
8. [בדיקת קצה‑לקצה](#8-בדיקת-קצה-לקצה-תשלום-ניסיון)
9. [פתרון תקלות נפוצות](#9-פתרון-תקלות-נפוצות)
10. [נספח — כתובות, endpoints ומונחים](#נספח--כתובות-endpoints-ומונחים)

---

## 1. דרישות מקדימות

לפני שמתחילים ודאו שיש ברשותכם:

| # | דרישה | פירוט |
|---|--------|--------|
| 1 | **סביבת Dataverse / Dynamics 365** | הרשאת **System Administrator** (או System Customizer) לייבוא פתרונות. |
| 2 | **חשבון PayPlus פעיל** | עסק מאושר ב‑PayPlus עם **מסוף סליקה** (Terminal) פעיל. |
| 3 | **מפתחות API של PayPlus** | `api_key` + `secret_key` — ראו [חלק 2](#2-צד-payplus--איתור-והפקת-מפתחות-ה-api). |
| 4 | **הרשאות ליצירת חיבורים** | הרשאה ליצור Connections ל‑Custom Connector בסביבה. |
| 5 | *(אופציונלי)* **Dynamics 365 Sales** | נדרש **רק** אם מתקינים את פתרון ההרחבה (quote / salesorder / invoice). |

> 💡 **טיפ:** מומלץ לבצע התקנה ראשונית בסביבת **Sandbox / בדיקות** של PayPlus לפני מעבר לפרודקשן.

---

## 2. צד PayPlus — איתור והפקת מפתחות ה‑API

האינטגרציה מזדהה מול PayPlus באמצעות **שתי כותרות (Headers)** בכל בקשה:

| כותרת | פרמטר במחבר | מקור |
|--------|--------------|------|
| `api-key` | **מפתח API** (`apiKey`) | דשבורד PayPlus |
| `secret-key` | **מפתח סודי** (`secretKey`) | דשבורד PayPlus |

### 2.1 כניסה לאזור הניהול של PayPlus
1. היכנסו לאתר **PayPlus** → <https://www.payplus.co.il> → **כניסת עסקים / אזור אישי**.
2. התחברו עם פרטי המשתמש של העסק.

### 2.2 איתור `api_key` ו‑`secret_key`
מפתחות ה‑API הם **ברמת העסק** ומופקים מתוך אזור הניהול:

1. עברו אל **הגדרות ⚙️ → API / מפתחות / חיבורים** (בממשקים מסוימים: *"הגדרות מתקדמות"* → *"API"*).
2. אתרו את שני הערכים:
   - **מפתח API** → זהו ה‑`api_key`.
   - **מפתח סודי** → זהו ה‑`secret_key`.
3. אם המפתחות אינם מוצגים או שהאפשרות אינה זמינה — יש להפעיל גישת API עבור העסק.
   פנו לתמיכת PayPlus: **tech@payplus.co.il** ובקשו הנפקת/הצגת מפתחות API עבור המסוף.

> ⚠️ **אבטחה:** ה‑`secret_key` הוא סוד. אין לשלוח אותו בדוא"ל לא מוצפן, ואין לשמור אותו בקוד או בקובץ.
> בתוך D365 הוא נשמר כ‑**securestring** בתוך ה‑Connection בלבד (מוצפן, לא ניתן לקריאה חוזרת).

### 2.3 מסוף (Terminal) ועמוד תשלום (Payment Page)
לצורך יצירת קישורי תשלום נדרשים גם:

| מזהה | מה זה | איך משיגים |
|------|--------|------------|
| `terminal_uid` | מזהה **מסוף הסליקה** | **נמשך אוטומטית** על ידי האשף (`MyTerminals`). אין צורך להעתיק ידנית. |
| `payment_page_uid` | מזהה **עמוד תשלום** מתארח | **נמשך אוטומטית** על ידי האשף (`Payment Pages List`) לאחר בחירת המסוף. |

> אם אין לכם עדיין **עמוד תשלום** מוגדר ב‑PayPlus — צרו אחד בדשבורד PayPlus תחת *"עמודי תשלום"*,
> והוא יופיע אוטומטית ברשימת הבחירה באשף.

### 2.4 סביבת Sandbox מול Production
לפתרון שני מחברים — לכל סביבה כתובת שונה:

| סביבה | מחבר בפתרון | כתובת (Host) |
|--------|--------------|--------------|
| **Production** | `PayPlus` | `restapi.payplus.co.il` |
| **Sandbox** | `PayPlus SandBox` | `restapidev.payplus.co.il` |

> למפתחות ה‑Sandbox יש להשתמש בפרטי חשבון ה‑Sandbox של PayPlus (נפרדים מהפרודקשן).
> כרטיסי אשראי לבדיקות: <https://docs.payplus.co.il/reference/sandbox-credit-card-numbers>

---

## 3. ייבוא הפתרונות ל‑Dynamics 365

הפתרון בנוי משתי שכבות. **סדר הייבוא חשוב:**

```
1) פתרון בסיס   →  alex_d365_payplus                              (עצמאי, ללא תלות ב‑Sales)
2) פתרון הרחבה  →  alex_d365_payplus_sales_extended_data_model    (דורש: בסיס + Dynamics 365 Sales)
```

### 3.1 הורדת החבילות
הורידו מ‑ה‑[Release](https://github.com/alexander-you/payplus-power-platform-connector/releases/tag/v1.0.0)
את הקבצים המתאימים:

- **סביבת בדיקות/פרודקשן** → קובצי **`_managed.zip`** (מומלץ).
- **סביבת פיתוח/התאמות** → קובצי **`_unmanaged.zip`**.

### 3.2 ייבוא פתרון הבסיס
1. היכנסו ל‑<https://make.powerapps.com> ובחרו את **הסביבה** הנכונה (בורר הסביבות בפינה הימנית העליונה).
2. תפריט **Solutions → Import solution**.
3. בחרו את `alex_d365_payplus_1_0_0_0_managed.zip` → **Next**.
4. בשלב ה‑**Connections** — ראו [חלק 4](#4-יצירת-חיבור-connection-וקישור-connection-references).
5. **Import** והמתינו לסיום.

### 3.3 ייבוא פתרון ההרחבה *(רק אם קיים Dynamics 365 Sales)*
חזרו על השלבים עם `alex_d365_payplus_sales_extended_data_model_1_0_0_0_managed.zip`.

> ⛔ **הערה:** פתרון ההרחבה **לא ייובא לבדו** — הוא תלוי בפתרון הבסיס. התקינו קודם את הבסיס.

---

## 4. יצירת חיבור (Connection) וקישור Connection References

מכיוון שחיבורים הם ספציפיים לסביבה, יש להגדירם **לאחר** הייבוא.

### 4.1 יצירת החיבור למחבר PayPlus
1. ב‑<https://make.powerapps.com> → **Connections → + New connection**.
2. חפשו **"PayPlus"** (לפרודקשן) או **"PayPlus SandBox"** (לבדיקות).
3. הזינו את הערכים מ‑[חלק 2](#2-צד-payplus--איתור-והפקת-מפתחות-ה-api):
   - **מפתח API** ← `api_key`
   - **מפתח סודי** ← `secret_key`
4. **Create**. אם החיבור נוצר בהצלחה — הפרטים תקינים.

### 4.2 קישור ה‑Connection References
בפתרון קיימות שתי הפניות חיבור שיש לקשר לחיבור שיצרתם:

| Connection Reference | שימוש |
|----------------------|--------|
| `alex_payplusprod` | חיבור הפרודקשן |
| `alex_payplussandbox` | חיבור ה‑Sandbox |

**כיצד לקשר:**
- אם קישרתם כבר בשלב ה‑Connections של הייבוא — סיימתם ✅.
- אחרת: **Solutions → PayPlus (D365) → Connection references →** פתחו כל הפניה **→** בחרו את החיבור שנוצר **→ Save**.

> ℹ️ הפניות החיבור מסופקות בעת הייבוא (Practice ALM סטנדרטי לחיבורים תלויי‑סביבה). המחברים עצמם כלולים בחבילה.

---

## 5. אשף ההגדרה (Setup Wizard) בתוך D365

הפתרון כולל **אשף הגדרה מובנה** (משאב אינטרנט `alex_payplus_setup.html`) שמלווה את התהליך
ושומר את ההתקדמות, כך שניתן לעצור ולחזור. האשף עובד ב‑4 שלבים:

| שלב | שם | מה קורה |
|-----|-----|----------|
| 1 | **CONNECT** | בחירת סביבה (Prod/Sandbox) ואימות שה‑Connection Reference מקושר לחיבור PayPlus. |
| 2 | **PAGES** | משיכת **מסופים** (`MyTerminals`) → בחירת מסוף → משיכת **עמודי תשלום** (`ListPaymentPages`) → בחירת עמוד. |
| 3 | **VALIDATE** | בדיקת חיבור אמיתית מול PayPlus (`GeneratePaymentLink` דרך ה‑Custom API `alex_ValidatePayPlusConnection`). |
| 4 | **DONE** | לוח בקרה — אימות מחדש / התחלה מחדש. |

**כיצד לפתוח את האשף:**
1. פתחו את אפליקציית ה‑Model‑Driven של PayPlus.
2. נווטו לדף **"PayPlus Setup"** (מוגדר ב‑Sitemap של הפתרון).
3. עקבו אחר השלבים 1→4. בכל שלב האשף שומר את המצב לרשומת ההגדרה (`alex_setupstage`).

> 💡 השלבים PAGES ו‑VALIDATE מריצים **Custom API → Flow → Connector**, והתוצאה נמשכת (polling)
> מרשומת ההגדרה. אם שלב "נתקע" — ודאו שה‑Flows הרלוונטיים **מופעלים** (חלק 6).

---

## 6. הפעלת ה‑Flows

לאחר קישור החיבורים יש לוודא שכל ה‑Flows **מופעלים (Turn on)**.

**Solutions → PayPlus (D365) → Cloud flows →** ודאו שכל אחד במצב **On**:

**פתרון הבסיס (14 flows):**
- PayPlus - Validate Credentials
- PayPlus - Fetch Options
- PayPlus HF Session
- PayPlus - Expire Pending Sessions
- PayPlus - Send Card Link (Email / SMS / WhatsApp)
- PayPlus - Poll Tokenization
- PayPlus - Process Sync Outbox
- PayPlus - Import Document Types
- PayPlus - Import Terminals & Pages
- PayPlus - Import Banks & Branches
- PayPlus - Document Action Request
- PayPlus - Process Workbench Payment

**פתרון ההרחבה (4 flows):**
- PayPlus - Preview Quote / Sales Order / Invoice Document
- PayPlus - Poll Invoice Payments

> אם Flow כבוי — פתחו אותו → **Turn on**. אם יש שגיאת חיבור — ודאו שה‑Connection Reference מקושר (חלק 4).

---

## 7. ייבוא נתוני ייחוס (מסופים, עמודים, בנקים, סוגי מסמכים)

להשלמת ההגדרה הריצו את זרימות הייבוא (פעם אחת, או לפי צורך לרענון):

| Flow | מה מייבא |
|------|-----------|
| PayPlus - Import Terminals & Pages | מסופים ועמודי תשלום |
| PayPlus - Import Document Types | סוגי מסמכים של Invoice+ |
| PayPlus - Import Banks & Branches | בנקים וסניפים (לארנק חשבונות בנק) |

ניתן להריץ אותן דרך האשף (שלב PAGES מפעיל את משיכת המסופים/עמודים) או ידנית מתוך **Cloud flows → Run**.

---

## 8. בדיקת קצה‑לקצה (תשלום ניסיון)

1. פתחו רשומת **חשבונית / הזמנה / איש קשר** (לפי התרחיש).
2. הפעילו את פעולת **יצירת קישור תשלום** של PayPlus (כפתור / Custom Page).
3. ודאו שנוצר **קישור תשלום** תקין.
4. ב‑Sandbox — השלימו תשלום עם [כרטיס בדיקה](https://docs.payplus.co.il/reference/sandbox-credit-card-numbers).
5. ודאו שנוצר **מסמך PayPlus** (`alex_payplusdocument`) והופיע ב‑Ledger של הרשומה.

אם כל השלבים עברו — האינטגרציה מוכנה לשימוש ✅.

---

## 9. פתרון תקלות נפוצות

| תסמין | סיבה סבירה | פתרון |
|--------|-------------|--------|
| יצירת Connection נכשלת | `api_key` / `secret_key` שגויים | בדקו שוב בדשבורד PayPlus (חלק 2). ודאו Prod מול Sandbox. |
| שלב PAGES/VALIDATE נתקע באשף | Flow כבוי או חיבור לא מקושר | הפעילו את ה‑Flows (חלק 6) וקשרו את ה‑Connection References (חלק 4). |
| "connection reference ... not bound" | לא נבחר חיבור | פתחו את ה‑Connection Reference ובחרו את החיבור → Save. |
| שינוי בסכמת המחבר לא נתפס | Cache של המחבר ב‑Power Automate | Republish למחבר ב‑Maker Portal או צרו את החיבור מחדש. |
| ההרחבה לא מתקינה | חסר פתרון בסיס / חסר Sales | התקינו קודם את הבסיס; ודאו ש‑Dynamics 365 Sales קיים. |
| שגיאת `401 / הרשאה` מ‑PayPlus | גישת API לא מופעלת לעסק | פנו ל‑**tech@payplus.co.il** להפעלת גישת API. |

---

## נספח — כתובות, endpoints ומונחים

**סביבות PayPlus:**
- Production: `https://restapi.payplus.co.il`
- Sandbox: `https://restapidev.payplus.co.il`

**Endpoints מרכזיים בשימוש:**

| פעולה | Endpoint | תיאור |
|--------|----------|--------|
| `MyTerminals` | `GET /api/v1.0/.../MyTerminals` | רשימת מסופים → `terminal_uid` |
| `Payment Pages List` | `GET /api/v1.0/PaymentPages/list` | רשימת עמודי תשלום → `payment_page_uid` |
| `GeneratePaymentLink` | `POST /api/v1.0/PaymentPages/generateLink` | יצירת קישור תשלום מתארח |
| `Get document types` | `GET /api/v1.0/Books/DocTypes` | סוגי מסמכים ל‑Invoice+ |
| `Bank List / Branches` | `GET /api/v1.0/Banks/list` | בנקים וסניפים |

**Custom APIs בפתרון (D365):**
- `alex_FetchPayPlusOptions` — משיכת מסופים / עמודי תשלום.
- `alex_ValidatePayPlusConnection` — אימות חיבור מקצה לקצה.

**מונחים:**
- **Terminal (`terminal_uid`)** — מסוף סליקה בצד PayPlus.
- **Payment Page (`payment_page_uid`)** — עמוד תשלום מתארח.
- **Connection Reference** — הפניה בפתרון המקשרת Flow לחיבור ספציפי בסביבה.

**קישורים רשמיים:**
- תיעוד PayPlus API: <https://docs.payplus.co.il/reference/introduction>
- תמיכה טכנית PayPlus: **tech@payplus.co.il**
- Release (הורדת הפתרונות): <https://github.com/alexander-you/payplus-power-platform-connector/releases/tag/v1.0.0>

---

*מסמך זה מתאר את גרסה v1.0.0 של הפתרון. שמות שדות ותוויות בדשבורד PayPlus עשויים להשתנות בין גרסאות ממשק —*
*במקרה של ספק, פנו לתמיכת PayPlus.*
