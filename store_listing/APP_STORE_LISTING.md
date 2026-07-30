# HalalCalorie — App Store & Google Play Listing

Metadata must match the shipped app exactly. A listing that promises
features the build does not have, or that makes health claims the app
cannot support, is the most common cause of review rejection.

---

## 1. Identity

| Field | Value |
|---|---|
| App name | HalalCalorie |
| Subtitle / short line | Halal calorie & habit tracker |
| Application id | `com.halalcalorie.app` |
| Category | Health & Fitness |
| Content rating | Everyone / 4+ |
| Price | Free, with an optional premium subscription |
| Languages | Arabic, English, French, Turkish, Urdu, Malay, Indonesian |

Do not use any earlier working title in listings, screenshots, product
ids or support pages. The store name, the in-app name and the package
id must all read HalalCalorie.

---

## 2. Positioning

HalalCalorie is a calorie and habit tracker with halal ingredient
checking built in. It is a food-logging app first: the halal check is a
feature, not a religious service, and the app does not present itself
as issuing religious rulings.

Tone for all copy: practical, calm, specific. Describe what the app
does. Avoid devotional language, do not quote scripture in store copy,
and never imply the app heals, treats, diagnoses or prevents anything.

---

## 3. Long description (English)

HalalCalorie helps you log what you eat, keep an eye on your habits,
and check whether a product's ingredients are halal — in one app, in
your language.

**Log food quickly**
• Search a food and pick from a list of real matches, not a single guess
• Scan a barcode to pull ingredients and nutrition from Open Food Facts
• Photograph a meal for an estimated breakdown of its items
• Choose grams, pieces, cups, tablespoons or millilitres
• Over a thousand foods built in, including Egyptian, Gulf, Levantine,
  Pakistani, Malay and Indonesian dishes

**Check ingredients**
• Barcode lookups flag ingredients commonly considered haram or doubtful
• Every result shows the ingredient list it was based on
• Results are informational — verify with the manufacturer or your own
  certifying body when it matters

**Track the day**
• Calories, protein, carbs and fat against goals from your own profile
• Water, sleep, steps and workout minutes
• Weight log with charts
• Body metrics: BMI, BMR, TDEE and related estimates

**The Ascent system**
• Eight daily quests — nourish, hydrate, rest, move, train, stillness,
  restraint and wholesome eating
• Quests feed a daily score, the score earns XP, and XP raises your
  level and rank
• A chain multiplier rewards consistency over intensity
• Weekly review and unlockable titles

**Ramadan mode**
• Iftar and suhoor countdowns from real prayer times for your city
• A dial showing how far through the current window you are
• Lighter workouts and fasting-friendly meal guidance
• A calendar-accurate day counter

**Prayer times**
• Daily times for your city via the Aladhan API
• Next-prayer countdown on the home screen

**Private by default**
• Your log lives on your device
• No ads, and we do not sell your data

HalalCalorie provides general wellbeing information only. It is not a
substitute for professional medical advice, diagnosis or treatment.
Consult a qualified healthcare professional before making health
decisions. It does not issue religious rulings; halal information is
provided to help you decide for yourself.

---

## 4. Long description (Arabic)

هلال كالوري يساعدك على تسجيل ما تأكله، ومتابعة عاداتك اليومية،
والتحقق من مكوّنات المنتجات — في تطبيق واحد وبلغتك.

**تسجيل سريع للطعام**
• ابحث عن الطعام واختر من قائمة نتائج حقيقية، لا نتيجة واحدة
• امسح الباركود لجلب المكوّنات والقيم الغذائية من Open Food Facts
• صوّر وجبتك للحصول على تقدير لمكوّناتها
• اختر الجرام أو الحبة أو الكوب أو الملعقة أو الملليلتر
• أكثر من ألف طعام مضمّن، منها أطباق مصرية وخليجية وشامية وباكستانية
  وماليزية وإندونيسية

**فحص المكوّنات**
• يبرز الماسح المكوّنات التي تُعد عادةً حرامًا أو مشبوهة
• كل نتيجة تعرض قائمة المكوّنات التي بُنيت عليها
• النتائج للاستدلال فقط — راجع الشركة أو جهة الاعتماد عند الحاجة

**متابعة اليوم**
• السعرات والبروتين والكارب والدهون مقابل أهداف ملفك الشخصي
• الماء والنوم والخطوات ودقائق التمرين
• سجل الوزن مع الرسوم البيانية
• مقاييس الجسم: BMI و BMR و TDEE وما يتصل بها

