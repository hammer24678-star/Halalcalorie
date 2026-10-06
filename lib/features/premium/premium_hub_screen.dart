// premium_hub_screen.dart — HalalCalorie v58 (PATCH_V58_HUB)
// "Premium Studio": the front door to every Premium tool, plus the card that
// sits on the Home tab. Free users see exactly what each tool does and a
// preview of their own data, then one clear upgrade button.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/fasting_calendar.dart';
import '../../core/hijri.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'premium_ui.dart';

class _Tool {
  final IconData icon;
  final Color color;
  final String route, titleAr, titleEn, subAr, subEn;
  final bool freeTaste;
  const _Tool(this.icon, this.color, this.route, this.titleAr, this.titleEn,
      this.subAr, this.subEn,
      {this.freeTaste = false});
}

const _tools = <_Tool>[
  _Tool(Icons.psychology_alt_rounded, AppColors.sleepPurple, '/coach',
      'المدرّب الذكي', 'AI Coach',
      'يرى أرقام يومك ويجيب عن أي سؤال', 'Sees your day\u2019s numbers and answers anything',
      freeTaste: true),
  _Tool(Icons.auto_awesome_rounded, AppColors.halalGreen, '/meal-plan',
      'مخطط الوجبات', 'AI Meal Planner',
      'يومك كاملًا بسعراتك ومغذياتك + قائمة مشتريات',
      'A full day to your macros, plus a grocery list'),
  _Tool(Icons.insights_rounded, AppColors.waterBlue, '/insights',
      'رؤى متقدمة', 'Insights Pro',
      'اتجاهات ٩٠ يومًا وتوقّع وزنك وخريطة التزامك',
      '90-day trends, weight forecast and consistency map',
      freeTaste: true),
  _Tool(Icons.nightlight_round, kGold, '/fasting', 'مخطط الصيام', 'Fasting Planner',
      'الاثنين والخميس والأيام البيض وعرفة وعاشوراء مع سجل وسلسلة',
      'Mondays, Thursdays, White Days, Arafah, Ashura with a log and streak',
      freeTaste: true),
  _Tool(Icons.notifications_active_rounded, AppColors.doubtOrange, '/notifications',
      'مركز الإشعارات', 'Notification Center',
      'تذكيرات ذكية وأوقات مخصصة وسحور وإفطار',
      'Smart reminders, custom times, suhoor and iftar',
      freeTaste: true),
];

