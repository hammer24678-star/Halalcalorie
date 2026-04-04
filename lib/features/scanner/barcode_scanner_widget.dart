// barcode_scanner_widget.dart — stub (mobile_scanner removed for stability)
// Real camera scanner restored in v2
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class BarcodeScannerWidget extends StatelessWidget {
  final bool isActive;
  final void Function(String barcode) onDetected;

  const BarcodeScannerWidget({
    super.key,
    required this.isActive,
    required this.onDetected,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, color: Colors.white, size: 80),
            const SizedBox(height: 16),
            const Text('Camera scanner coming in v2',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 24),
            // Manual barcode entry
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _ManualEntry(onDetected: onDetected),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualEntry extends StatefulWidget {
  final void Function(String) onDetected;
  const _ManualEntry({required this.onDetected});

  @override
  State<_ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends State<_ManualEntry> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter barcode manually',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white30)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.sunnahGreen)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: () {
          if (_ctrl.text.isNotEmpty) widget.onDetected(_ctrl.text.trim());
        },
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.sunnahGreen),
        child: const Text('Scan'),
      ),
    ]);
  }
}