**نظام الصعود**
• ثماني مهام يومية ترفع مستواك ورتبتك
• مضاعف السلسلة يكافئ الاستمرارية لا الشدّة
• مراجعة أسبوعية وألقاب تُفتح مع الوقت

**وضع رمضان**
• عدّاد للإفطار والسحور من أوقات الصلاة الحقيقية لمدينتك
• قرص يوضح موضعك من النافذة الحالية
• تمارين أخفّ وإرشادات غذائية مناسبة للصائم

**خصوصيتك أولاً**
• سجلّك يبقى على جهازك
• بلا إعلانات، ولا نبيع بياناتك

هذا التطبيق يقدّم معلومات عامة عن العافية فقط، وليس بديلاً عن
المشورة أو التشخيص أو العلاج الطبي المتخصص. استشر مختصًا مؤهلاً قبل
اتخاذ قرارات صحية. ولا يصدر التطبيق فتاوى؛ معلومات الحلال معروضة
لتساعدك على القرار بنفسك.

---

## 5. Keywords

```
halal, calorie counter, food scanner, barcode, nutrition, macros,
fitness, ramadan, prayer times, arabic, حلال, سعرات, تغذية, رمضان
```

Keep identity terms to what genuinely describes the app. Do not
keyword-stuff.

---

## 6. In-app purchases

| Product id | Type | Notes |
|---|---|---|
| `halalcalorie_premium_monthly` | Auto-renewing subscription | Regional pricing |
| `halalcalorie_premium_yearly` | Auto-renewing subscription | Regional pricing, discounted |

Every paid feature must be reachable through Play Billing / StoreKit.
Do not present any other payment path, donation flow or external
checkout link inside the app.

Premium unlocks: the Ascent system, unlimited photo analysis, the
advanced workout library, the AI meal planner, exact body-composition
figures and the weekly report.

Subscription screens must state the price, the billing period, the
renewal behaviour and how to cancel, and must link to the terms and the
privacy policy.

---

## 7. Screenshots (5)

1. **Home** — greeting, calorie ring, stat row, Ascent card
2. **Add food** — search results list with thumbnails and macros
3. **Scanner** — a barcode result with its halal status and ingredients
4. **Ascent** — level ring, rank, quest board
5. **Ramadan mode** — countdown dial with iftar and suhoor times

Sizes: 6.7" and 6.5" for App Store; phone and 7"/10" tablet for Play.

Use real screenshots from the shipped build. Do not composite features
that do not exist, and do not show a different app name.

---

## 8. Review notes

```
HalalCalorie is a calorie and habit tracker with halal ingredient
checking.

What to test:
1. Nutrition tab → Add food → search "rice" → a list of matches appears
2. Scanner tab → enter a barcode → halal status plus the ingredient list
3. Profile → Upgrade → subscription options via platform billing

Notes for review:
• Ingredient data comes from Open Food Facts (open data). Halal
  information is informational and labelled as such; the app does not
  issue religious rulings.
• Meal-photo and body-photo estimates come from a third-party vision
  model. Both screens label results as estimates and carry a disclaimer
  that they are not a medical assessment. Photos are not stored.
• Prayer times come from the public Aladhan API using the city the user
  picks. No location permission is required.
• Health content is general wellbeing information. The app makes no
  claim to diagnose, treat, cure or prevent any condition, and a medical
  disclaimer appears on the home and body screens.
• All premium access is sold through the platform's billing system.
• Camera access is requested only for barcode and meal photos, and
  notifications only for reminders the user turns on.

No account or login is required. All data is stored locally.
No social features and no user-generated content.
```

---

## 9. Compliance checklist

- [ ] Store name, in-app name, package id and product ids all say HalalCalorie
- [ ] No health, healing or treatment claims in listing or app copy
- [ ] Medical disclaimer visible in-app, not only in the listing
- [ ] Photo-analysis results labelled as estimates
- [ ] Halal results labelled informational, with sources shown
- [ ] Privacy policy URL live and reachable from inside the app
- [ ] Data-safety form matches what the app actually collects
- [ ] Only camera and notification permissions requested, each on first use
- [ ] All purchases go through platform billing; no external payment path
- [ ] Subscription price, period and cancellation shown before purchase
- [ ] Screenshots taken from the shipped build
- [ ] Target SDK meets the current Play requirement
- [ ] Every listed language renders correctly, including RTL
