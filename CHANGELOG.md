# HalalCalorie Changelog

## v1.0.0+10 — Release polish
*2026-07-30*

### 🆕 The Ascent system (replaces the Barakah engine)
- Rebuilt as a game-style progression layer: eight **daily quests** feed a
  0-1000 daily score, the score converts to **XP**, XP raises a **level**
  (1-99), and levels map onto **ranks** E → D → C → B → A → S → SS
- **Chain multiplier** up to 2× for consecutive qualifying days, so
  consistency is worth more than one heavy day
- Level-up sequence with a system-panel dialog and confetti
- **Weekly review** now shows every day of the week — the old Friday
  report was hidden six days out of seven
- 24 unlockable **titles** replace the old badge shelf; earned badges
  carry over from the previous key
- New screen at `/ascent` with a starfield, bracketed system panels and a
  dual-arc level ring; `/barakah` redirects so old links still work
- Quests now update live as meals, water, sleep, steps and workouts are
  logged, instead of only on screen open

### 🌙 Ramadan mode rebuilt
- Iftar and suhoor now come from **real prayer times** for the user's city;
  the old build hardcoded 18:05 and 05:12
- Day counter comes from a **tabular Hijri calendar** — the old build had a
  fixed 2025 start date and had already frozen at "day 30"
- Countdown dial shows progress through the current fasting or evening
  window, with phase-aware colours and copy
- Moon is drawn at the month's actual phase
- Practical per-phase guidance replaces the scripture strip

### 🌍 Localization — all seven languages now resolve
- Urdu no longer falls through to Arabic; it has its own strings and keeps
  RTL layout
- New shared dictionary (`core/translations.dart`, 537 entries × 5
  languages) that `tLang()` consults whenever a call site omits a
  language, so screens passing only Arabic and English still localize
- Positional slots that merely echoed English now fall through to the
  dictionary instead of showing English
- Interpolated labels restructured so their static half localizes

### 🔎 Search returns results, plural
- `AIService.searchFoods()` merges the built-in portion list, the offline
  per-100g table, Open Food Facts and a model fallback, de-duplicated
- Results list with thumbnails, macros, per-source badges and a direct
  route to manual entry; the old flow surfaced exactly one guess
- Portion-based entries get a servings picker; per-100g entries keep the
  unit picker, so the two are no longer conflated

### 🍽️ Food glyphs and thumbnails
- New `core/food_emoji.dart`: a few hundred foods keyed in Arabic,
  English, French, Turkish, Malay/Indonesian and Urdu, matched
  longest-keyword-first, replacing a 30-entry if-chain
- `FoodThumb` falls back to an Open Food Facts photo when a food has no
  glyph and the device is online, and to a neutral plate when it does not

### 🛡️ Store-policy hardening
- Removed unsubstantiated health claims throughout: "cure for every
  disease", "in it is healing", "water — cure for everything",
  antibacterial and gut-renewal claims, and the remedy-style recipe
- All ten health articles rewritten as general wellbeing information with
  reference ranges and explicit "see a professional" framing
- Naming softened across the app: no more Barakah, Al-Mujahid, Sunnah
  Warrior, Islamic HIIT, Islamic Fitness, Dhikr Power Walk or
  Bismillah/hadith cards; quests use Stillness, Restraint and Wholesome
- Daily hadith rotation replaced with 30 practical daily notes
- Deleted the orphaned donation flow — it did not compile, was
  unreachable, and an off-Billing payment path is a policy hazard
- Store listings and README rewritten: consistent app name, accurate
  feature list, no health claims, review notes and a compliance checklist
- Corrected copy that credited Claude for analysis the app runs on Groq

### 🐛 Fixes
- Database upgrades are now additive from v6 — meals, weights and daily
  summaries survive an app update instead of being dropped
- Progress history migrates from `barakah_log` into `ascent_log`
- Chain multiplier reaches exactly 2× at 30 days (was 1.999)
- Removed emoji keys short enough to match inside unrelated words

