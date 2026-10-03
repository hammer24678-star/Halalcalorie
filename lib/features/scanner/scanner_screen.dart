// scanner_screen.dart — HalalCalorie v1.0
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/motion.dart';
import '../../core/fx5.dart';
import 'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:go_router/go_router.dart'; import'package:http/http.dart' as http; import'../../core/theme.dart'; import'../../core/providers.dart';
import '../../core/l10n.dart'; import'../../data/models/models.dart'; import'barcode_scanner_widget.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});
  @override ConsumerState<ScannerScreen> createState() => _ScannerState();
}

class _ScannerState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  String get lang => ref.read(languageProvider);
  final _barcodeCtrl = TextEditingController();
  ScanResult? _result;
  bool _scanning = false; // true while hitting OFFapi
  String? _lastBarcode;   // last code the camera handed us (see _onCameraBarcode)
  bool _limitDialogOpen = false;
  String? _loggedKey; // result already added to the log (v48)

  @override
  void initState() {
    super.initState();
    // Real camera scanner handles animation internally
  }

  @override void dispose() { _barcodeCtrl.dispose(); super.dispose(); }

  // ── Halal ingredient check ─────────────────────────────
  HalalStatus _halalCheck(String ingredients) {
    // No ingredient text means we don't know — never report that as Halal.
    if (ingredients.trim().isEmpty) return HalalStatus.unknown;
    final lower = ingredients.toLowerCase();
    // Whole-word matches for the short terms: ' ham,' missed "ham" at the end of
    // a list, ' lard' missed it at the start, and 'e120' also hit E1200-E1209.
    // "sugar alcohol", "fatty alcohol" and "alcohol-free" aren't drinks.
    final haram = RegExp(
      r'pork|porcine|bacon|carmine|cochineal|\bwine\b|\blard\b|\bham\b|\be120\b'
      r'|(?<!sugar )(?<!fatty )(?<!non-)\balcohol(?!-free| free)');
    const doubtful = ['gelatin', 'e441', 'e471',
      'mono- and diglycerides', 'natural flavour', 'natural flavor',
      'rennet', 'whey powder'];
    if (haram.hasMatch(lower))        return HalalStatus.haram;
    if (doubtful.any(lower.contains)) return HalalStatus.doubtful;
    return HalalStatus.halal;
  }

  // Open Food Facts sends numbers, numeric strings or null depending on the product.
  static num? _numOf(dynamic v) =>
      v is num ? v : (v is String ? num.tryParse(v) : null);

  // ── Unknown product fallback ───────────────────────────
  void _unknownProduct(String barcode, bool isAr) {
    final r = ScanResult(
      barcode: barcode,
      name:   tLang(lang, 'منتج غير معروف', 'Unknown Product', 'Produit inconnu', 'Bilinmeyen Ürün', 'Produk Tidak Diketahui', 'Produk Tidak Diketahui'),
      brand:  tLang(lang, 'غير معروف', 'Unknown', 'Inconnu', 'Bilinmiyor', 'Tidak diketahui', 'Tidak diketahui'),
      status: HalalStatus.unknown,
      notes:  tLang(lang, 'لا توجد بيانات — جرّب تحليل AI', 'No data — try AI Analysis', 'Pas de données — essayez l\'analyse IA', 'Veri yok — AI Analizini deneyin', 'Tiada data — cuba Analisis AI', 'Tidak ada data — coba Analisis AI'),
    );
    ref.read(scanProvider.notifier).addScan(r);
    if (mounted) setState(() { _result = r; _scanning = false; });
  }

  // The camera reports the same barcode on every frame it stays in view. Each
  // report used to count as a scan: one product burned the 3 free scans and
  // stacked limit dialogs. Ignore repeats until a different code shows up or
  // the person taps "Scan again". (_scan itself enforces the limit.)
  void _onCameraBarcode(String barcode) {
    if (_scanning || barcode == _lastBarcode) return;
    _lastBarcode = barcode;
    HapticFeedback.mediumImpact();
    _scan(barcode);
  }

  // ── Main scan: local DB → Open Food Facts API ──────────
  Future<void> _scan(String barcode) async {
    if (_scanning) return;
    ref.read(scanProvider.notifier).refreshDay(); // app may have stayed open past midnight
    final scan      = ref.read(scanProvider);
    final isPremium = ref.read(premiumProvider);
    final isAr      = ref.read(languageProvider) == 'ar';
    if (!isPremium && scan.todayCount >= 3) { _showLimitDialog(isAr); return; }

    // 1. Local DB lookup (instant)
    final local = kProductsDB.cast<ScanResult?>().firstWhere(
        (p) => p!.barcode == barcode, orElse: () => null);
    if (local != null) {
      ref.read(scanProvider.notifier).addScan(local);
      setState(() => _result = local);
      return;
    }

    // 2. Open Food Facts API fallback
    setState(() { _scanning = true; _result = null; });
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
        '?fields=product_name,product_name_ar,brands,nutriments,ingredients_text');
      final resp = await http.get(uri,
        headers: {'User-Agent': 'HalalCalorie/1.0 (Android; halal-tracking)'}
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        if (json['status'] == 1) {
          final p    = json['product'] as Map<String, dynamic>;
          final n    = (p['nutriments'] ?? {}) as Map<String, dynamic>;
          final ing  = (p['ingredients_text'] ?? '') as String;
          final name = ((p['product_name_ar'] ?? '') as String).isNotEmpty
              ? p['product_name_ar'] as String
              : (p['product_name'] ?? barcode) as String;
          final brand  = (p['brands'] ?? '') as String;
          // energy_100g is kilojoules, not kcal — only ever use it converted.
          final kcal   = (_numOf(n['energy-kcal_100g']) ??
                          ((_numOf(n['energy_100g']) ?? 0) / 4.184)).round();
          final prot   = (_numOf(n['proteins_100g'])      ?? 0).toDouble();
          final carbs  = (_numOf(n['carbohydrates_100g']) ?? 0).toDouble();
          final fat    = (_numOf(n['fat_100g'])           ?? 0).toDouble();
          final status = _halalCheck(ing);
          final r = ScanResult(
            barcode:  barcode,
            name:     name.isEmpty ? (tLang(lang, 'منتج مجهول', 'Unknown', 'Inconnu', 'Bilinmiyor', 'Tidak diketahui', 'Tidak diketahui')) : name,
            brand:    brand,
            status:   status,
            kcal:     kcal > 0 ? kcal : null,
            proteinG: prot > 0 ? prot : null,
            carbsG:   carbs > 0 ? carbs : null,
            fatG:     fat > 0 ? fat : null,
            notes:    ing.trim().isEmpty
                ? '📡 Open Food Facts · ' + tLang(lang, 'لا توجد بيانات مكونات — راجع الملصق', 'No ingredient data — check the label')
                : '📡 Open Food Facts',
          );
          ref.read(scanProvider.notifier).addScan(r);
          if (mounted) setState(() { _result = r; _scanning = false; });
          return;
        }
      }
      _unknownProduct(barcode, isAr);
    } catch (_) {
      if (mounted) _unknownProduct(barcode, isAr);
    }
  }

  void _showLimitDialog(bool isAr) {
    if (_limitDialogOpen) return;
    _limitDialogOpen = true;
    showDialog(context: context, builder: (dialogCtx) => AlertDialog( title: Text(tLang(lang, 'وصلت الحد اليومي', 'Daily Limit Reached', 'Limite journalière atteinte', 'Günlük Limit Aşıldı', 'Had Harian Dicapai', 'Batas Harian Tercapai'), style: const TextStyle(fontFamily:'Aligarh')), content: Text(tLang(lang, 'استخدمت ٣ ماسحات اليوم.\nترقّ للبريميوم للمزيد.', 'You have used 3 scans today.\nUpgrade for unlimited.', 'Vous avez utilisé 3 scans aujourd\'hui.\nPassez à Premium.', 'Bugün 3 tarama kullandınız.\nSınırsız için yükseltin.', 'Anda telah menggunakan 3 imbasan.\nNaik taraf untuk tanpa had.', 'Anda telah menggunakan 3 pemindaian.\nUpgrade untuk tak terbatas.'), style: const TextStyle(fontFamily:'Aligarh')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(tLang(lang, 'إغلاق', 'Close', 'Fermer', 'Kapat', 'Tutup', 'Tutup'), style: const TextStyle(fontFamily: 'Aligarh'))), ElevatedButton(onPressed: () { Navigator.pop(dialogCtx); if (context.mounted) context.push('/paywall'); }, child: Text(tLang(lang, '⭐ ترقية', '⭐ Upgrade', '⭐ Mettre à niveau', '⭐ Yükselt', '⭐ Naik Taraf', '⭐ Upgrade'), style: const TextStyle(fontFamily: 'Aligarh'))),
      ],
    )).whenComplete(() { _limitDialogOpen = false; });
  }

  @override
  Widget build(BuildContext context) {
    final scan      = ref.watch(scanProvider);
    final isPremium = ref.watch(premiumProvider);
    final lang      = ref.watch(languageProvider); final isAr      = lang =='ar';
    final isDark    = ref.watch(themeProvider);
    final bg        = isDark ? AppColors.darkCard : Colors.white;
    final muted     = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    String t(String ar, String en) => tLang(lang, ar, en);

    final vfMode = _scanning
        ? ViewfinderMode.working
        : (_result != null ? ViewfinderMode.locked : ViewfinderMode.idle);
    final lockCol = _result != null
        ? _statusColor(_result!.status)
        : AppColors.halalGreen;
    String hint;
    if (_scanning) {
      hint = t('جارٍ التحليل…', 'Analyzing…');
    } else if (_result != null) {
      hint = isAr ? _labelAr(_result!.status) : _labelEn(_result!.status);
    } else {
      hint = t('ضع الباركود داخل الإطار', 'Align the barcode inside the frame');
    }

    return Scaffold(
      appBar: AppBar( title: Text(t('الماسح الذكي 📷', 'Smart Scanner 📷')),
        actions: [
          GestureDetector(
            onTap: () => _showHistory(isAr, isDark),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history, color: Colors.white),
                const SizedBox(width: 4), Text('${scan.history.length}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily:'Aligarh')),
              ]),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [

        // ── AI Food Photo hero ────────────────────────────
        Reveal(
          index: 0,
          child: PressFx(
            onTap: () => context.push('/food-photo'),
            scale: 0.97,
            child: SheenSweep(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brandGreen, AppColors.darkGreen],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: AppColors.brandGreen.withOpacity(0.35),
                    blurRadius: 18, offset: const Offset(0, 7),
                  )],
                ),
                child: Row(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: const Center(child: ShutterGlyph(size: 44)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [ Text(t('تحليل الطعام بـ AI 🤖', 'AI Food Analyzer 🤖'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 15,
                              fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold,
                          borderRadius: BorderRadius.circular(20),
                        ), child: Text(t('جديد!', 'NEW!'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 9,
                                fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Text( t('صوّر أي طعام ← سعرات + بروتين + حكم حلال فوراً', 'Photo any food ← Calories + Protein + Halal status instantly'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 11,
                          color: Colors.white70, height: 1.4),
                    ),
                  ])),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                ]),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── OR divider ───────────────────────────────────
        Reveal(
          index: 1,
          slide: false,
          child: Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(t('أو امسح باركود', 'or scan barcode'), style: TextStyle(fontFamily:'Aligarh', fontSize: 12, color: muted)),
            ),
            const Expanded(child: Divider()),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Camera ────────────────────────────────────────
        AnimatedContainer(
          duration: Motion.base,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(
              color: lockCol.withOpacity(_result != null ? 0.38 : 0.20),
              blurRadius: 22, offset: const Offset(0, 6),
            )],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(fit: StackFit.expand, children: [
              BarcodeScannerWidget(
                isActive: true,
                onDetected: _onCameraBarcode,
              ),
              ScanViewfinder(mode: vfMode, lockColor: lockCol),
              Positioned(top: 12, right: 12,
                  child: _quotaChip(isPremium, scan.todayCount, lang)),
              Positioned(left: 0, right: 0, bottom: 12,
                  child: Center(child: _hintPill(hint, lockCol, _result != null))),
            ]),
          ),
        ),

        // ── Lookup + result sit right under the camera ───
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.curve,
          alignment: Alignment.topCenter,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_scanning) ...[
              const SizedBox(height: 14),
              _loaderCard(bg, lang),
            ],
            if (_result != null && !_scanning) ...[
              const SizedBox(height: 14),
              _resultCard(_result!, isAr, isDark, bg, muted),
            ],
          ]),
        ),

        const SizedBox(height: 14),

        // ── Manual entry ──────────────────────────────────
        Reveal(
          index: 2,
          child: Row(children: [
            Expanded(child: TextField(
              controller: _barcodeCtrl,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) { if (v.trim().isNotEmpty) _scan(v.trim()); },
              decoration: InputDecoration( hintText: t('أدخل الباركود يدوياً...', 'Enter barcode manually...'), hintStyle: const TextStyle(fontFamily:'Aligarh', fontSize: 12),
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.brandGreen.withOpacity(0.25)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.brandGreen.withOpacity(0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.6),
                ),
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            )),
            const SizedBox(width: 8),
            PressFx(
              onTap: () {
                final v = _barcodeCtrl.text.trim();
                if (v.isNotEmpty) _scan(v);
              },
              scale: 0.92,
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.gradientGreen,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: AppColors.brandGreen.withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )],
                ),
                child: const Icon(Icons.search_rounded, color: Colors.white),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Demo products ─────────────────────────────────
        Reveal(
          index: 3,
          child: Row(children: [
            Expanded(child: Text(t('جرّب هذه المنتجات:', 'Try these products:'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 13, fontWeight: FontWeight.w700))),
            PressFx(
              onTap: () {
                final p = kProductsDB[DateTime.now().millisecond % kProductsDB.length];
                _scan(p.barcode);
              },
              scale: 0.94,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.brandGreen.withOpacity(0.3)),
                ),
                child: Text(t('📷 مسح عشوائي', '📷 Random Scan'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 12, color: AppColors.brandGreen, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 10),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.8,
          children: kProductsDB.asMap().entries.map((e) {
            final p = e.value;
            return Reveal(
              index: e.key > 7 ? 7 : e.key,
              offset: 0.2,
              child: PressFx(
                onTap: () => _scan(p.barcode),
                scale: 0.95,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _statusColor(p.status).withOpacity(0.22)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                  ),
                  child: Row(children: [
                    _statusIcon(p.status, 26),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [ Text(p.name, style: const TextStyle(fontFamily:'Aligarh', fontSize: 10,
                            fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis), Text(p.barcode, style: TextStyle(fontFamily:'Aligarh', fontSize: 9, color: muted)),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),
      ]),
    );
  }

  // ── Small pieces ──────────────────────────────────────────
  SealKind _sealKind(HalalStatus s) {
    switch (s) {
      case HalalStatus.halal:    return SealKind.halal;
      case HalalStatus.doubtful: return SealKind.doubtful;
      case HalalStatus.haram:    return SealKind.haram;
      case HalalStatus.unknown:  return SealKind.unknown;
    }
  }

  Widget _statusIcon(HalalStatus s, double size) {
    final c = _statusColor(s);
    IconData ic;
    switch (s) {
      case HalalStatus.halal:    ic = Icons.check_rounded; break;
      case HalalStatus.doubtful: ic = Icons.priority_high_rounded; break;
      case HalalStatus.haram:    ic = Icons.close_rounded; break;
      case HalalStatus.unknown:  ic = Icons.help_outline_rounded; break;
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withOpacity(0.16),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Icon(ic, size: size * 0.62, color: c),
    );
  }

  Widget _quotaChip(bool isPremium, int used, String lang) {
    final int left = (3 - used).clamp(0, 3).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.50),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: isPremium
        ? [
            const Icon(Icons.all_inclusive_rounded, size: 14, color: AppColors.accentGold),
            const SizedBox(width: 5),
            Text(tLang(lang, 'غير محدود', 'Unlimited', 'Illimité', 'Sınırsız', 'Tanpa Had', 'Tanpa Batas'),
              style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                  color: Colors.white, fontWeight: FontWeight.w700)),
          ]
        : [
            for (var i = 0; i < 3; i++) ...[
              AnimatedContainer(
                duration: Motion.base,
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < left ? AppColors.halalGreen : Colors.white.withOpacity(0.25),
                ),
              ),
              const SizedBox(width: 4),
            ],
            const SizedBox(width: 2),
            Text('${tLang(lang, "متبقي", "Left")} $left/3',
              style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                  color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
    );
  }

  Widget _hintPill(String text, Color col, bool strong) {
    return AnimatedSwitcher(
      duration: Motion.quick,
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: strong ? col.withOpacity(0.8) : Colors.white.withOpacity(0.14)),
        ),
        child: Text(text,
          style: TextStyle(fontFamily: 'Aligarh', fontSize: 11,
              fontWeight: FontWeight.w700,
              color: strong ? col : Colors.white)),
      ),
    );
  }

  Widget _loaderCard(Color bg, String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandGreen.withOpacity(0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ScanLoader(color: AppColors.brandGreen),
        const SizedBox(height: 12),
        Text(
          tLang(lang, '📡 جارٍ البحث في Open Food Facts…', '📡 Searching Open Food Facts…'),
          style: const TextStyle(
            fontFamily: 'Aligarh', fontSize: 13,
            color: AppColors.brandGreen,
            fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  // ── Result card ───────────────────────────────────────────
  Widget _resultCard(ScanResult r, bool isAr, bool isDark, Color bg, Color muted) {
    final lang  = ref.read(languageProvider);
    final col   = _statusColor(r.status);
    final label = isAr ? _labelAr(r.status) : _labelEn(r.status);
    String t(String ar, String en) => tLang(lang, ar, en);
    final key    = '${r.barcode}-${r.scannedAt.microsecondsSinceEpoch}';
    final logged = _loggedKey == key;

    return Reveal(
      key: ValueKey(key),
      offset: 0.14,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(bg, col, isDark ? 0.16 : 0.10)!, bg],
          ),
          border: Border.all(color: col.withOpacity(0.5), width: 1.4),
          boxShadow: [BoxShadow(color: col.withOpacity(0.22), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              VerdictSeal(kind: _sealKind(r.status), color: col, size: 78),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w900,
                    fontSize: 22, color: col)),
                const SizedBox(height: 2),
                Text(r.name, style: const TextStyle(fontFamily:'Aligarh', fontSize: 14,
                    fontWeight: FontWeight.w600)),
                if (r.brand != null && r.brand!.isNotEmpty)
                  Text(r.brand!, style: TextStyle(fontFamily:'Aligarh', fontSize: 11, color: muted)),
              ])),
            ]),
            const Divider(height: 22),
            _row(t('الباركود', 'Barcode'), r.barcode),
            if (r.certs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(spacing: 6, runSpacing: 6, children: r.certs.map((c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.halalGreen.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.halalGreen.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.verified_rounded, size: 12, color: AppColors.halalGreen),
                      const SizedBox(width: 4),
                      Text(c, style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                          fontWeight: FontWeight.w700, color: AppColors.halalGreen)),
                    ]),
                  )).toList()),
                ),
              ),
            if (r.notes != null && r.notes!.isNotEmpty) _row(t('ملاحظات', 'Notes'), r.notes!),
            // ── Nutrition macros (from OFFapi) ──────────────
            if (r.kcal != null) ...[
              const Divider(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                MacroRing(value: '${r.kcal}', label: t('سعرة', 'kcal'),
                    pct: r.kcal! / 600.0, color: AppColors.haramRed),
                if (r.proteinG != null)
                  MacroRing(value: '${r.proteinG!.toStringAsFixed(1)}g', label: t('بروتين', 'Prot'),
                      pct: r.proteinG! / 30.0, color: AppColors.halalGreen),
                if (r.carbsG != null)
                  MacroRing(value: '${r.carbsG!.toStringAsFixed(1)}g', label: t('كربوهيد', 'Carbs'),
                      pct: r.carbsG! / 60.0, color: AppColors.waterBlue),
                if (r.fatG != null)
                  MacroRing(value: '${r.fatG!.toStringAsFixed(1)}g', label: t('دهون', 'Fat'),
                      pct: r.fatG! / 40.0, color: AppColors.accentGold),
              ]),
              const SizedBox(height: 6),
              Text(t('لكل ١٠٠ج', 'per 100g'),
                style: TextStyle(fontFamily: 'Aligarh', fontSize: 9, color: muted),
                textAlign: TextAlign.center),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => setState(() { _result = null; _barcodeCtrl.clear(); _lastBarcode = null; }),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(t('مسح آخر', 'Scan Again'),
                  style: const TextStyle(fontFamily: 'Aligarh')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandGreen,
                  side: const BorderSide(color: AppColors.brandGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
              const SizedBox(width: 10),
              if (r.kcal != null)
                Expanded(child: ElevatedButton.icon(
                  onPressed: logged ? null : () {
                    HapticFeedback.mediumImpact();
                    ref.read(caloriesProvider.notifier).addEntry(
                        r.name, r.kcal!);
                    setState(() => _loggedKey = key);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tLang(lang, '✅ أُضيف للعداد', '✅ Added to tracker', '✅ Ajouté au suivi', '✅ Takibe eklendi', '✅ Ditambah ke penjejak', '✅ Ditambahkan ke pelacak'),
                          style: const TextStyle(fontFamily: 'Aligarh')),
                      backgroundColor: AppColors.brandGreen,
                      duration: const Duration(seconds: 2),
                    ));
                  },
                  icon: Icon(logged ? Icons.check_rounded : Icons.add_rounded,
                      color: Colors.white, size: 16),
                  label: Text(logged ? t('أُضيف', 'Added') : t('أضف للعداد', 'Add to Log'),
                      style: const TextStyle(fontFamily: 'Aligarh', color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    disabledBackgroundColor: AppColors.brandGreen.withOpacity(0.55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ))
              else
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => context.push('/food-photo'),
                  icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                  label: Text(t('تحليل AI', 'AI Analysis'),
                      style: const TextStyle(fontFamily: 'Aligarh', color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _row(String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('$label: ', style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w700, fontSize: 12)), Expanded(child: Text(val, style: const TextStyle(fontFamily:'Aligarh', fontSize: 12, color: AppColors.lightMuted))),
    ]),
  );

  void _showHistory(bool isAr, bool isDark) {
    final history = ref.read(scanProvider).history;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 38, height: 4,
          decoration: BoxDecoration(
            color: AppColors.lightMuted.withOpacity(0.35),
            borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(14), child: Text(tLang(lang, 'سجل الماسحات', 'Scan History', 'Historique des scans', 'Tarama Geçmişi', 'Sejarah Imbasan', 'Riwayat Pemindaian'), style: const TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        if (history.isEmpty) Expanded(child: Center(child: Text(tLang(lang, 'لا توجد ماسحات بعد', 'No scans yet', 'Aucun scan encore', 'Henüz tarama yok', 'Belum ada imbasan', 'Belum ada pemindaian'), style: const TextStyle(fontFamily:'Aligarh', color: AppColors.lightMuted))))
        else
          Expanded(child: ListView(children: history.map((r) => ListTile(
            leading: _statusIcon(r.status, 34), title: Text(r.name, style: const TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w600, fontSize: 13)), subtitle: Text(r.brand ??'', style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11)),
            trailing: Text(
              isAr ? _labelAr(r.status) : _labelEn(r.status), style: TextStyle(fontFamily:'Aligarh', fontSize: 11, fontWeight: FontWeight.w700,
                  color: _statusColor(r.status)),
            ),
          )).toList())),
      ]),
    );
  }

  Color _statusColor(HalalStatus s) {
    switch (s) {
      case HalalStatus.halal:    return AppColors.halalGreen;
      case HalalStatus.doubtful: return AppColors.doubtOrange;
      case HalalStatus.haram:    return AppColors.haramRed;
      case HalalStatus.unknown:  return Colors.grey;
    }
  }

  String _labelAr(HalalStatus s) {
    switch (s) { case HalalStatus.halal:    return'حلال ✓'; case HalalStatus.doubtful: return'مشبوه ⚠️'; case HalalStatus.haram:    return'حرام ✕'; case HalalStatus.unknown:  return'غير معروف ?';
    }
  }

  String _labelEn(HalalStatus s) {
    switch (s) { case HalalStatus.halal:    return'Halal ✓'; case HalalStatus.doubtful: return'Doubtful ⚠️'; case HalalStatus.haram:    return'Haram ✕'; case HalalStatus.unknown:  return'Unknown ?';
    }
  }
}
