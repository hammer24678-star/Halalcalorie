// Covers the strength ladder: tiers, divisions, LP, 1RM estimation and
// the plate calculator.
import 'package:flutter_test/flutter_test.dart';
import 'package:halalcalorie/core/strength.dart';

void main() {
  group('ladder shape', () {
    test('nine tiers, Legend last and undivided', () {
      expect(kStrengthTiers.length, kTierCount);
      expect(kStrengthTiers.last.nameEn, 'Legend');
      expect(kStrengthTiers.last.hasDivisions, isFalse);
      for (final t in kStrengthTiers.take(kTierCount - 1)) {
        expect(t.hasDivisions, isTrue, reason: t.nameEn);
      }
    });

    test('tier order starts at Copper and passes Silver, Gold, Diamond', () {
      final names = kStrengthTiers.map((t) => t.nameEn).toList();
      expect(names.first, 'Copper');
      expect(names.indexOf('Silver'), greaterThan(names.indexOf('Copper')));
      expect(names.indexOf('Gold'), greaterThan(names.indexOf('Silver')));
      expect(names.indexOf('Diamond'), greaterThan(names.indexOf('Gold')));
    });

    test('zero LP is Copper I', () {
      const rank = StrengthRank(0);
      expect(rank.tier.nameEn, 'Copper');
      expect(rank.division, 1);
      expect(rank.lp, 0);
      expect(rank.label(), 'Copper I');
    });

    test('divisions advance every 100 LP inside a tier', () {
      expect(const StrengthRank(99).label(), 'Copper I');
      expect(const StrengthRank(100).label(), 'Copper II');
      expect(const StrengthRank(200).label(), 'Copper III');
      expect(const StrengthRank(300).label(), 'Bronze I');
      expect(const StrengthRank(600).label(), 'Silver I');
      expect(const StrengthRank(900).label(), 'Gold I');
    });

    test('the very top is Legend and reports as maxed', () {
      const top = StrengthRank(kMaxLp);
      expect(top.tier.nameEn, 'Legend');
      expect(top.isMax, isTrue);
      expect(top.lpToNextDivision, isNull);
      expect(top.label(), 'Legend');
      expect(top.ladderProgress, 1.0);
    });

    test('LP beyond the top clamps rather than overflowing', () {
      const beyond = StrengthRank(kMaxLp * 3);
      expect(beyond.tier.nameEn, 'Legend');
      expect(beyond.ladderProgress, 1.0);
      expect(beyond.division, 1);
    });

    test('rank fields stay in range across the whole ladder', () {
      for (var lp = 0; lp <= kMaxLp; lp += 7) {
        final rank = StrengthRank(lp);
        expect(rank.division, inInclusiveRange(1, kDivisionsPerTier));
        expect(rank.lp, inInclusiveRange(0, kLpPerDivision));
        expect(rank.divisionProgress, inInclusiveRange(0.0, 1.0));
        expect(rank.ladderProgress, inInclusiveRange(0.0, 1.0));
        expect(rank.label().trim(), isNotEmpty);
        expect(rank.shortLabel.trim(), isNotEmpty);
      }
    });

    test('Arabic labels are provided for every tier', () {
      for (final t in kStrengthTiers) {
        expect(t.nameAr.trim(), isNotEmpty, reason: t.nameEn);
      }
    });
  });

  group('one-rep max', () {
    test('a single rep is the weight itself', () {
      expect(estimateOneRepMax(100, 1), 100);
    });

    test('more reps estimate a higher max', () {
      expect(estimateOneRepMax(100, 5), greaterThan(100));
      expect(estimateOneRepMax(100, 10),
          greaterThan(estimateOneRepMax(100, 5)));
    });

    test('reps are capped so high-rep sets do not inflate the estimate', () {
      expect(estimateOneRepMax(100, 30), estimateOneRepMax(100, 12));
    });

    test('nonsense input yields zero rather than a negative max', () {
      expect(estimateOneRepMax(0, 5), 0);
      expect(estimateOneRepMax(100, 0), 0);
      expect(estimateOneRepMax(-50, 5), 0);
    });
  });

  group('scoring', () {
    final squat = liftById('squat')!;

    test('an unlogged lift sits at the very bottom', () {
      expect(rankForValue(0, squat.maleStandards).totalLp, 0);
    });

    test('hitting a tier standard lands at that tier', () {
      for (var i = 0; i < squat.maleStandards.length; i++) {
        final rank = rankForValue(squat.maleStandards[i], squat.maleStandards);
        expect(rank.tier.index, i,
            reason: 'standard $i = ${squat.maleStandards[i]}');
      }
    });

    test('a stronger lift never ranks lower', () {
      var previous = 0;
      for (var v = 0.0; v < 4.0; v += 0.02) {
        final lp = rankForValue(v, squat.maleStandards).totalLp;
        expect(lp, greaterThanOrEqualTo(previous));
        previous = lp;
      }
    });

    test('women standards are scaled, so equal load ranks higher', () {
      final maleRank = rankForSet(
          exercise: squat, isMale: true,
          bodyweightKg: 70, weightKg: 70, reps: 5);
      final femaleRank = rankForSet(
          exercise: squat, isMale: false,
          bodyweightKg: 70, weightKg: 70, reps: 5);
      expect(femaleRank.totalLp, greaterThan(maleRank.totalLp));
    });

    test('bodyweight matters: lighter lifter ranks higher for equal load', () {
      final light = rankForSet(
          exercise: squat, isMale: true,
          bodyweightKg: 60, weightKg: 100, reps: 5);
      final heavy = rankForSet(
          exercise: squat, isMale: true,
          bodyweightKg: 110, weightKg: 100, reps: 5);
      expect(light.totalLp, greaterThan(heavy.totalLp));
    });

    test('a missing bodyweight scores zero instead of dividing by zero', () {
      final rank = rankForSet(
          exercise: squat, isMale: true,
          bodyweightKg: 0, weightKg: 100, reps: 5);
      expect(rank.totalLp, 0);
    });

    test('rep-counted and timed lifts use their own units', () {
      final pushup = liftById('pushup')!;
      final plank = liftById('plank')!;
      expect(
          liftValue(
              exercise: pushup, bodyweightKg: 80, weightKg: 0, reps: 30),
          30);
      expect(
          liftValue(
              exercise: plank, bodyweightKg: 80, weightKg: 0, reps: 1,
              seconds: 120),
          120);
    });

    test('every exercise has nine ascending standards for both sexes', () {
      for (final e in kLiftExercises) {
        for (final isMale in [true, false]) {
          final s = e.standardsFor(isMale: isMale);
          expect(s.length, kTierCount, reason: e.id);
          for (var i = 1; i < s.length; i++) {
            expect(s[i], greaterThan(s[i - 1]),
                reason: '${e.id} standard $i not ascending');
          }
        }
      }
    });

    test('every exercise is labelled and grouped', () {
      for (final e in kLiftExercises) {
        expect(e.nameEn.trim(), isNotEmpty);
        expect(e.nameAr.trim(), isNotEmpty);
        expect(e.glyph.trim(), isNotEmpty);
        expect(kLiftGroups, contains(e.group), reason: e.id);
      }
      expect(kLiftExercises.map((e) => e.id).toSet().length,
          kLiftExercises.length);
    });
  });

  group('overall rank', () {
    test('no lifts logged is the bottom of the ladder', () {
      expect(overallRank(const []).totalLp, 0);
      expect(overallRank(const [StrengthRank(0)]).totalLp, 0);
    });

    test('stronger lifts pull the overall up more than weak ones drag', () {
      const strong = StrengthRank(1200);
      final alone = overallRank(const [strong]);
      final withWeak =
          overallRank(const [strong, StrengthRank(100), StrengthRank(80)]);
      // The weak lifts lower it, but nowhere near to their own level.
      expect(withWeak.totalLp, lessThan(alone.totalLp));
      expect(withWeak.totalLp, greaterThan(400));
    });

    test('a consistent set of lifts averages near that level', () {
      final rank = overallRank(
          List.generate(5, (_) => const StrengthRank(900)));
      expect(rank.totalLp, closeTo(900, 5));
    });
  });

  group('plate maths', () {
    test('an empty bar needs no plates', () {
      expect(plateBreakdown(20), isEmpty);
      expect(plateBreakdown(10), isEmpty);
    });

    test('a loadable weight breaks down and adds back up', () {
      final plates = plateBreakdown(100);
      expect(plates, isNotEmpty);
      final perSide = plates.reduce((a, b) => a + b);
      expect(20 + perSide * 2, closeTo(100, 0.01));
    });

    test('heaviest plates come first', () {
      final plates = plateBreakdown(180);
      for (var i = 1; i < plates.length; i++) {
        expect(plates[i], lessThanOrEqualTo(plates[i - 1]));
      }
    });

    test('a weight standard plates cannot make reports empty', () {
      expect(plateBreakdown(21), isEmpty);
    });
  });
}
