// ============================================================
//  login_screen.dart — HalalCalorie
//  Clean Google Sign-In screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(children: [
        // Background gradient
        Positioned.fill(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.sunnahGreen.withOpacity(0.12),
                AppColors.darkBg,
                AppColors.barakahGold.withOpacity(0.06),
              ],
            ),
          ),
        )),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.gradientGreen,
                    boxShadow: [BoxShadow(
                      color: AppColors.sunnahGreen.withOpacity(0.35),
                      blurRadius: 24, offset: const Offset(0, 8),
                    )],
                  ),
                  child: const Center(
                    child: Text('🌿', style: TextStyle(fontSize: 48)),
                  ),
                ),

                const SizedBox(height: 28),

                // Title
                const Text(
                  'هلال كالوري',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 32, fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'تتبع سعراتك • حلال ١٠٠٪',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),

                const Spacer(flex: 2),

                // Google Sign-In button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      final success = await ref
                          .read(authNotifierProvider.notifier)
                          .signInWithGoogle();
                      if (success && context.mounted) {
                        context.go('/home');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.sunnahGreen,
                            ))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('G',
                                style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900,
                                  color: Color(0xFF4285F4),
                                )),
                              const SizedBox(width: 10),
                              const Text('تسجيل الدخول بـ Google',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                )),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                // Skip (guest mode)
                TextButton(
                  onPressed: () => context.go('/onboarding'),
                  child: Text(
                    'متابعة بدون حساب',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'بياناتك محفوظة وآمنة تماماً',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
