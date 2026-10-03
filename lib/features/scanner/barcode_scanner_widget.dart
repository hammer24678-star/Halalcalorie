// barcode_scanner_widget.dart — HalalCalorie v1.0 (v48: torch + flip)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme.dart';

class BarcodeScannerWidget extends StatefulWidget {
  final bool isActive;
  final void Function(String barcode) onDetected;
  const BarcodeScannerWidget({
    super.key, required this.isActive, required this.onDetected});
  @override State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  late MobileScannerController _ctrl;
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) widget.onDetected(barcode!.rawValue!);
  }

  Future<void> _toggleTorch() async {
    try {
      await _ctrl.toggleTorch();
      if (mounted) setState(() => _torch = !_torch);
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  Future<void> _flip() async {
    try {
      await _ctrl.switchCamera();
      if (mounted) setState(() => _torch = false);
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  Widget _roundBtn(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 38, height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppColors.accentGold.withOpacity(0.92)
              : Colors.black.withOpacity(0.50),
          border: Border.all(
              color: Colors.white.withOpacity(active ? 0.0 : 0.16)),
        ),
        child: Icon(icon, size: 20,
            color: active ? Colors.black : Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();
    return Stack(fit: StackFit.expand, children: [
      MobileScanner(
        controller: _ctrl,
        onDetect: _onDetect,
        errorBuilder: (context, err, _) {
          if (err.errorCode == MobileScannerErrorCode.permissionDenied) {
            return Center(child: Text(
              'Camera permission denied',
              style: const TextStyle(color: AppColors.haramRed, fontFamily: 'Aligarh'),
            ));
          }
          return const Center(child: Text('Camera error',
            style: TextStyle(color: Colors.white)));
        },
      ),
      Positioned(
        top: 12, left: 12,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _roundBtn(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              _torch, _toggleTorch),
          const SizedBox(width: 8),
          _roundBtn(Icons.cameraswitch_rounded, false, _flip),
        ]),
      ),
    ]);
  }
}
