// shell.dart — HalalCalorie — floating glass navigation (v44)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import 'l10n.dart';
import 'fx.dart';
import 'motion.dart';
import 'providers.dart';
import 'notifications.dart'; // PATCH_V58

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  // PATCH_V58_NOTIF_TAP
  @override
  void initState() {
    super.initState();
    NotificationService.pendingRoute.addListener(_openNotifRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openNotifRoute());
  }

  void _openNotifRoute() {
    final r = NotificationService.pendingRoute.value;
    if (r == null || r.isEmpty || !mounted) return;
    NotificationService.pendingRoute.value = null;
    const tabPaths = ['/home', '/nutrition', '/fitness', '/ascent', '/health', '/profile'];
    if (r == '/ascent' && !ref.read(premiumProvider)) { context.push('/paywall'); return; }
    if (tabPaths.contains(r)) { context.go(r); } else { context.push(r); }
  }

  @override
  void dispose() {
    NotificationService.pendingRoute.removeListener(_openNotifRoute);
    _slideIn.dispose();
    super.dispose();
  }

  static const _tabs = [
    _T('/home', Glyph.home),
    _T('/nutrition', Glyph.nutrition),
    _T('/fitness', Glyph.fitness),
    _T('/ascent', Glyph.ascent),
    _T('/health', Glyph.health),
    _T('/profile', Glyph.profile),
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
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _idx(loc);
    final isDark = ref.watch(themeProvider);
    final lang = ref.watch(languageProvider);
    final isRamadan = ref.watch(ramadanModeProvider);

    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _slideIn, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _slideIn, curve: Motion.curve)),
          child: widget.child,
        ),
      ),
      bottomNavigationBar: _FloatingNav(
        tabs: _tabs,
        activeIdx: idx,
        isDark: isDark,
        isRamadan: isRamadan,
        l: L.fromLang(lang),
        onTap: (path) {
          HapticFeedback.selectionClick();
          if (path == '/ascent' && !ref.read(premiumProvider)) {
            context.push('/paywall');
            return;
          }
          context.go(path);
        },
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  final List<_T> tabs;
  final int activeIdx;
  final bool isDark, isRamadan;
  final L l;
  final void Function(String) onTap;
  const _FloatingNav({
    required this.tabs,
    required this.activeIdx,
    required this.isDark,
    required this.isRamadan,
    required this.l,
    required this.onTap,
  });

  String _label(String path) {
    switch (path) {
      case '/home':
        return l.navHome;
      case '/nutrition':
        return l.navNutrition;
      case '/fitness':
        return l.navFitness;
      case '/health':
        return l.navHealth;
      case '/ascent':
        return l.ascentNavLabel;
      default:
        return l.navProfile;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = tabs.length;
    final accent = isRamadan ? AppColors.ramadanGold : AppColors.halalGreen;
    final inactive = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final bar = isDark ? const Color(0xFF0F1E18) : Colors.white;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: bar,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.55 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              if (isRamadan)
                BoxShadow(
                  color: accent.withOpacity(0.18),
                  blurRadius: 24,
                ),
            ],
          ),
          child: Stack(children: [
            // One pill that slides between tabs instead of one per tab.
            AnimatedAlign(
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeOutBack,
              alignment: AlignmentDirectional(-1 + 2 * activeIdx / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(21),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withOpacity(isDark ? 0.24 : 0.20),
                          accent.withOpacity(isDark ? 0.10 : 0.08),
                        ],
                      ),
                      border: Border.all(
                          color: accent.withOpacity(0.28), width: 0.6),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: _NavItem(
                      glyph: tabs[i].glyph,
                      label: _label(tabs[i].path),
                      active: i == activeIdx,
                      activeColor: accent,
                      inactiveColor: inactive,
                      onTap: () => onTap(tabs[i].path),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final Glyph glyph;
  final String label;
  final bool active;
  final Color activeColor, inactiveColor;
  final VoidCallback onTap;
  const _NavItem({
    required this.glyph,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: active ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, v, __) {
          final c = Color.lerp(inactiveColor, activeColor, v.clamp(0.0, 1.0))!;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, -2.5 * v),
                child: Transform.scale(
                  scale: 1 + 0.14 * v,
                  child: AppGlyph(glyph: glyph, color: c, t: v, size: 24),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: c,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _T {
  final String path;
  final Glyph glyph;
  const _T(this.path, this.glyph);
}