### 🧪 Tests
- 35 tests covering the translation fallback chain, every `L` getter in
  all seven languages, dictionary completeness, the XP/level/rank curve
  and the Hijri conversion

---

## v0.5.0 — Premium & Store Release Prep
*Released: 2026-03-05*

### 🆕 New: RevenueCat Integration
- Full in-app purchase system via RevenueCat
- **Apple Pay** and **Google Pay** appear automatically in the purchase sheet
- 3 plans: Monthly (EGP 399) · Yearly (EGP 3,299, save 30%) · Lifetime (EGP 7,999)
- Entitlement: `premium_access` gates all premium features
- Restore Purchases button on paywall and profile
- Subscription management sheet in Profile → shows active plan, cancel instructions
- Premium badge in profile updates dynamically: "Monthly Premium" / "Yearly Premium" / "Lifetime Premium"
- RevenueCat logout on sign-out (cross-device sync)
- Local cache prevents premium flash on app start

### 🆕 New: Premium Enforcement
- **Body fat %** exact value: Premium only (free users see 🔒)
- **Muscle mass** in kg: Premium only
- **Lean Body Mass**: Premium only
- **Body photo AI analysis**: Premium only (full privacy consent screen)
- **Halal scanner**: 10/day free → unlimited Premium
- **180 advanced workouts**: Premium only (free shows 10 basic)
- **AI meal planner**: Premium only

### 🆕 New: Platform Config
- `ios/Runner/Info.plist` — all camera/photo/notification permissions with correct descriptions
- `android/app/src/main/AndroidManifest.xml` — BILLING + CAMERA + INTERNET permissions
- `android/app/build.gradle` — minSdk 21, ProGuard rules for RevenueCat
- `android/app/proguard-rules.pro` — keeps RevenueCat & Flutter classes

### 🆕 New: Store Listing Pack
- `store_listing/APP_STORE_LISTING.md` — complete App Store & Google Play listing
  - App name, subtitle, 4000-char description (bilingual)
  - Keywords optimized for "halal", "حلال", "Muslim fitness"
  - In-app purchase table (all 3 products)
  - Screenshot guide (5 screens, sizes, design brief)
  - App icon design specs
  - 15-item submission checklist
  - App Review Notes for Apple
  - Pricing matrix: Egypt, Saudi, UAE, Jordan, USA, UK
  - ASO tips (App Store Optimization)
- `REVENUECAT_SETUP.md` — step-by-step RevenueCat configuration guide

### 🔧 Bug Fixes
- Profile screen: removed duplicate `PaywallScreen` class (was defined twice)
- Profile screen: version badge updated from 0.3 → 0.5
- Providers: `PremiumNotifier` now live-syncs with RevenueCat on app start
- Fitness screen: advanced plans upsell hidden if already premium

### 🏗️ Architecture
- `lib/core/revenuecat_service.dart` — complete RC service wrapper
  - `configure()` — call once from main.dart
  - `isPremium()` — checks live entitlement
  - `getOfferings()` — fetches live pricing, falls back to hardcoded
  - `purchase(offering)` — wraps purchasePackage with error handling
  - `restore()` — restores previous purchases
  - `getActivePlanId()` — returns monthly/yearly/lifetime/free
  - `setUserId()` / `logOut()` — for cross-device sync
- `rcOfferingsProvider` — FutureProvider for paywall live pricing
- `planNameProvider` — FutureProvider for profile plan badge

---

## v0.4.0 — AI Vision Features
*2026-03-05*
- AI Food Photo Analyzer (Claude Vision API)
- AI Body Photo Analyzer (Premium)
- Real AI Meal Planner (Nutrition tab)
- Recipe steps bug fix (String → List<String>)
- Models typing fixes

## v0.3.0 — Bilingual Complete
*2026-03-05*
- All 7 screens fully bilingual (Arabic ↔ English)
- 14-step onboarding
- Body metrics engine (15+ calculations)
- Nutrition tracker with Sunnah recipes
- Halal scanner

## v0.1–0.2 — Foundation
- Core architecture, navigation, theming
- Dark mode, RTL support
- SharedPreferences persistence
