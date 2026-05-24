// scanner_screen.dart — HalalCalorie v1.0
import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    // Real camera scanner handles animation internally
  }

  @override void dispose() { _barcodeCtrl.dispose(); super.dispose(); }

  // ── Halal ingredient check ─────────────────────────────
  HalalStatus _halalCheck(String ingredients) {
    final lower = ingredients.toLowerCase();
    const haram = ['alcohol', ' wine', 'pork', ' lard', 'bacon', ' ham,',
      'porcine', 'carmine', 'cochineal', 'e120', 'gelatin porcine'];
    const doubtful = ['gelatin', 'e441', 'e471',
      'mono- and diglycerides', 'natural flavour', 'natural flavor',
      'rennet', 'whey powder'];
    if (haram.any(lower.contains))    return HalalStatus.haram;
    if (doubtful.any(lower.contains)) return HalalStatus.doubtful;
    return HalalStatus.halal;
  }

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

  // ── Main scan: local DB → Open Food Facts API ──────────
  Future<void> _scan(String barcode) async {
    if (_scanning) return;
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
          final kcal   = ((n['energy-kcal_100g'] ?? n['energy_100g'] ?? 0) as num).toInt();
          final prot   = ((n['proteins_100g']       ?? 0) as num).toDouble();
          final carbs  = ((n['carbohydrates_100g']  ?? 0) as num).toDouble();
          final fat    = ((n['fat_100g']            ?? 0) as num).toDouble();
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
            notes:    '📡 Open Food Facts',
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
    showDialog(context: context, builder: (_) => AlertDialog( title: Text(tLang(lang, 'وصلت الحد اليومي', 'Daily Limit Reached', 'Limite journalière atteinte', 'Günlük Limit Aşıldı', 'Had Harian Dicapai', 'Batas Harian Tercapai'), style: const TextStyle(fontFamily:'Cairo')), content: Text(tLang(lang, 'استخدمت ٣ ماسحات اليوم.\nترقّ للبريميوم للمزيد.', 'You have used 3 scans today.\nUpgrade for unlimited.', 'Vous avez utilisé 3 scans aujourd\'hui.\nPassez à Premium.', 'Bugün 3 tarama kullandınız.\nSınırsız için yükseltin.', 'Anda telah menggunakan 3 imbasan.\nNaik taraf untuk tanpa had.', 'Anda telah menggunakan 3 pemindaian.\nUpgrade untuk tak terbatas.'), style: const TextStyle(fontFamily:'Cairo')),
      actions: [
        TextButton(onPressed: () { if (context.mounted) Navigator.pop(context); }, child: Text(tLang(lang, 'إغلاق', 'Close', 'Fermer', 'Kapat', 'Tutup', 'Tutup'), style: const TextStyle(fontFamily: 'Cairo'))), ElevatedButton(onPressed: () { if (context.mounted) Navigator.pop(context); context.push('/paywall'); }, child: Text(tLang(lang, '⭐ ترقية', '⭐ Upgrade', '⭐ Mettre à niveau', '⭐ Yükselt', '⭐ Naik Taraf', '⭐ Upgrade'), style: const TextStyle(fontFamily: 'Cairo'))),
      ],
    ));
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

    return Scaffold(
      appBar: AppBar( title: Text(t('الماسح الذكي 📷', 'Smart Scanner 📷')),
        actions: [
          GestureDetector(
            onTap: () => _showHistory(isAr, isDark),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history, color: Colors.white),
                const SizedBox(width: 4), Text('${scan.history.length}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily:'Cairo')),
              ]),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [

        // ── v1.0 AI Food Photo Hero ───────────────────────
        GestureDetector( onTap: () => context.push('/food-photo'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.sunnahGreen, AppColors.darkGreen],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(
                color: AppColors.sunnahGreen.withOpacity(0.35),
                blurRadius: 16, offset: const Offset(0, 6),
              )],
            ),
            child: Row(children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ), child: const Center(child: Text('📸', style: TextStyle(fontSize: 32))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [ Text(t('تحليل الطعام بـ AI 🤖', 'AI Food Analyzer 🤖'), style: const TextStyle(fontFamily:'Cairo', fontSize: 15,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.barakahGold,
                      borderRadius: BorderRadius.circular(20),
                    ), child: Text(t('جديد!', 'NEW!'), style: const TextStyle(fontFamily:'Cairo', fontSize: 9,
                            fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text( t('صوّر أي طعام ← سعرات + بروتين + حكم حلال فوراً', 'Photo any food ← Calories + Protein + Halal status instantly'), style: const TextStyle(fontFamily:'Cairo', fontSize: 11,
                      color: Colors.white70, height: 1.4),
                ),
              ])),
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            ]),
          ),
        ),

        const SizedBox(height: 14),

        // ── OR divider ───────────────────────────────────
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(t('أو امسح باركود', 'or scan barcode'), style: TextStyle(fontFamily:'Cairo', fontSize: 12, color: muted)),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 14),

                // ── Real Camera Scanner ───────────────────────────
        Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: AppColors.sunnahGreen.withOpacity(0.2),
              blurRadius: 16, offset: const Offset(0, 4),
            )],
          ),
          child: Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BarcodeScannerWidget(
                isActive: true,
                onDetected: (barcode) {
                  if (!isPremium && scan.todayCount >= 3) {
                    _showLimitDialog(isAr);
                    return;
                  }
                  _scan(barcode);
                },
              ),
            ),
            // Scan counter badge
            Positioned(top: 12, right: 12, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isPremium
                    ? (tLang(lang, '♾️ غير محدود', '♾️ Unlimited', '♾️ Illimité', '♾️ Sınırsız', '♾️ Tanpa Had', '♾️ Tanpa Batas'))
                    : '${t("متبقي", "Left")}: ${(3 - scan.todayCount).clamp(0, 3)}/3',
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 11,
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Manual entry ──────────────────────────────────
        Row(children: [
          Expanded(child: TextField(
            controller: _barcodeCtrl,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration( hintText: t('أدخل الباركود يدوياً...', 'Enter barcode manually...'), hintStyle: const TextStyle(fontFamily:'Cairo', fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.qr_code),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          )),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () { if (_barcodeCtrl.text.isNotEmpty) _scan(_barcodeCtrl.text); },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sunnahGreen,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            child: const Icon(Icons.search, color: Colors.white),
          ),
        ]),

        const SizedBox(height: 14),

        // ── Demo products ───────────────────────────────── Text(t('جرّب هذه المنتجات:', 'Try these products:'), style: const TextStyle(fontFamily:'Cairo', fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),

        ElevatedButton(
          onPressed: () {
            final p = kProductsDB[DateTime.now().millisecond % kProductsDB.length];
            _scan(p.barcode);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sunnahGreen.withOpacity(0.1),
            foregroundColor: AppColors.sunnahGreen,
            elevation: 0,
          ), child: Text(t('📷 مسح عشوائي', '📷 Random Scan'), style: const TextStyle(fontFamily:'Cairo', fontSize: 12)),
        ),

        const SizedBox(height: 8),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.8,
          children: kProductsDB.map((p) => GestureDetector(
            onTap: () => _scan(p.barcode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
              ),
              child: Row(children: [
                Text(_statusEmoji(p.status), style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [ Text(p.name, style: const TextStyle(fontFamily:'Cairo', fontSize: 10,
                        fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis), Text(p.barcode, style: TextStyle(fontFamily:'Cairo', fontSize: 9, color: muted)),
                  ]),
                ),
              ]),
            ),
          )).toList(),
        ),

        // ── OFFapi loading indicator ──────────────────────
        if (_scanning) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sunnahGreen.withOpacity(0.3)),
            ),
            child: Column(children: [
              const CircularProgressIndicator(
                color: AppColors.sunnahGreen, strokeWidth: 2.5),
              const SizedBox(height: 10),
              Text(
                tLang(lang, '📡 جارٍ البحث في Open Food Facts…', '📡 Searching Open Food Facts…', '📡 Searching Open Food Facts…', '📡 Searching Open Food Facts…', '📡 Searching Open Food Facts…', '📡 Searching Open Food Facts…'),
                style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 13,
                  color: AppColors.sunnahGreen,
                  fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ],
        // ── Scan result ───────────────────────────────────
        if (_result != null && !_scanning) ...[
          const SizedBox(height: 14),
          _resultCard(_result!, isAr, isDark, bg, muted),
        ],

        const SizedBox(height: 14),
      ]),
    );
  }

  // ── Result card ───────────────────────────────────────────
  Widget _resultCard(ScanResult r, bool isAr, bool isDark, Color bg, Color muted) {
    final lang  = ref.read(languageProvider);
    final col   = _statusColor(r.status);
    final label = isAr ? _labelAr(r.status) : _labelEn(r.status);
    String t(String ar, String en) => tLang(lang, ar, en);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withOpacity(0.45), width: 1.5),
        boxShadow: [BoxShadow(color: col.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_statusEmoji(r.status), style: const TextStyle(fontSize: 42)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(label, style: TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w900,
                  fontSize: 20, color: col)), Text(r.name, style: const TextStyle(fontFamily:'Cairo', fontSize: 14,
                  fontWeight: FontWeight.w600)),
              if (r.brand != null && r.brand!.isNotEmpty) Text(r.brand!, style: TextStyle(fontFamily:'Cairo', fontSize: 11, color: muted)),
            ]),
          ]),
          const Divider(height: 20),
          _row(t('الباركود', 'Barcode'), r.barcode),
          if (r.certs.isNotEmpty) _row(t('الشهادات', 'Certificates'), r.certs.join(' • ')),
          if (r.notes != null && r.notes!.isNotEmpty) _row(t('ملاحظات', 'Notes'), r.notes!),
          // ── Nutrition macros (from OFFapi) ──────────────
          if (r.kcal != null) ...[
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _macroCol('🔥', '${r.kcal}', t('سعرة', 'kcal'), AppColors.haramRed),
              if (r.proteinG != null)
                _macroCol('💪', '${r.proteinG!.toStringAsFixed(1)}g', t('بروتين', 'Prot'), AppColors.halalGreen),
              if (r.carbsG != null)
                _macroCol('🍚', '${r.carbsG!.toStringAsFixed(1)}g', t('كربوهيد', 'Carbs'), AppColors.waterBlue),
              if (r.fatG != null)
                _macroCol('🫒', '${r.fatG!.toStringAsFixed(1)}g', t('دهون', 'Fat'), AppColors.barakahGold),
            ]),
            const SizedBox(height: 4),
            Text(t('لكل ١٠٠ج', 'per 100g'),
              style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: muted),
              textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => setState(() { _result = null; _barcodeCtrl.clear(); }),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(t('مسح آخر', 'Scan Again'),
                style: const TextStyle(fontFamily: 'Cairo')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sunnahGreen,
                side: const BorderSide(color: AppColors.sunnahGreen),
              ),
            )),
            const SizedBox(width: 10),
            if (r.kcal != null)
              Expanded(child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(caloriesProvider.notifier).addEntry(
                      r.name, r.kcal!);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tLang(lang, '✅ أُضيف للعداد', '✅ Added to tracker', '✅ Ajouté au suivi', '✅ Takibe eklendi', '✅ Ditambah ke penjejak', '✅ Ditambahkan ke pelacak'),
                        style: const TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: AppColors.sunnahGreen,
                    duration: const Duration(seconds: 2),
                  ));
                },
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                label: Text(t('أضف للعداد', 'Add to Log'),
                    style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.sunnahGreen),
              ))
            else
              Expanded(child: ElevatedButton.icon(
                onPressed: () => context.push('/food-photo'),
                icon: const Text('📸', style: TextStyle(fontSize: 14)),
                label: Text(t('تحليل AI', 'AI Analysis'),
                    style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.sunnahGreen),
              )),
          ]),
        ]),
      ),
    );
  }

  Widget _macroCol(String emoji, String val, String label, Color col) =>
    Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      Text(val, style: TextStyle(fontFamily:'Cairo',
          fontWeight: FontWeight.w800, fontSize: 13, color: col)),
      Text(label, style: TextStyle(
          fontFamily:'Cairo', fontSize: 9, color: col)),
    ]);

  Widget _row(String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('$label: ', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12)), Expanded(child: Text(val, style: const TextStyle(fontFamily:'Cairo', fontSize: 12, color: AppColors.lightMuted))),
    ]),
  );

  void _showHistory(bool isAr, bool isDark) {
    final history = ref.read(scanProvider).history;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(14), child: Text(tLang(lang, 'سجل الماسحات', 'Scan History', 'Historique des scans', 'Tarama Geçmişi', 'Sejarah Imbasan', 'Riwayat Pemindaian'), style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        if (history.isEmpty) Expanded(child: Center(child: Text(tLang(lang, 'لا توجد ماسحات بعد', 'No scans yet', 'Aucun scan encore', 'Henüz tarama yok', 'Belum ada imbasan', 'Belum ada pemindaian'), style: const TextStyle(fontFamily:'Cairo', color: AppColors.lightMuted))))
        else
          Expanded(child: ListView(children: history.map((r) => ListTile(
            leading: Text(_statusEmoji(r.status), style: const TextStyle(fontSize: 22)), title: Text(r.name, style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w600, fontSize: 13)), subtitle: Text(r.brand ??'', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
            trailing: Text(
              isAr ? _labelAr(r.status) : _labelEn(r.status), style: TextStyle(fontFamily:'Cairo', fontSize: 11, fontWeight: FontWeight.w700,
                  color: _statusColor(r.status)),
            ),
          )).toList())),
      ]),
    );
  }

  String _statusEmoji(HalalStatus s) {
    switch (s) { case HalalStatus.halal:    return'✅'; case HalalStatus.doubtful: return'⚠️'; case HalalStatus.haram:    return'❌'; case HalalStatus.unknown:  return'❓';
    }
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
