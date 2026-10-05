// scanner_screen.dart — HalalCalorie v1.0
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/motion.dart';
import '../../core/fx5.dart';
import '../../core/ai_service.dart';
import '../../core/halal_engine.dart';
import '../../core/scan_store.dart';
import '../../core/open_food_facts_service.dart';
import 'package:image_picker/image_picker.dart';
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
  double _grams = 100;                    // portion on the result card (v57)
  List<Map<String, dynamic>>? _alts;      // healthier halal-safe picks
  bool _altsLoading = false;
  bool _labelBusy = false;

  @override
  void initState() {
    super.initState();
    // Real camera scanner handles animation internally
  }

  @override void dispose() { _barcodeCtrl.dispose(); super.dispose(); }

  // ── v55: smart scanner core ───────────────────────────
  String _t(String ar, String en) => tLang(ref.read(languageProvider), ar, en);

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Aligarh')),
      backgroundColor: color ?? AppColors.brandGreen,
      duration: const Duration(seconds: 2),
    ));
  }

  // One entry point for showing a result: resets the portion + alternatives.
  void _showResult(ScanResult r) {
    final d = r.details ?? const <String, dynamic>{};
    final sg = (d['serving_g'] as num?)?.toDouble();
    setState(() {
      _result = r;
      _grams = (sg != null && sg >= 5 && sg <= 500) ? sg.roundToDouble() : 100;
      _alts = null;
      _altsLoading = false;
      _scanning = false;
    });
    _loadAlternatives(r);
  }

  Future<void> _loadAlternatives(ScanResult r) async {
    final d = r.details;
    if (d == null) return;
    final nutri = (d['nutri'] ?? '') as String;
    final worth = nutri == 'c' || nutri == 'd' || nutri == 'e' ||
        r.status == HalalStatus.haram || r.status == HalalStatus.doubtful;
    final cats = [for (final c in (d['categories'] as List? ?? const [])) '$c'];
    if (!worth || cats.isEmpty) return;
    final key = r.barcode;
    if (mounted) setState(() => _altsLoading = true);
    final alts = await OpenFoodFactsService.alternatives(
        categoryTag: cats.last, excludeCode: r.barcode);
    if (!mounted || _result?.barcode != key) return;
    setState(() { _alts = alts; _altsLoading = false; });
  }

  // Open Food Facts sends numbers, numeric strings or null depending on the product.
  static num? _numOf(dynamic v) =>
      v is num ? v : (v is String ? num.tryParse(v) : null);

  Map<String, dynamic> _detailsOf(HalalReport rep, Map<String, dynamic> d,
      {required bool vegan, required bool certified}) {
    final analysis = [for (final a in (d['analysis'] as List? ?? const [])) '$a'];
    return {
      'flags': [for (final f in rep.flags) f.toJson()],
      'ingredients': d['ingredients'] ?? '',
      'image': d['image_url'] ?? '',
      'serving_g': d['serving_g'],
      'quantity': d['quantity'] ?? '',
      'nutri': d['nutri'] ?? '',
      'nova': d['nova'],
      'sugar': d['sugar_g'], 'salt': d['salt_g'],
      'satfat': d['satfat_g'], 'fiber': d['fiber_g'],
      'fat': d['fat_g'],
      'allergens': d['allergens'] ?? const [],
      'categories': d['categories'] ?? const [],
      'vegan': vegan,
      'vegetarian': analysis.contains('vegetarian') || vegan,
      'certified': certified,
    };
  }

  ScanResult _fromOff(String barcode, Map<String, dynamic> d) {
    final ing = (d['ingredients'] ?? '') as String;
    final labels = [for (final l in (d['labels'] as List? ?? const [])) '$l'.toLowerCase()];
    final analysis = [for (final a in (d['analysis'] as List? ?? const [])) '$a'];
    final certified = labels.any((l) => l.contains('halal'));
    final vegan = analysis.contains('vegan');
    final rep = HalalEngine.analyze(ing, vegan: vegan ? true : null, certified: certified);
    final kcal = (_numOf(d['kcal']) ?? 0).round();
    final prot = (_numOf(d['protein_g']) ?? 0).toDouble();
    final carbs = (_numOf(d['carbs_g']) ?? 0).toDouble();
    final fat = (_numOf(d['fat_g']) ?? 0).toDouble();
    final name = (d['name'] ?? '') as String;
    return ScanResult(
      barcode: barcode,
      name: name.isEmpty ? _t('منتج مجهول', 'Unknown product') : name,
      brand: (d['brand'] ?? '') as String,
      status: rep.status,
      certs: certified ? [_t('علامة حلال على العبوة', 'Halal label on pack')] : const [],
      kcal: kcal > 0 ? kcal : null,
      proteinG: prot > 0 ? prot : null,
      carbsG: carbs > 0 ? carbs : null,
      fatG: fat > 0 ? fat : null,
      notes: ing.trim().isEmpty
          ? '📡 Open Food Facts · ' + _t('لا توجد بيانات مكونات — راجع الملصق', 'No ingredient data — check the label')
          : '📡 Open Food Facts',
      details: _detailsOf(rep, d, vegan: vegan, certified: certified),
    );
  }

  // ── Unknown product fallback ───────────────────────────
  void _unknownProduct(String barcode, bool isAr) {
    final r = ScanResult(
      barcode: barcode,
      name:   tLang(lang, 'منتج غير معروف', 'Unknown Product', 'Produit inconnu', 'Bilinmeyen Ürün', 'Produk Tidak Diketahui', 'Produk Tidak Diketahui'),
      brand:  tLang(lang, 'غير معروف', 'Unknown', 'Inconnu', 'Bilinmiyor', 'Tidak diketahui', 'Tidak diketahui'),
      status: HalalStatus.unknown,
      notes:  tLang(lang, 'لا توجد بيانات — صوّر الملصق أو جرّب تحليل AI', 'No data — photograph the label or try AI Analysis', 'Pas de données — essayez l\'analyse IA', 'Veri yok — AI Analizini deneyin', 'Tiada data — cuba Analisis AI', 'Tidak ada data — coba Analisis AI'),
      details: const {'flags': [], 'unknown': true},
    );
    ref.read(scanProvider.notifier).addScan(r);
    if (mounted) _showResult(r);
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

  // ── Main scan: local DB → Open Food Facts → offline cache ──
  Future<void> _scan(String barcode) async {
    if (_scanning) return;
    barcode = barcode.trim();
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
      _showResult(local);
      return;
    }

    // 2. Open Food Facts
    setState(() { _scanning = true; _result = null; });
    final res = await OpenFoodFactsService.lookupBarcodeFull(barcode);
    if (!mounted) return;
    if (res.data != null) {
      final r = _fromOff(barcode, res.data!);
      ScanStore.cachePut(r);
      ref.read(scanProvider.notifier).addScan(r);
      _showResult(r);
      return;
    }

    // 3. No connection → last good copy of this product, if we have one
    if (res.failed) {
      final cached = await ScanStore.cacheGet(barcode);
      if (!mounted) return;
      if (cached != null) {
        final r = ScanResult(
          barcode: cached.barcode, name: cached.name, brand: cached.brand,
          status: cached.status, certs: cached.certs,
          notes: '📴 ' + _t('نسخة محفوظة (بدون إنترنت)', 'Saved copy (offline)'),
          kcal: cached.kcal, proteinG: cached.proteinG,
          carbsG: cached.carbsG, fatG: cached.fatG, details: cached.details,
        );
        ref.read(scanProvider.notifier).addScan(r);
        _showResult(r);
        return;
      }
      setState(() => _scanning = false);
      _lastBarcode = null; // let the camera retry
      _snack(_t('لا يوجد اتصال — حاول مجدداً', 'No connection — try again'),
          color: AppColors.doubtOrange);
      return;
    }
    _unknownProduct(barcode, isAr);
  }

  // ── Photograph an ingredient label → AI reads it → halal engine ──
  Future<void> _readLabel() async {
    if (_labelBusy) return;
    final isPremium = ref.read(premiumProvider);
    if (!isPremium && ref.read(aiPhotoScanProvider) >= 3) {
      if (mounted) context.push('/paywall');
      return;
    }
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
      if (x == null || !mounted) return;
      setState(() => _labelBusy = true);
      final txt = await AIService.readIngredientLabel(
          imagePath: x.path, language: ref.read(languageProvider));
      if (!mounted) return;
      if (txt.trim().isEmpty) {
        _snack(_t('لم أجد قائمة مكونات في الصورة', 'No ingredient list found in the photo'),
            color: AppColors.doubtOrange);
        return;
      }
      await ref.read(aiPhotoScanProvider.notifier).increment();
      final rep = HalalEngine.analyze(txt);
      final prev = _result;
      final r = ScanResult(
        barcode: prev != null && !prev.barcode.startsWith('label-')
            ? prev.barcode
            : 'label-${DateTime.now().millisecondsSinceEpoch}',
        name: prev != null && prev.name.isNotEmpty && prev.status != HalalStatus.unknown
            ? prev.name
            : _t('منتج من صورة الملصق', 'Product from label photo'),
        brand: prev?.brand,
        status: rep.status,
        notes: '📝 ' + _t('قرأها الذكاء الاصطناعي من الملصق', 'Read from the label by AI'),
        kcal: prev?.kcal, proteinG: prev?.proteinG,
        carbsG: prev?.carbsG, fatG: prev?.fatG,
        details: {
          ...?prev?.details,
          'flags': [for (final f in rep.flags) f.toJson()],
          'ingredients': txt,
          'fromLabel': true,
        },
      );
      _showResult(r);
    } catch (_) {
      _snack(_t('تعذّرت قراءة الملصق', 'Could not read the label'),
          color: AppColors.haramRed);
    } finally {
      if (mounted) setState(() => _labelBusy = false);
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

        // ── Favourites (v57) ──────────────────────────────
        Builder(builder: (_) {
          final favs = ref.watch(scanFavsProvider);
          final seen = <String>{};
          final items = [
            for (final r in scan.history)
              if (favs.contains(r.barcode) && seen.add(r.barcode)) r
          ];
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.star_rounded, size: 16, color: AppColors.accentGold),
              const SizedBox(width: 6),
              Text(t('المفضلة', 'Favourites'), style: const TextStyle(fontFamily: 'Aligarh',
                  fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final r in items)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: PressFx(
                      onTap: () { _lastBarcode = r.barcode; _showResult(r); },
                      scale: 0.95,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _statusColor(r.status).withOpacity(0.35)),
                        ),
                        child: Row(children: [
                          _statusIcon(r.status, 24),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
          ]);
        }),

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
  static const Map<String, Color> _gradeColors = {
    'a': Color(0xFF038141), 'b': Color(0xFF85BB2F), 'c': Color(0xFFFECB02),
    'd': Color(0xFFEE8100), 'e': Color(0xFFE63E11),
  };

  Color _lvl(double v, double lo, double hi) => v <= lo
      ? AppColors.halalGreen
      : (v <= hi ? AppColors.accentGold : AppColors.haramRed);

  Widget _pill(String text, Color c, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withOpacity(0.45)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
      Text(text, style: TextStyle(fontFamily: 'Aligarh', fontSize: 11,
          fontWeight: FontWeight.w700, color: c)),
    ]),
  );

  Widget _sectionTitle(String text, Color muted) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
          fontWeight: FontWeight.w800, color: muted, letterSpacing: 0.3)),
    ),
  );

  Widget _flagTile(IngredientFlag f, bool isAr, Color muted) {
    final c = f.level == HalalStatus.haram ? AppColors.haramRed : AppColors.doubtOrange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.withOpacity(0.16)),
          child: Icon(f.level == HalalStatus.haram
              ? Icons.close_rounded : Icons.priority_high_rounded, size: 14, color: c),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.term, style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
              fontWeight: FontWeight.w800, color: c)),
          Text(isAr ? f.whyAr : f.whyEn, style: TextStyle(fontFamily: 'Aligarh',
              fontSize: 11, height: 1.4, color: muted)),
        ])),
      ]),
    );
  }

  Widget _altTile(Map<String, dynamic> a, Color bg, Color muted) {
    final g = ((a['grade'] ?? '') as String).toLowerCase();
    final gc = _gradeColors[g] ?? Colors.grey;
    final brand = (a['brand'] ?? '') as String;
    return PressFx(
      onTap: () => _scan('${a['code']}'),
      scale: 0.97,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.halalGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.halalGreen.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            width: 26, height: 26, alignment: Alignment.center,
            decoration: BoxDecoration(color: gc, shape: BoxShape.circle),
            child: Text(g.toUpperCase(), style: const TextStyle(fontFamily: 'Aligarh',
                fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                    fontWeight: FontWeight.w700)),
            if (brand.isNotEmpty)
              Text(brand, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 18, color: muted),
        ]),
      ),
    );
  }

  Widget _resultCard(ScanResult r, bool isAr, bool isDark, Color bg, Color muted) {
    final lang  = ref.read(languageProvider);
    final col   = _statusColor(r.status);
    final label = isAr ? _labelAr(r.status) : _labelEn(r.status);
    String t(String ar, String en) => tLang(lang, ar, en);
    final key    = '${r.barcode}-${r.scannedAt.microsecondsSinceEpoch}';
    final logged = _loggedKey == key;

    final d = r.details ?? const <String, dynamic>{};
    final flags = [
      for (final e in (d['flags'] as List? ?? const []))
        if (e is Map) IngredientFlag.fromJson(Map<String, dynamic>.from(e))
    ];
    final fav = ref.watch(scanFavsProvider).contains(r.barcode);
    final img = (d['image'] ?? '') as String;
    final qty = (d['quantity'] ?? '') as String;
    final ingredients = (d['ingredients'] ?? '') as String;
    final nutri = (d['nutri'] ?? '') as String;
    final nova = (d['nova'] as num?)?.toInt();
    final allergens = [for (final a in (d['allergens'] as List? ?? const [])) '$a'];
    final vegan = d['vegan'] == true;
    final vegetarian = d['vegetarian'] == true;
    final certified = d['certified'] == true || r.certs.isNotEmpty;
    final isLabelOnly = r.barcode.startsWith('label-');
    final needsLabel = ingredients.trim().isEmpty || r.status == HalalStatus.unknown;

    final g = _grams;
    final k = g / 100.0;
    final kcalS = r.kcal == null ? null : (r.kcal! * k).round();
    final protS = r.proteinG == null ? null : r.proteinG! * k;
    final carbS = r.carbsG == null ? null : r.carbsG! * k;
    final fatS  = r.fatG == null ? null : r.fatG! * k;
    final sg = (d['serving_g'] as num?)?.toDouble();

    const novaAr = {1: 'غير مصنّع', 2: 'مكوّن طهي', 3: 'مصنّع', 4: 'فائق التصنيع'};
    const novaEn = {1: 'Unprocessed', 2: 'Culinary', 3: 'Processed', 4: 'Ultra-processed'};

    final traffic = <Widget>[];
    void addT(String name, num? v, double lo, double hi) {
      if (v == null) return;
      traffic.add(_pill('$name ${v.toStringAsFixed(1)}g', _lvl(v.toDouble(), lo, hi)));
    }
    addT(t('دهون', 'Fat'), (d['fat'] as num?), 3, 17.5);
    addT(t('مشبعة', 'Sat. fat'), (d['satfat'] as num?), 1.5, 5);
    addT(t('سكر', 'Sugar'), (d['sugar'] as num?), 5, 22.5);
    addT(t('ملح', 'Salt'), (d['salt'] as num?), 0.3, 1.5);

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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Verdict ─────────────────────────────────────
            Row(children: [
              VerdictSeal(kind: _sealKind(r.status), color: col, size: 78),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w900,
                    fontSize: 24, color: col)),
                const SizedBox(height: 2),
                Text(
                  r.status == HalalStatus.halal
                      ? t('لم نجد مكونات محرّمة أو مشبوهة', 'No haram or doubtful ingredients found')
                      : r.status == HalalStatus.haram
                          ? t('يحتوي على مكوّن محرّم', 'Contains a haram ingredient')
                          : r.status == HalalStatus.doubtful
                              ? t('بعض المكوّنات تحتاج تحقّق', 'Some ingredients need checking')
                              : t('لا نملك قائمة المكوّنات', 'No ingredient list available'),
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, height: 1.4, color: muted)),
              ])),
              if (!isLabelOnly)
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref.read(scanFavsProvider.notifier).toggle(r.barcode);
                  },
                  icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: fav ? AppColors.accentGold : muted, size: 28),
                ),
            ]),
            const Divider(height: 24),

            // ── Product ─────────────────────────────────────
            Row(children: [
              if (img.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(img, width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, style: const TextStyle(fontFamily:'Aligarh', fontSize: 15,
                    fontWeight: FontWeight.w700)),
                if ((r.brand ?? '').isNotEmpty || qty.isNotEmpty)
                  Text([if ((r.brand ?? '').isNotEmpty) r.brand!, if (qty.isNotEmpty) qty].join(' · '),
                      style: TextStyle(fontFamily:'Aligarh', fontSize: 11, color: muted)),
                if (!isLabelOnly)
                  Text(r.barcode, style: TextStyle(fontFamily:'Aligarh', fontSize: 10, color: muted)),
              ])),
            ]),

            // ── Badges ──────────────────────────────────────
            if (nutri.isNotEmpty || nova != null || vegan || vegetarian || certified || allergens.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (certified)
                  _pill(r.certs.isNotEmpty ? r.certs.first : t('علامة حلال', 'Halal label'),
                      AppColors.halalGreen, icon: Icons.verified_rounded),
                if (nutri.isNotEmpty)
                  _pill('Nutri-Score ${nutri.toUpperCase()}',
                      _gradeColors[nutri] ?? Colors.grey, icon: Icons.favorite_rounded),
                if (nova != null)
                  _pill('NOVA $nova · ${isAr ? novaAr[nova] : novaEn[nova]}',
                      nova >= 4 ? AppColors.haramRed : (nova == 3 ? AppColors.accentGold : AppColors.halalGreen)),
                if (vegan) _pill(t('نباتي', 'Vegan'), AppColors.halalGreen, icon: Icons.eco_rounded)
                else if (vegetarian) _pill(t('نباتي جزئياً', 'Vegetarian'), AppColors.halalGreen, icon: Icons.eco_rounded),
                for (final a in allergens.take(6))
                  _pill(a, AppColors.doubtOrange, icon: Icons.warning_amber_rounded),
              ]),
            ],

            // ── Why this verdict ────────────────────────────
            _sectionTitle(t('سبب الحكم', 'WHY THIS VERDICT'), muted),
            if (flags.isEmpty)
              Row(children: [
                Icon(needsLabel ? Icons.help_outline_rounded : Icons.check_circle_rounded,
                    size: 18, color: needsLabel ? Colors.grey : AppColors.halalGreen),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  needsLabel
                      ? t('لا توجد قائمة مكوّنات — صوّر الملصق ليقرأها الذكاء الاصطناعي',
                          'No ingredient list — photograph the label and AI will read it')
                      : t('فحصنا المكوّنات والإضافات (E) ولم نجد ما يثير الشك',
                          'We checked the ingredients and E-numbers — nothing raised a flag'),
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, height: 1.4, color: muted))),
              ])
            else
              for (final f in flags) _flagTile(f, isAr, muted),
            if (ingredients.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 6),
                  dense: true,
                  title: Text(t('المكوّنات كما على العبوة', 'Ingredients as printed'),
                      style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: muted)),
                  children: [Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(ingredients, style: TextStyle(fontFamily: 'Aligarh',
                        fontSize: 11, height: 1.5, color: muted)),
                  )],
                ),
              ),
            if (r.notes != null && r.notes!.isNotEmpty && flags.isEmpty && !needsLabel)
              Padding(padding: const EdgeInsets.only(top: 4),
                  child: Text(r.notes!, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted))),

            // ── Nutrition + portion ─────────────────────────
            if (r.kcal != null) ...[
              _sectionTitle(t('القيمة الغذائية', 'NUTRITION'), muted),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                MacroRing(value: '$kcalS', label: t('سعرة', 'kcal'),
                    pct: kcalS! / 600.0, color: AppColors.haramRed),
                if (protS != null)
                  MacroRing(value: '${protS.toStringAsFixed(1)}g', label: t('بروتين', 'Prot'),
                      pct: protS / 30.0, color: AppColors.halalGreen),
                if (carbS != null)
                  MacroRing(value: '${carbS.toStringAsFixed(1)}g', label: t('كربوهيد', 'Carbs'),
                      pct: carbS / 60.0, color: AppColors.waterBlue),
                if (fatS != null)
                  MacroRing(value: '${fatS.toStringAsFixed(1)}g', label: t('دهون', 'Fat'),
                      pct: fatS / 40.0, color: AppColors.accentGold),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text(t('الكمية', 'Portion'), style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: muted)),
                const Spacer(),
                Text('${g.round()} g', style: const TextStyle(fontFamily: 'Aligarh',
                    fontSize: 15, fontWeight: FontWeight.w900)),
              ]),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 4),
                child: Slider(
                  value: g.clamp(10.0, 500.0).toDouble(),
                  min: 10, max: 500, divisions: 49,
                  activeColor: AppColors.brandGreen,
                  onChanged: (v) => setState(() => _grams = v.roundToDouble()),
                ),
              ),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final q in <double>[
                  if (sg != null && sg >= 5 && sg <= 500) sg.roundToDouble(),
                  50, 100, 200,
                ].toSet())
                  PressFx(
                    onTap: () => setState(() => _grams = q),
                    scale: 0.94,
                    child: _pill(
                        sg != null && q == sg.roundToDouble() && q != 100 && q != 50 && q != 200
                            ? '${t("حصة", "Serving")} ${q.round()}g'
                            : '${q.round()}g',
                        q == g ? AppColors.brandGreen : muted),
                  ),
              ]),
              if (traffic.isNotEmpty) ...[
                _sectionTitle(t('لكل ١٠٠ غ', 'PER 100 G'), muted),
                Wrap(spacing: 6, runSpacing: 6, children: traffic),
              ],
            ],

            // ── Better alternatives ─────────────────────────
            if (_altsLoading) ...[
              _sectionTitle(t('بدائل أفضل', 'BETTER PICKS'), muted),
              Row(children: [
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandGreen)),
                const SizedBox(width: 10),
                Text(t('أبحث عن بدائل حلال وأصحّ…', 'Looking for healthier halal-safe options…'),
                    style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: muted)),
              ]),
            ] else if (_alts != null && _alts!.isNotEmpty) ...[
              _sectionTitle(t('بدائل أصحّ وحلال', 'HEALTHIER HALAL-SAFE PICKS'), muted),
              for (final a in _alts!) _altTile(a, bg, muted),
            ],

            const SizedBox(height: 12),
            Text(
              t('فحص آلي مساعد وليس فتوى — تحقّق من شعار الحلال على العبوة.',
                  'Automated aid, not a fatwa — verify with the halal logo on the pack.'),
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 9.5, color: muted, height: 1.4)),
            const SizedBox(height: 12),

            // ── Actions ─────────────────────────────────────
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _result = null; _alts = null; _altsLoading = false;
                  _barcodeCtrl.clear(); _lastBarcode = null;
                }),
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
                        g.round() == 100 ? r.name : '${r.name} (${g.round()}g)',
                        kcalS!,
                        proteinG: protS ?? 0, carbsG: carbS ?? 0, fatG: fatS ?? 0);
                    setState(() => _loggedKey = key);
                    _snack(tLang(lang, '✅ أُضيف للعداد', '✅ Added to tracker', '✅ Ajouté au suivi', '✅ Takibe eklendi', '✅ Ditambah ke penjejak', '✅ Ditambahkan ke pelacak'));
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
            if (needsLabel && !isLabelOnly) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _labelBusy ? null : _readLabel,
                icon: _labelBusy
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.document_scanner_rounded, size: 16),
                label: Text(t('صوّر ملصق المكوّنات (AI)', 'Photograph ingredient label (AI)'),
                    style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentGold,
                  side: BorderSide(color: AppColors.accentGold.withOpacity(0.7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
            ],
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
    final lang = ref.read(languageProvider);
    String t(String ar, String en) => tLang(lang, ar, en);
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    bool onlyFav = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => SizedBox(
        height: MediaQuery.of(sheetCtx).size.height * 0.72,
        child: Consumer(builder: (cctx, w, _) {
          final all = w.watch(scanProvider).history;
          final favs = w.watch(scanFavsProvider);
          return StatefulBuilder(builder: (c2, setS) {
            final list = onlyFav ? all.where((r) => favs.contains(r.barcode)).toList() : all;
            return Column(children: [
              const SizedBox(height: 8),
              Container(width: 38, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightMuted.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(children: [
                  Expanded(child: Text(tLang(lang, 'سجل الماسحات', 'Scan History', 'Historique des scans', 'Tarama Geçmişi', 'Sejarah Imbasan', 'Riwayat Pemindaian'),
                      style: const TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w700, fontSize: 16))),
                  PressFx(
                    onTap: () => setS(() => onlyFav = false),
                    scale: 0.94,
                    child: _pill(t('الكل', 'All'), !onlyFav ? AppColors.brandGreen : muted)),
                  const SizedBox(width: 6),
                  PressFx(
                    onTap: () => setS(() => onlyFav = true),
                    scale: 0.94,
                    child: _pill(t('المفضلة', 'Favourites'), onlyFav ? AppColors.accentGold : muted,
                        icon: Icons.star_rounded)),
                ]),
              ),
              if (list.isEmpty)
                Expanded(child: Center(child: Text(
                    onlyFav ? t('لا توجد منتجات مفضلة', 'No favourites yet')
                        : tLang(lang, 'لا توجد ماسحات بعد', 'No scans yet', 'Aucun scan encore', 'Henüz tarama yok', 'Belum ada imbasan', 'Belum ada pemindaian'),
                    style: TextStyle(fontFamily:'Aligarh', color: muted))))
              else
                Expanded(child: ListView(children: list.map((r) {
                  final isFav = favs.contains(r.barcode);
                  return ListTile(
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _lastBarcode = r.barcode;
                      _showResult(r);
                    },
                    leading: _statusIcon(r.status, 34),
                    title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(
                        '${r.brand ?? ''}${(r.brand ?? '').isNotEmpty ? ' · ' : ''}${isAr ? _labelAr(r.status) : _labelEn(r.status)}',
                        style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: _statusColor(r.status))),
                    trailing: r.barcode.startsWith('label-') ? null : IconButton(
                      icon: Icon(isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isFav ? AppColors.accentGold : muted),
                      onPressed: () => ref.read(scanFavsProvider.notifier).toggle(r.barcode),
                    ),
                  );
                }).toList())),
            ]);
          });
        }),
      ),
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
