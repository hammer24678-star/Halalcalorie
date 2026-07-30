// shell.dart — HalalCalorie — Premium animated shell
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import 'l10n.dart';
import 'providers.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideIn;

  @override
  void initState() {
    super.initState();
    _slideIn = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
    _slideIn.forward();
  }

  @override void dispose() { _slideIn.dispose(); super.dispose(); }

  static const _tabs = [
    _T('/home',      '⌂',  'Home',      'الرئيسية'),
    _T('/nutrition', '◈',  'Nutrition', 'تغذية'),
    _T('/fitness',   '◉',  'Fitness',   'لياقة'),
    _T('/ascent',    '▲',  'Ascent',    'صعود'),
    _T('/health',    '♡',  'Health',    'صحة'),
    _T('/profile',   '◯',  'Profile',   'ملفي'),
  ];

  int _idx(String loc) {
    if (loc.startsWith('/body') || loc.startsWith('/health')) return 4;
    if (loc.startsWith('/ascent')) return 3;
    if (loc.startsWith('/scanner')) return 1;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc    = GoRouterState.of(context).matchedLocation;
    final idx    = _idx(loc);
    final isDark = ref.watch(themeProvider);
    final lang   = ref.watch(languageProvider);
    final isAr      = isRtlLang(lang);
    final isRamadan = ref.watch(ramadanModeProvider);

    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _slideIn, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015), end: Offset.zero,
          ).animate(CurvedAnimation(parent: _slideIn, curve: Curves.easeOutCubic)),
          child: widget.child,
        ),
      ),
      bottomNavigationBar: _PremiumNav(
        tabs: _tabs, activeIdx: idx,
        isDark: isDark, isAr: isAr, isRamadan: isRamadan,
        onTap: (path) {
          HapticFeedback.lightImpact();
          if (path == '/ascent' &&
              !ref.read(premiumProvider)) {
            context.push('/paywall');
            return;
          }
          context.go(path);
        },
      ),
    );
  }
}

class _PremiumNav extends ConsumerStatefulWidget {
  final List<_T> tabs;
  final int activeIdx;
  final bool isDark, isAr, isRamadan;
  final void Function(String) onTap;
  const _PremiumNav({required this.tabs, required this.activeIdx,
    required this.isDark, required this.isAr,
    required this.isRamadan, required this.onTap});
  @override ConsumerState<_PremiumNav> createState() => _PremiumNavState();
}

class _PremiumNavState extends ConsumerState<_PremiumNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _spring;
  int _prev = 0;

  @override
  void initState() {
    super.initState();
    _prev = widget.activeIdx;
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350));
    _spring = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_PremiumNav old) {
    super.didUpdateWidget(old);
    if (old.activeIdx != widget.activeIdx) {
      _prev = old.activeIdx;
      _ctrl.forward(from: 0);
    }
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bg         = widget.isDark ? const Color(0xFF161B22) : Colors.white;
    final border     = widget.isDark ? const Color(0xFF21262D) : const Color(0xFFD0D7DE);
    // Ramadan mode: swap all greens to gold
    final activeColor = widget.isRamadan ? AppColors.accentGold : AppColors.halalGreen;
    final activeBg    = widget.isRamadan
        ? AppColors.accentGold.withOpacity(0.15)
        : AppColors.brandGreen.withOpacity(0.15);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: widget.tabs.asMap().entries.map((e) {
              final i      = e.key;
              final tab    = e.value;
              final active = i == widget.activeIdx;
              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onTap(tab.path),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _spring,
                    builder: (_, __) {
                      final scale = active ? (0.88 + 0.12 * _spring.value) : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Pill bg
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                              decoration: BoxDecoration(
                                color: active ? activeBg : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: active && widget.isRamadan
                                    ? [BoxShadow(
                                        color: AppColors.accentGold.withOpacity(0.55),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      )]
                                    : null,
                              ),
                              child: Text(tab.icon, style: TextStyle(
                                fontSize: active ? 20 : 18,
                                color: active
                                  ? activeColor
                                  : (widget.isDark ? AppColors.darkDimmed : AppColors.lightMuted),
                              )),
                            ),
                            const SizedBox(height: 1),
                            // Label
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 9,
                                fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                                color: active
                                  ? activeColor
                                  : (widget.isDark ? AppColors.darkDimmed : AppColors.lightMuted),
                              ),
                              child: Builder(builder: (ctx) {
                                final _lang = ref.watch(languageProvider);
                                final _l = L.fromLang(_lang);
                                switch (tab.path) {
                                  case '/home':      return Text(_l.navHome);
                                  case '/nutrition': return Text(_l.navNutrition);
                                  case '/fitness':   return Text(_l.navFitness);
                                  case '/health':    return Text(_l.navHealth);
                                  case '/ascent':    return Text(_l.ascentNavLabel);
                                  case '/profile':   return Text(_l.navProfile);
                                  default: return Text(widget.isAr ? tab.ar : tab.en);
                                }
                              }),
                            ),
                            // Active bar
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              margin: const EdgeInsets.only(top: 3),
                              width: active ? 20 : 0,
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: activeColor,
                                borderRadius: BorderRadius.circular(2),
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

class _T {
  final String path, icon, en, ar;
  const _T(this.path, this.icon, this.en, this.ar);
}
