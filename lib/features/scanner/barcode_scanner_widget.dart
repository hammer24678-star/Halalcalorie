// barcode_scanner_widget.dart — HalalCalorie v1.0
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();
    return MobileScanner(
      controller: _ctrl,
      onDetect: _onDetect,
      errorBuilder: (context, err, _) {
        if (err.errorCode == MobileScannerErrorCode.permissionDenied) {
          return Center(child: Text(
            'Camera permission denied',
            style: const TextStyle(color: AppColors.haramRed, fontFamily: 'Cairo'),
          ));
        }
        return const Center(child: Text('Camera error',
          style: TextStyle(color: Colors.white)));
      },
    );
  }
}
