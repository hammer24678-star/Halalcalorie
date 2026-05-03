import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import 'providers.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {

  late AnimationController _navAnim;

  static const _tabs = [
    _NavTab('/home',      '🏠', 'Home',      'الرئيسية'),
    _NavTab('/nutrition', '🌿', 'Nutrition', 'تغذية'),
    _NavTab('/fitness',   '🏃', 'Fitness',   'لياقة'),
    _NavTab('/health',    '🩺', 'Health',    'صحة'),
    _NavTab('/profile',   '👤', 'Profile',   'ملفي'),
  ];

  int _idx(String loc) {
    if (loc.startsWith('/body'))    return 3;
    if (loc.startsWith('/scanner')) return 0;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _navAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
    _navAnim.forward();
  }

  @override
  void dispose() { _navAnim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final loc    = GoRouterState.of(context).matchedLocation;
    final idx    = _idx(loc);
    final isDark = ref.watch(themeProvider);
    final isAr   = ref.watch(languageProvider) == 'ar';
    final water  = ref.watch(waterProvider);
    final cals   = ref.watch(caloriesProvider);

    return Scaffold(
      body: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02), end: Offset.zero,
        ).animate(CurvedAnimation(parent: _navAnim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: _navAnim, child: widget.child),
      ),
      bottomNavigationBar: _AnimatedNavBar(
        tabs: _tabs,
        activeIdx: idx,
        isDark: isDark,
        isAr: isAr,
        nutritionBadge: cals.entries.isEmpty,
        healthBadge: water.cups == 0,
        onTap: (path) {
          HapticFeedback.lightImpact();
          context.go(path);
        },
      ),
    );
  }
}

class _AnimatedNavBar extends StatefulWidget {
  final List<_NavTab> tabs;
  final int activeIdx;
  final bool isDark, isAr, nutritionBadge, healthBadge;
  final void Function(String) onTap;
  const _AnimatedNavBar({
    required this.tabs, required this.activeIdx,
    required this.isDark, required this.isAr,
    required this.nutritionBadge, required this.healthBadge,
    required this.onTap,
  });
  @override State<_AnimatedNavBar> createState() => _AnimatedNavBarState();
}

class _AnimatedNavBarState extends State<_AnimatedNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pillCtrl;
  late Animation<double> _pillAnim;
  int _prevIdx = 0;

  @override
  void initState() {
    super.initState();
    _prevIdx = widget.activeIdx;
    _pillCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
    _pillAnim = CurvedAnimation(parent: _pillCtrl, curve: Curves.easeOutBack);
    _pillCtrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedNavBar old) {
    super.didUpdateWidget(old);
    if (old.activeIdx != widget.activeIdx) {
      _prevIdx = old.activeIdx;
      _pillCtrl.forward(from: 0);
    }
  }

  @override void dispose() { _pillCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bg     = widget.isDark ? const Color(0xFF161B22) : Colors.white;
    final border = widget.isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.08),
            blurRadius: 20, offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: widget.tabs.asMap().entries.map((e) {
              final i      = e.key;
              final tab    = e.value;
              final active = i == widget.activeIdx;
              final label  = widget.isAr ? tab.labelAr : tab.labelEn;
              final showBadge =
                (tab.path == '/nutrition' && widget.nutritionBadge) ||
                (tab.path == '/health'    && widget.healthBadge);

              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onTap(tab.path),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _pillAnim,
                    builder: (_, __) {
                      final scale = active
                        ? 0.9 + 0.1 * _pillAnim.value
                        : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Pill container
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: active
                                  ? AppColors.halalGreen.withOpacity(0.15)
                                  : Colors.transparent,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: TextStyle(fontSize: active ? 22 : 19),
                                    child: Text(tab.emoji),
                                  ),
                                  if (showBadge)
                                    Positioned(
                                      right: -4, top: -4,
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0, end: 1),
                                        duration: const Duration(milliseconds: 400),
                                        builder: (_, v, __) => Transform.scale(
                                          scale: v,
                                          child: Container(
                                            width: 8, height: 8,
                                            decoration: const BoxDecoration(
                                              color: AppColors.haramRed,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 1),
                            // Label
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 9,
                                fontWeight: active
                                    ? FontWeight.w800 : FontWeight.w400,
                                color: active
                                    ? AppColors.halalGreen
                                    : (widget.isDark
                                        ? const Color(0xFF7D8590)
                                        : const Color(0xFF6B7A8D)),
                              ),
                              child: Text(label),
                            ),
                            // Active dot
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              margin: const EdgeInsets.only(top: 2),
                              width: active ? 18 : 0,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.halalGreen,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final String path, emoji, labelEn, labelAr;
  const _NavTab(this.path, this.emoji, this.labelEn, this.labelAr);
}
