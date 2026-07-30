// Covers the Ascent progression maths and the Hijri calendar helper the
// Ramadan UI depends on.
import 'package:flutter_test/flutter_test.dart';
import 'package:halalcalorie/core/ascent.dart';
import 'package:halalcalorie/core/hijri.dart';

void main() {
  group('levels and XP', () {
    test('zero XP is level 1', () {
      expect(levelFromXp(0), 1);
      expect(xpIntoLevel(0), 0);
      expect(levelProgress(0), 0);
    });

    test('one level costs exactly xpToAdvance', () {
      expect(levelFromXp(xpToAdvance(1) - 1), 1);
      expect(levelFromXp(xpToAdvance(1)), 2);
    });

    test('progress is monotonic and stays in range', () {
      var previousLevel = 1;
      for (var xp = 0; xp < 60000; xp += 37) {
        final level = levelFromXp(xp);
        expect(level, greaterThanOrEqualTo(previousLevel));
        expect(levelProgress(xp), inInclusiveRange(0.0, 1.0));
        expect(xpIntoLevel(xp), greaterThanOrEqualTo(0));
        previousLevel = level;
      }
    });

    test('the level curve is capped', () {
      expect(levelFromXp(100000000), kMaxLevel);
      expect(levelProgress(100000000), 1.0);
    });

    test('xpAtLevelStart lines up with levelFromXp', () {
      for (var level = 1; level <= 40; level++) {
        final start = xpAtLevelStart(level);
        expect(levelFromXp(start), level, reason: 'level $level');
        if (level > 1) expect(levelFromXp(start - 1), level - 1);
      }
    });
  });

  group('ranks', () {
    test('rank letters follow the level bands', () {
      expect(rankForLevel(1).letter, 'E');
      expect(rankForLevel(4).letter, 'E');
      expect(rankForLevel(5).letter, 'D');
      expect(rankForLevel(10).letter, 'C');
      expect(rankForLevel(20).letter, 'B');
      expect(rankForLevel(35).letter, 'A');
      expect(rankForLevel(55).letter, 'S');
      expect(rankForLevel(80).letter, 'SS');
      expect(rankForLevel(kMaxLevel).letter, 'SS');
    });

    test('nextRankLevel points at the following band, null at the top', () {
      expect(nextRankLevel(1), 5);
      expect(nextRankLevel(54), 55);
      expect(nextRankLevel(80), isNull);
    });
  });

  group('daily XP', () {
    test('a zero-score day earns nothing', () {
      expect(xpForDay(score: 0, chainDays: 0, allQuests: false), 0);
    });

    test('the chain multiplier is bounded at 2x', () {
      expect(chainMultiplier(0), 1.0);
      expect(chainMultiplier(-5), 1.0);
      expect(chainMultiplier(1000), 2.0);
      expect(chainMultiplier(10), greaterThan(1.0));
    });

    test('a longer chain never earns less for the same score', () {
      var previous = 0;
      for (var chain = 0; chain <= 40; chain++) {
        final xp = xpForDay(score: 800, chainDays: chain, allQuests: false);
        expect(xp, greaterThanOrEqualTo(previous));
        previous = xp;
      }
    });

    test('a clean sweep adds a bonus', () {
      final plain = xpForDay(score: 1000, chainDays: 0, allQuests: false);
      final swept = xpForDay(score: 1000, chainDays: 0, allQuests: true);
      expect(swept, greaterThan(plain));
    });
  });

  group('AscentState', () {
    test('an empty state scores zero and nothing is done', () {
      const state = AscentState();
      expect(state.score, 0);
      expect(state.questsDone, 0);
      expect(state.allQuestsDone, isFalse);
      expect(state.level, 1);
    });

    test('all eight quests full is a 1000 score', () {
      final state = AscentState(
        quests: {for (final q in kQuests) q.id: kQuestMax},
      );
      expect(state.score, 1000);
      expect(state.questsDone, kQuests.length);
      expect(state.allQuestsDone, isTrue);
    });

    test('quest points above the cap do not inflate the score', () {
      final state = AscentState(
        quests: {for (final q in kQuests) q.id: kQuestMax * 3},
      );
      expect(state.score, 1000);
    });

    test('there are eight quests and each has a distinct id', () {
      expect(kQuests.length, 8);
      expect(kQuests.map((q) => q.id).toSet().length, 8);
      expect(kQuests.length * kQuestMax, 1000);
    });

    test('grades are non-empty at every score band', () {
      for (final score in [0, 350, 550, 750, 950]) {
        final state = AscentState(
          quests: {QuestId.nourish: score},
        );
        expect(state.gradeEn().trim(), isNotEmpty);
        expect(state.gradeAr().trim(), isNotEmpty);
      }
    });
  });

  group('titles', () {
    test('ids are unique and every title is labelled', () {
      expect(kTitles.map((t) => t.id).toSet().length, kTitles.length);
      for (final title in kTitles) {
        expect(title.nameEn.trim(), isNotEmpty);
        expect(title.nameAr.trim(), isNotEmpty);
        expect(title.descEn.trim(), isNotEmpty);
        expect(title.descAr.trim(), isNotEmpty);
        expect(title.glyph.trim(), isNotEmpty);
      }
    });
  });

  group('Hijri calendar', () {
    test('a known conversion lands in the right month', () {
      // 1 Ramadan 1446 fell on 1-2 March 2025; the tabular calendar is
      // accurate to about a day, so allow that tolerance.
      final hijri = HijriDate.fromGregorian(DateTime(2025, 3, 2));
      expect(hijri.month, HijriDate.ramadanMonth);
      expect(hijri.year, 1446);
      expect(hijri.day, lessThanOrEqualTo(3));
    });

    test('conversion is stable and monotonic across a decade', () {
      var date = DateTime(2024, 1, 1);
      var previous = HijriDate.fromGregorian(date);
      for (var i = 0; i < 3650; i++) {
        date = date.add(const Duration(days: 1));
        final current = HijriDate.fromGregorian(date);
        expect(current.day, inInclusiveRange(1, 30));
        expect(current.month, inInclusiveRange(1, 12));
        // The day either advances or the month rolls over.
        final rolled = current.month != previous.month;
        if (!rolled) expect(current.day, previous.day + 1);
        previous = current;
      }
    });

    test('daysUntilRamadan is zero during Ramadan and positive outside', () {
      expect(HijriDate.daysUntilRamadan(DateTime(2025, 3, 5)), 0);
      final outside = HijriDate.daysUntilRamadan(DateTime(2025, 6, 1));
      expect(outside, greaterThan(0));
      expect(outside, lessThan(400));
    });

    test('month names exist in both languages for all twelve months', () {
      for (var month = 1; month <= 12; month++) {
        final hijri = HijriDate(1446, month, 1);
        expect(hijri.monthName().trim(), isNotEmpty);
        expect(hijri.monthName(arabic: true).trim(), isNotEmpty);
      }
    });

    test('illumination peaks mid-month and is dark at the edges', () {
      expect(moonIllumination(1), lessThan(0.15));
      expect(moonIllumination(15), greaterThan(0.9));
      expect(moonIllumination(30), lessThan(0.15));
      for (var day = 1; day <= 30; day++) {
        expect(moonIllumination(day), inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
