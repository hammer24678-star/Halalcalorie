// ============================================================
//  barcode_scanner_widget.dart — HalalCalorie
//  Real camera barcode scanner using mobile_scanner
//  Drop-in replacement for the fake viewfinder
// ============================================================
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme.dart';

class BarcodeScannerWidget extends StatefulWidget {
  final void Function(String barcode) onDetected;
  final bool isActive;

  const BarcodeScannerWidget({
    super.key,
    required this.onDetected,
    this.isActive = true,
  });

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  late MobileScannerController _ctrl;
  bool _hasDetected = false;
  bool _torchOn    = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BarcodeScannerWidget old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _hasDetected = false;
      _ctrl.start();
    } else if (!widget.isActive && old.isActive) {
      _ctrl.stop();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _hasDetected = true;
        _ctrl.stop();
        widget.onDetected(raw);
        // Allow re-scan after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _hasDetected = false);
            _ctrl.start();
          }
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(children: [
        // ── Camera feed ─────────────────────────────────
        MobileScanner(
          controller: _ctrl,
          onDetect: _onDetect,
          errorBuilder: (ctx, err, child) => Container(
            color: Colors.black87,
            child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_outlined,
                    color: Colors.white54, size: 48),
                const SizedBox(height: 12),
                Text(
                  err.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Camera permission denied\nPlease allow in Settings'
                      : 'Camera unavailable',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Cairo', color: Colors.white70, fontSize: 13),
                ),
              ],
            )),
          ),
        ),

        // ── Scan overlay ─────────────────────────────────
        Positioned.fill(child: CustomPaint(painter: _ScanOverlay())),

        // ── Scan line animation ───────────────────────────
        if (!_hasDetected)
          const Positioned.fill(child: _ScanLineAnimation()),

        // ── Success flash ─────────────────────────────────
        if (_hasDetected)
          Positioned.fill(child: Container(
            color: AppColors.sunnahGreen.withOpacity(0.3),
            child: const Center(child: Icon(
              Icons.check_circle,
              color: AppColors.sunnahGreen,
              size: 64,
            )),
          )),

        // ── Torch button ──────────────────────────────────
        Positioned(
          bottom: 12, right: 12,
          child: GestureDetector(
            onTap: () {
              setState(() => _torchOn = !_torchOn);
              _ctrl.toggleTorch();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _torchOn
                    ? AppColors.barakahGold
                    : Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _torchOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white, size: 20,
              ),
            ),
          ),
        ),

        // ── Flip camera button ────────────────────────────
        Positioned(
          bottom: 12, left: 12,
          child: GestureDetector(
            onTap: () => _ctrl.switchCamera(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.flip_camera_ios,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Scan overlay painter ─────────────────────────────────────
class _ScanOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black45;
    final cutout = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width:  size.width * 0.72,
      height: size.width * 0.72,
    );

    // Dark overlay outside cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(12))),
      ),
      paint,
    );

    // Corner brackets
    final cornerPaint = Paint()
      ..color = AppColors.halalGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const c = 24.0; // corner length
    final l = cutout.left;
    final t = cutout.top;
    final r = cutout.right;
    final b = cutout.bottom;

    // Top-left
    canvas.drawLine(Offset(l, t + c), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + c, t), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(r - c, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + c), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(l, b - c), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + c, b), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(r - c, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b), Offset(r, b - c), cornerPaint);
  }

  @override
  bool shouldRepaint(_ScanOverlay old) => false;
}

// ── Animated scan line ───────────────────────────────────────
class _ScanLineAnimation extends StatefulWidget {
  const _ScanLineAnimation();
  @override
  State<_ScanLineAnimation> createState() => _ScanLineAnimationState();
}

class _ScanLineAnimationState extends State<_ScanLineAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        return CustomPaint(
          painter: _ScanLinePainter(_anim.value),
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutW = size.width * 0.72;
    final cutoutH = cutoutW;
    final left   = (size.width - cutoutW) / 2;
    final top    = (size.height - cutoutH) / 2;
    final y      = top + cutoutH * progress;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.halalGreen.withOpacity(0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(left, y - 1, cutoutW, 2))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(left, y), Offset(left + cutoutW, y), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}
