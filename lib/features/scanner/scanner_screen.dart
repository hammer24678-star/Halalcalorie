// scanner_screen.dart — HalalCalorie v1.0
import 'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:go_router/go_router.dart'; import'../../core/theme.dart'; import'../../core/providers.dart'; import'../../data/models/models.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});
  @override ConsumerState<ScannerScreen> createState() => _ScannerState();
}

class _ScannerState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final _barcodeCtrl = TextEditingController();
  ScanResult? _result;

  @override
  void initState() {
    super.initState();
    // Real camera scanner handles animation internally
  }

  @override void dispose() { _barcodeCtrl.dispose(); super.dispose(); }

  void _scan(String barcode) {
    final scan      = ref.read(scanProvider);
    final isPremium = ref.read(premiumProvider); final isAr      = ref.read(languageProvider) =='ar';
    if (!isPremium && scan.todayCount >= 10) { _showLimitDialog(isAr); return; }
    final product = kProductsDB.firstWhere((p) => p.barcode == barcode,
        orElse: () => ScanResult(
          barcode: barcode, name:    isAr ?'منتج غير معروف' : 'Unknown Product', brand:   isAr ?'غير معروف'       : 'Unknown',
          status:  HalalStatus.unknown, notes:   isAr ?'لا توجد بيانات' : 'No data found'));
    final r = ScanResult(barcode: barcode, name: product.name, brand: product.brand,
        status: product.status, certs: product.certs, notes: product.notes);
    ref.read(scanProvider.notifier).addScan(r);
    setState(() => _result = r);
  }

  void _showLimitDialog(bool isAr) {
    showDialog(context: context, builder: (_) => AlertDialog( title: Text(isAr ?'وصلت الحد اليومي' : 'Daily Limit Reached', style: const TextStyle(fontFamily:'Cairo')), content: Text(isAr ?'استخدمت ١٠ ماسحات اليوم.\nترقّ للبريميوم للمزيد.' : 'You\'ve used 10 scans today.\nUpgrade for unlimited.', style: const TextStyle(fontFamily:'Cairo')),
      actions: [
        TextButton(onPressed: () => if (context.mounted) Navigator.pop(context), child: Text(isAr ?'إغلاق' : 'Close', style: const TextStyle(fontFamily: 'Cairo'))), ElevatedButton(onPressed: () { if (context.mounted) Navigator.pop(context); context.push('/paywall'); }, child: Text(isAr ?'⭐ ترقية' : '⭐ Upgrade', style: const TextStyle(fontFamily: 'Cairo'))),
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
    String t(String ar, String en) => isAr ? ar : en;

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
                  if (!isPremium && scan.todayCount >= 10) {
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
                    ? (isAr ? '♾️ غير محدود' : '♾️ Unlimited')
                    : '${t("متبقي", "Left")}: ${(10 - scan.todayCount).clamp(0, 10)}/10',
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

        // ── Scan result ───────────────────────────────────
        if (_result != null) ...[
          const SizedBox(height: 14),
          _resultCard(_result!, isAr, isDark, bg, muted),
        ],

        const SizedBox(height: 14),
      ]),
    );
  }

  // ── Result card ───────────────────────────────────────────
  Widget _resultCard(ScanResult r, bool isAr, bool isDark, Color bg, Color muted) {
    final col   = _statusColor(r.status);
    final label = isAr ? _labelAr(r.status) : _labelEn(r.status);
    String t(String ar, String en) => isAr ? ar : en;

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
          const Divider(height: 20), _row(t('الباركود', 'Barcode'), r.barcode), if (r.certs.isNotEmpty) _row(t('الشهادات', 'Certificates'), r.certs.join(' • ')), if (r.notes != null && r.notes!.isNotEmpty) _row(t('ملاحظات', 'Notes'), r.notes!),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => setState(() { _result = null; _barcodeCtrl.clear(); }),
              icon: const Icon(Icons.refresh, size: 16), label: Text(t('مسح آخر', 'Scan Again'), style: const TextStyle(fontFamily: 'Cairo')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sunnahGreen,
                side: const BorderSide(color: AppColors.sunnahGreen),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon( onPressed: () => context.push('/food-photo'), icon: const Text('📸', style: TextStyle(fontSize: 14)), label: Text(t('تحليل AI', 'AI Analysis'), style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.sunnahGreen),
            )),
          ]),
        ]),
      ),
    );
  }

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
          padding: const EdgeInsets.all(14), child: Text(isAr ?'سجل الماسحات' : 'Scan History', style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        if (history.isEmpty) Expanded(child: Center(child: Text(isAr ?'لا توجد ماسحات بعد' : 'No scans yet', style: const TextStyle(fontFamily:'Cairo', color: AppColors.lightMuted))))
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
