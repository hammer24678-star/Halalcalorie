// ============================================================
//  prayer_card.dart — Prayer times card for home screen
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/prayer_provider.dart';
import '../../core/prayer_service.dart';

class PrayerTimesCard extends ConsumerStatefulWidget {
  final bool isAr;
  final bool isDark;
  const PrayerTimesCard({
    super.key, required this.isAr, required this.isDark});

  @override
  ConsumerState<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends ConsumerState<PrayerTimesCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh countdown every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prayerAsync = ref.watch(prayerTimesProvider);
    final isDark      = widget.isDark;
    final bg = isDark ? AppColors.darkCard : Colors.white;

    return prayerAsync.when(
      loading: () => _skeleton(bg),
      error:   (_, __) => const SizedBox.shrink(),
      data:    (times) {
        if (times == null) return const SizedBox.shrink();
        final next     = times.nextPrayer;
        final duration = times.timeToNextPrayer;
        final h = duration.inHours;
        final m = duration.inMinutes % 60;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sunnahGreen.withOpacity(0.2)),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4),
            )],
          ),
          child: Column(children: [
            // ── Next prayer countdown ────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.gradientGreen,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Text('🕌', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isAr
                          ? 'الصلاة القادمة: \${next.nameAr}'
                          : 'Next Prayer: \${next.nameEn}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      times.formatTime(next.time),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11, color: Colors.white70,
                      ),
                    ),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '\${h}س \${m}د',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13, fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ]),
            ),

            // ── All 5 prayers row ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: times.allPrayers.map((prayer) {
                  final isNext = prayer.nameEn == next.nameEn;
                  final isPast = prayer.time.isBefore(DateTime.now())
                      && !isNext;
                  return _PrayerItem(
                    prayer:  prayer,
                    times:   times,
                    isNext:  isNext,
                    isPast:  isPast,
                    isAr:    widget.isAr,
                    isDark:  isDark,
                  );
                }).toList(),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _skeleton(Color bg) => Container(
    height: 110, margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(16)),
    child: const Center(child: SizedBox(
      width: 20, height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2, color: AppColors.sunnahGreen),
    )),
  );
}

class _PrayerItem extends StatelessWidget {
  final PrayerInfo prayer;
  final PrayerTimes times;
  final bool isNext, isPast, isAr, isDark;
  const _PrayerItem({
    required this.prayer, required this.times,
    required this.isNext, required this.isPast,
    required this.isAr,   required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isNext ? AppColors.sunnahGreen
                : isPast ? AppColors.darkMuted
                : (isDark ? Colors.white70 : Colors.black87);

    return Column(children: [
      Text(
        isAr ? prayer.nameAr : prayer.nameEn,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 9, fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        times.formatTime(prayer.time),
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10, fontWeight: FontWeight.w800,
          color: isNext ? AppColors.sunnahGreen : color,
        ),
      ),
      if (isNext) Container(
        margin: const EdgeInsets.only(top: 2),
        width: 4, height: 4,
        decoration: const BoxDecoration(
          color: AppColors.sunnahGreen, shape: BoxShape.circle),
      ),
    ]);
  }
}
