// Verifies that every language actually resolves, rather than silently
// falling back to English for whole screens.
import 'package:flutter_test/flutter_test.dart';
import 'package:halalcalorie/core/l10n.dart';
import 'package:halalcalorie/core/translations.dart';

void main() {
  group('tLang', () {
    test('Arabic returns the Arabic argument', () {
      expect(tLang('ar', 'مرحبا', 'Hello'), 'مرحبا');
    });

    test('English returns the English argument', () {
      expect(tLang('en', 'مرحبا', 'Hello'), 'Hello');
    });

    test('an explicit translation wins over the dictionary', () {
      expect(tLang('fr', 'مرحبا', 'Hello', 'Salut'), 'Salut');
    });

    test('a missing translation falls back to the dictionary', () {
      // 'Settings' is a dictionary key with no positional argument here.
      expect(tLang('fr', 'الإعدادات', 'Settings'),
          kAutoTranslations['Settings']!['fr']);
      expect(tLang('tr', 'الإعدادات', 'Settings'),
          kAutoTranslations['Settings']!['tr']);
      expect(tLang('ur', 'الإعدادات', 'Settings'),
          kAutoTranslations['Settings']!['ur']);
      expect(tLang('ms', 'الإعدادات', 'Settings'),
          kAutoTranslations['Settings']!['ms']);
      expect(tLang('id', 'الإعدادات', 'Settings'),
          kAutoTranslations['Settings']!['id']);
    });

    test('a positional slot echoing English still hits the dictionary', () {
      // Older call sites pass the English string into every slot.
      expect(tLang('fr', 'الإعدادات', 'Settings', 'Settings', 'Settings',
              'Settings', 'Settings'),
          kAutoTranslations['Settings']!['fr']);
    });

    test('Urdu no longer falls through to Arabic', () {
      final urdu = tLang('ur', 'الإعدادات', 'Settings');
      expect(urdu, isNot('الإعدادات'));
      expect(urdu, isNot('Settings'));
    });

    test('an unknown string falls back to English, never to empty', () {
      expect(tLang('fr', 'نص', 'A string that is not in the dictionary'),
          'A string that is not in the dictionary');
    });
  });

  group('L', () {
    test('every getter returns something in every language', () {
      // A representative sweep across the screens.
      for (final lang in kSupportedLangs) {
        final l = L.fromLang(lang);
        final values = <String>[
          l.appTagline, l.start, l.next, l.back, l.save, l.cancel, l.done,
          l.skip, l.halal, l.doubtful, l.haram, l.unknown,
          l.navHome, l.navNutrition, l.navFitness, l.navHealth, l.navProfile,
          l.addFood, l.protein, l.carbs, l.fat, l.calories, l.water,
          l.breakfast, l.lunch, l.dinner, l.snack, l.addToLog,
          l.eaten, l.burned, l.left, l.todayTab, l.recipesTab, l.aiPlanTab,
          l.balanced, l.highProtein, l.highCarb, l.mindfulEatingTip,
          l.goodMorning, l.goodAfternoon, l.goodEvening,
          l.workout, l.steps, l.fitnessTitle, l.ramadanModeLabel,
          l.recommendedNow, l.filterAll, l.filterWalk, l.filterStrength,
          l.filterGentle, l.filterRamadan, l.filterBreathe, l.minLabel,
          l.healthAndWellness, l.dailyHealthScore, l.scoreExcellent,
          l.scoreVeryGood, l.scoreGood, l.scoreKeepGoing, l.dailyWaterSec,
          l.sleepLabel, l.stepsLabel, l.moodLabel, l.trackingTab,
          l.calculatorsTab, l.articlesTab, l.addCup, l.removeCup,
          l.myProfile, l.lifetimeStats, l.bodyMetrics, l.streakLabel,
          l.tonightSleep, l.viewAll, l.menMode, l.sistersMode,
          l.manLabel, l.womanLabel, l.yrsLabel,
          l.settings, l.language, l.notifications, l.macroPlans, l.noInternet,
          l.ascentTitle, l.ascentNavLabel, l.systemLabel, l.levelShort,
          l.rankLabel, l.maxLevel, l.dailyScore, l.dailyQuests,
          l.dailyQuestsHint, l.questsLabel, l.titlesLabel, l.weeklyReview,
          l.averageLabel, l.bestLabel, l.levelUp, l.levelUpNote,
          l.continueLabel, l.ascentLockedTitle, l.ascentLockedBody,
          l.upgradeCta, l.ascentHomeCard, l.todayLabel,
          l.cameraError, l.ramadanKareem, l.iftarIn, l.suhoorIn,
          l.suhoor, l.iftar, l.dayLabel, l.inDaysLabel, l.daysShort,
          l.ramadanTimesEstimated, l.ramadanFasting, l.ramadanIftarSoon,
          l.ramadanSuhoorSoon, l.ramadanEvening, l.ramadanTipFasting,
          l.ramadanTipIftarSoon, l.ramadanTipSuhoor, l.ramadanTipEvening,
          l.planIftar, l.logWater, l.openNutrition,
          l.todayCalories, l.nextPrayer, l.dailyNote, l.sleep, l.streak,
          l.lifeStats, l.fasting, l.stayStrong,
          // Ranked lifting
          l.liftTitle, l.liftNavLabel, l.overallRankLabel, l.maxRankReached,
          l.toNextDivision, l.setsToday, l.volumeToday, l.liftsRanked,
          l.needBodyweight, l.needBodyweightShort, l.notRankedYet,
          l.repsLabel, l.weightLabel, l.addedWeight, l.holdLabel,
          l.logASet, l.logSetCta, l.setLogged, l.newPersonalBest,
          l.thisSetWouldRank, l.bodyweightShort, l.bodyweightOnly,
          l.restTimer, l.standardsTitle, l.standardsHint, l.historyTitle,
          l.noSetsYet, l.perSide, l.platesNotExact, l.rankUp,
          l.yesterdayLabel, l.notFound, l.strengthCardTitle, l.openLifts,
        ];
        for (final value in values) {
          expect(value.trim(), isNotEmpty, reason: 'empty string for $lang');
        }
      }
    });

    test('weekDaysShort always has seven entries', () {
      for (final lang in kSupportedLangs) {
        expect(L.fromLang(lang).weekDaysShort.length, 7, reason: lang);
      }
    });

    test('only Arabic and Urdu lay out right-to-left', () {
      expect(L.fromLang('ar').isRtl, isTrue);
      expect(L.fromLang('ur').isRtl, isTrue);
      expect(L.fromLang('en').isRtl, isFalse);
      expect(L.fromLang('fr').isRtl, isFalse);
      expect(L.fromLang('tr').isRtl, isFalse);
      expect(L.fromLang('ms').isRtl, isFalse);
      expect(L.fromLang('id').isRtl, isFalse);
    });

    test('isAr is Arabic only, so Urdu gets its own copy', () {
      expect(L.fromLang('ar').isAr, isTrue);
      expect(L.fromLang('ur').isAr, isFalse);
    });
  });

  group('dictionary', () {
    test('every row covers all five fallback languages', () {
      const langs = ['fr', 'tr', 'ur', 'ms', 'id'];
      final gaps = <String>[];
      kAutoTranslations.forEach((en, row) {
        for (final lang in langs) {
          final value = row[lang];
          if (value == null || value.trim().isEmpty) gaps.add('$en/$lang');
        }
      });
      expect(gaps, isEmpty, reason: 'incomplete rows: ${gaps.take(10)}');
    });

    test('no row is keyed by an interpolated string', () {
      // Those keys could never match a runtime value.
      final bad = kAutoTranslations.keys.where((k) => k.contains(r'$'));
      expect(bad, isEmpty, reason: 'interpolated keys: ${bad.take(5)}');
    });
  });
}