class PremiumHubScreen extends ConsumerWidget {
  const PremiumHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final th = PTheme(isDark);
    final isAr = lang == 'ar';
    String t(String ar, String en) => tLang(lang, ar, en);
    final toRamadan = HijriDate.daysUntilRamadan(DateTime.now());

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        title: Text(t('استوديو بريميوم', 'Premium Studio'),
            style: pText(th.text, 18, w: FontWeight.w900)),
        backgroundColor: th.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: th.text),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          PCard(
            th: th,
            gold: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const PBadge(Icons.workspace_premium_rounded, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        premium
                            ? t('أهلًا بك في بريميوم', 'Welcome to Premium')
                            : t('كل ما تحتاجه للوصول لهدفك', 'Everything to reach your goal'),
                        style: pText(th.text, 17, w: FontWeight.w900, h: 1.25)),
                    const SizedBox(height: 4),
                    Text(
                        premium
                            ? t('أدواتك كلها مفتوحة', 'All your tools are unlocked')
                            : t('جرّب كل أداة مجانًا أولًا', 'Try every tool for free first'),
                        style: pText(th.muted, 12.5, w: FontWeight.w600)),
                  ]),
                ),
              ]),
              if (!premium) ...[
                const SizedBox(height: 14),
                PGoldButton(
                  label: t('ترقية الآن', 'Upgrade now'),
                  icon: Icons.workspace_premium_rounded,
                  onTap: () => openPaywall(context),
                ),
              ],
            ]),
          ),
          if (toRamadan > 0 && toRamadan <= 75) ...[
            const SizedBox(height: 12),
            PCard(
              th: th,
              onTap: () => context.push('/fasting'),
              child: Row(children: [
                const PBadge(Icons.nightlight_round, size: 44, color: AppColors.sleepPurple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('رمضان بعد $toRamadan يومًا', 'Ramadan in $toRamadan days'),
                        style: pText(th.text, 15, w: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                        t('درّب جسمك بصيام الاثنين والخميس والأيام البيض',
                            'Prepare with Monday, Thursday and White Day fasts'),
                        style: pText(th.muted, 12, w: FontWeight.w600, h: 1.4)),
                  ]),
                ),
              ]),
            ),
          ],
          PSection(t('أدواتك', 'YOUR TOOLS'), th),
          for (final tool in _tools) ...[
            PCard(
              th: th,
              padding: const EdgeInsets.all(14),
              onTap: () => context.push(tool.route),
              child: Row(children: [
                PBadge(tool.icon, size: 46, color: tool.color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                          child: Text(isAr ? tool.titleAr : tool.titleEn,
                              style: pText(th.text, 15, w: FontWeight.w900))),
                      if (!premium && tool.freeTaste) ...[
                        const SizedBox(width: 8),
                        PPill(t('تجربة مجانية', 'Free taste'), AppColors.halalGreen),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(isAr ? tool.subAr : tool.subEn,
                        style: pText(th.muted, 12, w: FontWeight.w500, h: 1.4)),
                  ]),
                ),
                Icon(isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: th.muted),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          PSection(t('وأيضًا في بريميوم', 'ALSO INCLUDED'), th),
          PCard(
            th: th,
            child: Column(children: [
              _line(th, Icons.qr_code_scanner_rounded, t('ماسحات حلال بلا حدود', 'Unlimited halal scans')),
              _line(th, Icons.photo_camera_rounded, t('تحليل الطعام والجسم بالصورة بلا حدود', 'Unlimited AI food and body photo analysis')),
              _line(th, Icons.monitor_weight_rounded, t('نسبة الدهون وكتلة العضلات', 'Body fat and muscle mass')),
              _line(th, Icons.fitness_center_rounded, t('كل خطط التمرين المميزة', 'Every premium workout plan')),
              _line(th, Icons.terrain_rounded, t('رحلة Ascent كاملة', 'The full Ascent journey')),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _line(PTheme th, IconData i, String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(i, size: 20, color: kGold),
          const SizedBox(width: 12),
          Expanded(child: Text(s, style: pText(th.text, 13, w: FontWeight.w700))),
          const Icon(Icons.check_rounded, size: 18, color: AppColors.halalGreen),
        ]),
      );
}

/// Card for the Home tab. Free: a one-line pitch that opens the Studio.
/// Premium: shortcuts, and today's recommended fast when there is one.
class PremiumHomeCard extends ConsumerWidget {
  const PremiumHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final th = PTheme(isDark);
    String t(String ar, String en) => tLang(lang, ar, en);
    final now = DateTime.now();
    final fast = FastingCalendar.upcoming(from: DateTime(now.year, now.month, now.day), days: 2);
    final fastToday = fast.isNotEmpty &&
        fast.first.date.day == now.day &&
        fast.first.date.month == now.month;

    Widget chip(IconData i, String label, String route) => Expanded(
          child: GestureDetector(
            onTap: () => context.push(route),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: th.card.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGold.withOpacity(0.35), width: 0.8),
              ),
              child: Column(children: [
                Icon(i, size: 20, color: kGold),
                const SizedBox(height: 4),
                Text(label, style: pText(th.text, 11, w: FontWeight.w800)),
              ]),
            ),
          ),
        );

    return PCard(
      th: th,
      gold: true,
      padding: const EdgeInsets.all(14),
      onTap: premium ? null : () => context.push('/premium'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const PBadge(Icons.workspace_premium_rounded, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  premium
                      ? t('استوديو بريميوم', 'Premium Studio')
                      : t('جرّب بريميوم', 'Try Premium'),
                  style: pText(th.text, 15, w: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                  premium
                      ? (fastToday
                          ? t('اليوم يوم صيام مستحب', 'Today is a recommended fast')
                          : t('مدرّبك ومخططك وتقاريرك', 'Your coach, planner and reports'))
                      : t('مدرّب ذكي • مخطط وجبات • رؤى • صيام',
                          'AI coach • meal planner • insights • fasting'),
                  style: pText(th.muted, 12, w: FontWeight.w600, h: 1.35)),
            ]),
          ),
          if (!premium) const Icon(Icons.arrow_forward_rounded, color: kGold, size: 20),
        ]),
        if (premium) ...[
          const SizedBox(height: 12),
          Row(children: [
            chip(Icons.psychology_alt_rounded, t('المدرّب', 'Coach'), '/coach'),
            const SizedBox(width: 8),
            chip(Icons.auto_awesome_rounded, t('الخطة', 'Plan'), '/meal-plan'),
            const SizedBox(width: 8),
            chip(Icons.insights_rounded, t('رؤى', 'Insights'), '/insights'),
            const SizedBox(width: 8),
            chip(Icons.nightlight_round, t('صيام', 'Fasting'), '/fasting'),
          ]),
        ],
      ]),
    );
  }
}
