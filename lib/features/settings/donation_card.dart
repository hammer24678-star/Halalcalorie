// ============================================================
//  donation_card.dart — Sadaqah Jariyah donation UI
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/donation_service.dart';

class DonationCard extends ConsumerStatefulWidget {
  final bool isAr;
  const DonationCard({super.key, required this.isAr});

  @override
  ConsumerState<DonationCard> createState() => _DonationCardState();
}

class _DonationCardState extends ConsumerState<DonationCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.barakahGold.withOpacity(0.12),
            AppColors.barakahGold.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.barakahGold.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _loading ? null : _showDonationSheet,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Text('💛', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isAr ? 'ادعم التطبيق — صدقة جارية' : 'Support the app',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: AppColors.barakahGold,
                    ),
                  ),
                  Text(
                    widget.isAr
                        ? 'كل دعم يساعدنا على الاستمرار في خدمة المسلمين'
                        : 'Help us keep serving the Muslim community',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.barakahGold.withOpacity(0.75),
                    ),
                  ),
                ],
              )),
              Icon(Icons.favorite_rounded,
                  color: AppColors.barakahGold.withOpacity(0.6), size: 18),
            ]),
          ),
        ),
      ),
    );
  }

  void _showDonationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('💛', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            widget.isAr ? 'جزاك الله خيراً' : 'JazakAllah Khayran',
            style: const TextStyle(
              fontFamily: 'Cairo', fontSize: 22,
              fontWeight: FontWeight.w900, color: AppColors.barakahGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isAr
                ? 'دعمك يجعل هذا التطبيق صدقة جارية
تستمر في خدمة المسلمين'
                : 'Your support keeps this app as Sadaqah Jariyah',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo', fontSize: 13,
              color: Colors.white.withOpacity(0.65), height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          // Donation amounts
          for (final amount in [
            widget.isAr ? ('250 جنيه', '5') : ('5 USD', '5'),
            widget.isAr ? ('500 جنيه', '10') : ('10 USD', '10'),
            widget.isAr ? ('1000 جنيه', '20') : ('20 USD', '20'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // TODO: call DonationService.donate()
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.barakahGold,
                    side: BorderSide(
                        color: AppColors.barakahGold.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    amount.$1,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15, fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
