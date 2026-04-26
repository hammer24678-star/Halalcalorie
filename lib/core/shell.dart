import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import 'providers.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _navTabs = [
    _Tab('/home',      '🏠', 'Home',      'الرئيسية'),
    _Tab('/nutrition', '🌿', 'Nutrition', 'تغذية'),
    _Tab('/fitness',   '🏃', 'Fitness',   'لياقة'),
    _Tab('/health',    '🩺', 'Health',    'صحة'),
    _Tab('/profile',   '👤', 'Profile',   'ملفي'),
  ];

  int _idx(String loc) {
    if (loc.startsWith('/body'))    return 3;
    if (loc.startsWith('/scanner')) return 0;
    for (int i = 0; i < _navTabs.length; i++) {
      if (loc.startsWith(_navTabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc   = GoRouterState.of(context).matchedLocation;
    final idx   = _idx(loc);
    final isDark = ref.watch(themeProvider);
    final isAr  = ref.watch(languageProvider) == 'ar';
    final cals  = ref.watch(caloriesProvider);
    final water = ref.watch(waterProvider);

    final navBg = isDark ? AppColors.darkNav : AppColors.lightNav;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(color: AppColors.darkBorder, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: _navTabs.asMap().entries.map((e) {
                final active = e.key == idx;
                final tab = e.value;
                final showBadge =
                  (tab.path == '/nutrition' && cals.entries.isEmpty) ||
                  (tab.path == '/health'    && water.cups == 0);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(tab.path),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Pill highlight
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.halalGreen.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Text(tab.emoji,
                                style: TextStyle(
                                  fontSize: active ? 22 : 20,
                                )),
                              if (showBadge)
                                Positioned(
                                  right: -3, top: -3,
                                  child: Container(
                                    width: 7, height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.haramRed,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAr ? tab.labelAr : tab.labelEn,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 9,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                            color: active
                                ? AppColors.halalGreen
                                : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
                          ),
                        ),
                        // Active dot
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(top: 2),
                          width: active ? 16 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.halalGreen,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final String path, emoji, labelEn, labelAr;
  const _Tab(this.path, this.emoji, this.labelEn, this.labelAr);
}
