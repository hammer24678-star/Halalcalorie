// ============================================================
//  login_screen.dart — HalalCalorie v48 (studio redesign)
//  Same sign-in / guest logic as before. Now: living aurora,
//  orbiting brand hero, staggered reveals, shine-free white
//  Google button, language switch, trust chips.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/fx.dart';
import '../../core/fx2.dart';
import '../../core/fx6.dart';
import '../../core/providers.dart';
import '../../core/auth_provider.dart';

String _nextLoginLang(String current) {
  const langs = ['ar', 'en', 'fr', 'tr', 'ur', 'ms', 'id'];
  final i = langs.indexOf(current);
  return langs[(i + 1) % langs.length];
}

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authNotifierProvider);
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar' || lang == 'ur';
    String t(String ar, String en) => tLang(lang, ar, en);

    const base = Color(0xFF04100A);

    Widget chip(IconData icon, String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.07),
            border: Border.all(color: Colors.white.withOpacity(0.16), width: 0.7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: AppColors.halalGreen),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 12, color: Colors.white70)),
          ]),
        );

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: base,
        body: Stack(children: [
          const Positioned.fill(
            child: AuroraBackground(
              base: base,
              colors: [Color(0xFF1E9E52), Color(0xFFDBA75D), Color(0xFF0E6B6B)],
              intensity: 1.0,
            ),
          ),
          Positioned.fill(
            child: DriftingLeaves(
                count: 12, color: AppColors.halalGreen, speed: 10, opacity: 0.45),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GlassIconBtn(
                      isDark: true,
                      size: 40,
                      onTap: () => ref
                          .read(languageProvider.notifier)
                          .set(_nextLoginLang(lang)),
                      child: Text(
                        lang == 'ar' ? 'ع' : lang.toUpperCase(),
                        style: const TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Reveal(
                  index: 0,
                  child: const OnboardScene(
                      kind: 0, color: AppColors.halalGreen, size: 230),
                ),
                const SizedBox(height: 18),
                Reveal(
                  index: 1,
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFF0CF98)],
                    ).createShader(r),
                    child: Text(
                      isAr ? 'هلال كالوري' : 'HalalCalorie',
                      style: const TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Reveal(
                  index: 2,
                  child: Text(
                    t('تتبع سعراتك • حلال ١٠٠٪', 'Track your calories • 100% halal'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Reveal(
                  index: 3,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      chip(Icons.verified_rounded, t('حلال', 'Halal')),
                      chip(Icons.lock_rounded, t('خاص', 'Private')),
                      chip(Icons.auto_awesome_rounded, t('ماسح ذكي', 'AI scanner')),
                    ],
                  ),
                ),
                const Spacer(),
                Reveal(
                  index: 4,
                  child: PressFx(
                    onTap: isLoading
                        ? null
                        : () async {
                            final ok = await ref
                                .read(authNotifierProvider.notifier)
                                .signInWithGoogle();
                            if (ok && context.mounted) context.go('/home');
                          },
                    scale: 0.97,
                    child: Container(
                      height: 58,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: isLoading
                              ? const SizedBox(
                                  key: ValueKey('l'),
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.6,
                                      color: AppColors.brandGreen),
                                )
                              : Row(
                                  key: const ValueKey('t'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ShaderMask(
                                      blendMode: BlendMode.srcIn,
                                      shaderCallback: (r) => const SweepGradient(
                                        colors: [
                                          Color(0xFF4285F4),
                                          Color(0xFF34A853),
                                          Color(0xFFFBBC05),
                                          Color(0xFFEA4335),
                                          Color(0xFF4285F4),
                                        ],
                                      ).createShader(r),
                                      child: const Text('G',
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white)),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      t('تسجيل الدخول بـ Google',
                                          'Continue with Google'),
                                      style: const TextStyle(
                                        fontFamily: 'Aligarh',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1F2A1F),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Reveal(
                  index: 5,
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.go('/onboarding');
                    },
                    child: Text(
                      t('متابعة بدون حساب', 'Continue without an account'),
                      style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
                Reveal(
                  index: 6,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.shield_rounded,
                          size: 12, color: Colors.white.withOpacity(0.35)),
                      const SizedBox(width: 5),
                      Text(
                        t('بياناتك محفوظة وآمنة تماماً',
                            'Your data stays private and secure'),
                        style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
