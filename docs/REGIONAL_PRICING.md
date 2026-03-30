# Regional Pricing Strategy — HalalCalorie

## Philosophy
Same app, different value per market. Price relative to income.

## Pricing Tiers

### Egypt (EGP)
- Monthly:  99 EGP  (~$2 USD)
- Annual:   799 EGP (~$16 USD)
- Donation: 250/500/1000 EGP

### Gulf (SAR/AED/KWD)
- Monthly:  $4.99 USD
- Annual:   $34.99 USD
- Donation: $5/$10/$20 USD

### Western (US/UK/EU/CA/AU)
- Monthly:  $3.99 USD
- Annual:   $24.99 USD

## How to set in Google Play Console

1. Open Play Console → your app → Monetize → Products
2. For each subscription product:
   - Click "View pricing template"
   - Select "Set price by country"
   - Egypt (EG): set EGP price manually
   - Saudi Arabia (SA), UAE (AE), Kuwait (KW): set USD equivalent
   - Rest of world: keep default

## RevenueCat Product IDs

Create these in RevenueCat dashboard:
- halalcalorie_monthly_egp    (Egypt monthly)
- halalcalorie_annual_egp     (Egypt annual)
- halalcalorie_monthly_usd    (Gulf + international monthly)
- halalcalorie_annual_usd     (Gulf + international annual)
- donation_5   (one-time)
- donation_10  (one-time)
- donation_20  (one-time)

## RevenueCat Offerings

Create 2 offerings:
1. "egypt"       → show EGP products when locale == ar_EG
2. "default"     → show USD products everywhere else

## Code to detect region (already in app)
```dart
final locale = Localizations.localeOf(context);
final isEgypt = locale.countryCode == 'EG';
final offering = isEgypt ? 'egypt' : 'default';
```

## Expected impact
Egypt:  conversion 0.5% → 3-5% (6-10x more paying users)
Gulf:   higher ARPU ($35-50/year vs $24)
Total revenue: estimated 3-5x vs flat pricing
