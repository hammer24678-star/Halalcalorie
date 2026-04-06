// body_photo_screen.dart — stub (image_picker restored in v2)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/ai_service.dart';

class BodyPhotoScreen extends ConsumerStatefulWidget {
  const BodyPhotoScreen({super.key});
  @override ConsumerState<BodyPhotoScreen> createState() => _BodyPhotoState();
}

class _BodyPhotoState extends ConsumerState<BodyPhotoScreen> {
  bool _loading = false;
  String? _result;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar';
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: AppColors.sunnahGreen,
        title: Text(isAr ? 'تحليل الجسم' : 'Body Analysis',
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.camera_alt, size: 80, color: AppColors.sunnahGreen),
            const SizedBox(height: 24),
            Text(
              isAr ? 'تحليل صورة الجسم سيتوفر في الإصدار القادم'
                   : 'Body photo analysis coming in next version',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo', fontSize: 16,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.sunnahGreen),
              child: Text(isAr ? 'رجوع' : 'Back',
                  style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ]),
        ),
      ),
    );
  }
}
