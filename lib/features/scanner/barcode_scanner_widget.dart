import 'package:flutter/material.dart';
import '../../core/theme.dart';

class BarcodeScannerWidget extends StatefulWidget {
  final bool isActive;
  final void Function(String) onDetected;
  const BarcodeScannerWidget({super.key, required this.isActive, required this.onDetected});
  @override State<BarcodeScannerWidget> createState() => _State();
}
class _State extends State<BarcodeScannerWidget> {
  final _ctrl = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();
    return Container(
      color: Colors.black,
      child: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.qr_code_scanner, color: Colors.white, size: 80),
          const SizedBox(height: 24),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter barcode manually',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.sunnahGreen)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () { if (_ctrl.text.isNotEmpty) widget.onDetected(_ctrl.text.trim()); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sunnahGreen),
            child: const Text('Search'),
          )),
        ]),
      )),
    );
  }
}
