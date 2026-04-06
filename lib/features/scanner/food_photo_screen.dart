// food_photo_screen.dart — stub (image_picker restored in v2)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';

class FoodPhotoScreen extends ConsumerWidget {
  const FoodPhotoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar';
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: AppColors.sunnahGreen,
        title: Text(isAr ? 'تحليل طعام بـ AI' : 'AI Food Analysis',
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
            const Icon(Icons.photo_camera, size: 80, color: AppColors.sunnahGreen),
            const SizedBox(height: 24),
            Text(
              isAr ? 'تحليل صورة الطعام سيتوفر في الإصدار القادم'
                   : 'Food photo analysis coming in next version',
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
