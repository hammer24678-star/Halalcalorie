// ============================================================
//  ai_service.dart — HalalCalorie v1.0
//  Anthropic Claude Vision API for:
//  1. Food photo → nutrition analysis + halal check
//  2. Body photo → composition estimate (Premium)
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../data/models/models.dart';

class AIService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: '');
  static const _model    = 'claude-sonnet-4-20250514';
  /// Maps language code → human-readable name for AI prompts
  static String _langName(String code) => const {
    'ar': 'Arabic',
    'en': 'English',
    'fr': 'French',
    'tr': 'Turkish',
    'ur': 'Urdu',
    'ms': 'Malay',
    'id': 'Indonesian',
  }[code] ?? 'English';

  static const _version  = '2023-06-01';

  // ── Convert image file to base64 ──────────────
  static Future<String> _toBase64(String path) async {
    final bytes = await File(path).readAsBytes();
    return base64Encode(bytes);
  }

  static String _mimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':  return 'image/png';
      case 'webp': return 'image/webp';
      case 'gif':  return 'image/gif';
      default:     return 'image/jpeg';
    }
  }

  // ── Core API call ─────────────────────────────
  static Future<String> _callVision({
    required String imagePath,
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 800,
  }) async {
    if (_apiKey.isEmpty) throw Exception('ANTHROPIC_API_KEY not set');
    final b64   = await _toBase64(imagePath);
    final mime  = _mimeType(imagePath);

    final body = jsonEncode({
      'model': _model,
      'max_tokens': maxTokens,
      'system': systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {'type': 'base64', 'media_type': mime, 'data': b64},
            },
            {'type': 'text', 'text': userPrompt},
          ],
        }
      ],
    });

    final resp = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': _version,
        'x-api-key': _apiKey,
      },
      body: body,
    ).timeout(const Duration(seconds: 60));

    if (resp.statusCode != 200) {
      throw Exception('API ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = data['content'];
    if (content is! List || content.isEmpty) return '{}';
    final textBlock = content.firstWhere(
      (c) => c is Map && c['type'] == 'text',
      orElse: () => <String, dynamic>{'text': '{}'},
    );
    // Extract raw text
    final raw = (textBlock is Map ? textBlock['text'] : null)?.toString() ?? '{}';
    // Claude sometimes adds preamble before JSON — extract only the {...} block
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    return match?.group(0) ?? '{}';
  }

  // helper: same extraction for text-only responses
  static String _extractJson(String raw) {
    final m = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    return m?.group(0) ?? '{}';
  }
  }

  // ════════════════════════════════════════════════
  //  FOOD PHOTO ANALYSIS
  // ════════════════════════════════════════════════
  static Future<FoodPhotoResult> analyzeFoodPhoto({
    required String imagePath,
    required String language, // 'ar' | 'en'
  }) async {
    const system = '''You are a professional dietitian and halal food expert.
Analyze food images and return ONLY valid JSON with this exact structure — no markdown, no extra text:
{
  "foodName": "<Arabic name>",
  "foodNameEn": "<English name>",
  "kcal": <integer per serving>,
  "proteinG": <integer grams>,
  "carbsG": <integer grams>,
  "fatG": <integer grams>,
  "halalStatus": "<halal|doubtful|haram|unknown>",
  "halalNote": "<halal explanation in Arabic>",
  "halalNoteEn": "<halal explanation in English>",
  "confidence": <0.0-1.0>,
  "ingredients": ["<main ingredient 1>", "<main ingredient 2>"],
  "portionSize": "<e.g. 1 plate ~300g>",
  "sunnahNote": "<Sunnah/Islamic connection in Arabic, or empty>",
  "sunnahNoteEn": "<Sunnah/Islamic connection in English, or empty>"
}

Rules:
- Calories for visible/estimated portion (not 100g)
- halalStatus: halal=clearly permissible, doubtful=contains uncertain additives, haram=contains pork/alcohol/blood, unknown=cannot determine
- If multiple foods visible, analyze the main dish
- Be conservative with halalStatus — when uncertain, use "doubtful"
- sunnahNote: mention if food is referenced in Sunnah (dates, honey, olive oil, black seed, etc.)''';

    final prompt = language == 'ar'
      ? 'حلل هذا الطعام وأعطني القيم الغذائية والحكم الشرعي.'
      : 'Analyze this food and provide nutritional values and halal assessment.';

    try {
      final raw  = await _callVision(imagePath: imagePath, systemPrompt: system, userPrompt: prompt);
      final clean = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final json  = jsonDecode(clean) as Map<String, dynamic>;
      return FoodPhotoResult(
        foodName:         json['foodName']    as String? ?? 'Unknown',
        foodNameEn:       json['foodNameEn']  as String? ?? 'Unknown',
        kcal:             _safeInt(json['kcal']),
        proteinG:         _safeDouble(json['proteinG']),
        carbsG:           _safeDouble(json['carbsG']),
        fatG:             _safeDouble(json['fatG']),
        halalStatus:      _parseHalalStatus(json['halalStatus'] as String? ?? 'unknown'),
        halalExplanation: json['halalNote']   as String? ?? '',
        halalExplanationEn: json['halalNoteEn'] as String? ?? json['halalNote'] as String? ?? '',
        sunnahNote:       json['sunnahNote']  as String? ?? '',
        sunnahNoteEn:     json['sunnahNoteEn'] as String? ?? '',
        confidence:   _safeDouble(json['confidence'], 0.75),
        portionSize:  json['portionSize'] as String? ?? '',
        ingredients:  (json['ingredients'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
    } on FormatException {
      return _fallbackFoodResult(language);
    }
  }

  static FoodPhotoResult _fallbackFoodResult(String lang) => FoodPhotoResult(
    foodName: lang == 'ar' ? 'وجبة مختلطة' : 'Mixed Meal',
    foodNameEn: 'Mixed Meal',
    kcal: 350, proteinG: 20, carbsG: 40, fatG: 12,
    halalStatus: HalalStatus.unknown,
    halalExplanation: lang == 'ar' ? 'التحليل غير متاح' : 'Analysis unavailable',
    halalExplanationEn: 'Analysis unavailable',
    sunnahNote: '',
    sunnahNoteEn: '',
  );

  // ════════════════════════════════════════════════
  //  BODY PHOTO ANALYSIS (Premium)
  // ════════════════════════════════════════════════
  static Future<BodyPhotoResult> analyzeBodyPhoto({
    required String imagePath,
    required bool isMale,
    required double weightKg,
    required double heightCm,
    required int age,
    required String language,
  }) async {
    final system = '''You are a professional fitness coach and body composition analyst.
Analyze the body image and return ONLY valid JSON with this exact structure:
{
  "estimatedBodyFatPct": <number 5-50>,
  "estimatedMuscleMassKg": <number>,
  "bodyType": "<ectomorph|mesomorph|endomorph>",
  "bodyTypeAr": "<نحيف|متوازن|ضخم>",
  "postureNote": "<brief posture observation in English>",
  "postureNoteAr": "<brief posture observation in Arabic>",
  "recommendations": ["<English rec 1>", "<English rec 2>", "<English rec 3>"],
  "recommendationsAr": ["<Arabic rec 1>", "<Arabic rec 2>", "<Arabic rec 3>"],
  "confidence": <0.0-1.0>
}

IMPORTANT:
- This is an ESTIMATE only — body fat from photos is not clinically accurate
- Use visible muscle definition, fat distribution, and overall physique
- Gender: ${isMale ? 'Male' : 'Female'}, Weight: ${weightKg}kg, Height: ${heightCm}cm, Age: $age
- Recommendations should be practical, Islamic-friendly (no mixed-gender gyms reference)
- Confidence should be lower (0.4-0.65) since photo analysis has inherent limitations
- Focus on achievable, halal fitness goals''';

    final prompt = language == 'ar'
      ? 'قدّر تركيبة الجسم من الصورة. هذا للاستخدام الشخصي فقط.'
      : 'Estimate body composition from this photo. This is for personal use only.';

    try {
      final raw   = await _callVision(imagePath: imagePath, systemPrompt: system, userPrompt: prompt, maxTokens: 1000);
      final clean = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final json  = jsonDecode(clean) as Map<String, dynamic>;
      return BodyPhotoResult(
        bodyFatPercent: (json['estimatedBodyFatPct'] as num?)?.toDouble() ?? 20.0,
        muscleMassKg: (json['estimatedMuscleMassKg'] as num?)?.toDouble() ?? weightKg * 0.4,
        leanBodyMassKg: weightKg * (1 - ((json['estimatedBodyFatPct'] as num?)?.toDouble() ?? 20.0) / 100),
        bodyType: json['bodyTypeAr'] as String? ?? 'متوازن',
        bodyTypeEn: json['bodyType'] as String? ?? 'mesomorph',
        recommendationsAr: List<String>.from(json['recommendationsAr'] ?? []),
        recommendationsEn: List<String>.from(json['recommendations'] ?? []),
        rawAnalysis: '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.55,
      );
    } catch (e) {
      return _fallbackBodyResult(isMale, weightKg, language);
    }
  }

  static BodyPhotoResult _fallbackBodyResult(bool isMale, double weightKg, String lang) {
    final bf = isMale ? 18.0 : 28.0;
    return BodyPhotoResult(
      bodyFatPercent: bf,
      muscleMassKg: weightKg * (1 - bf / 100) * 0.85,
      leanBodyMassKg: weightKg * (1 - bf / 100),
      bodyType: lang == 'ar' ? 'متوازن' : 'mesomorph',
      bodyTypeEn: 'mesomorph',
      recommendationsAr: ['زِد البروتين اليومي', 'امشِ ٣٠ دقيقة يومياً', 'نم ٨ ساعات'],
      recommendationsEn: ['Increase protein intake', 'Walk 30 min daily', 'Sleep 8 hours'],
      rawAnalysis: '',
      confidence: 0.55,
    );
  }

  // ════════════════════════════════════════════════
  //  QUICK TEXT-ONLY MEAL SUGGESTION (no image)
  // ════════════════════════════════════════════════
  static Future<String> getMealSuggestion({
    required String prompt,
    required int calorieGoal,
    required String dietType,
    required String goal,
    required String language,
  }) async {
    final system = '''You are a halal dietitian. Respond in ${_langName(language)}.
Provide meal suggestions that are 100% halal, practical, and aligned with Islamic dietary guidelines.
Mention Sunnah foods (dates, honey, olive oil, black seed) when relevant.
Keep response concise and structured.''';

    final userMsg = '''
Calorie goal: $calorieGoal kcal/day
Diet type: $dietType
Goal: $goal
Request: $prompt
''';

    if (_apiKey.isEmpty) {
      return language == 'ar'
        ? 'لم يتم إعداد مفتاح API. راجع إعدادات Codemagic.'
        : 'API key not configured. Check Codemagic secrets.';
    }
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 600,
      'system': system,
      'messages': [
        {'role': 'user', 'content': userMsg},
      ],
    });

    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json', 'anthropic-version': _version, 'x-api-key': _apiKey},
        body: body,
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final content = data['content'];
        if (content is! List || content.isEmpty) return '';
        final block = content.firstWhere(
          (c) => c is Map && c['type'] == 'text',
          orElse: () => <String, dynamic>{'text': ''},
        );
        return (block is Map ? block['text'] : null)?.toString() ?? '';
      }
      throw Exception('${resp.statusCode}');
    } catch (_) {
      return language == 'ar'
        ? 'عذراً، حدث خطأ في الاتصال. تأكد من اتصالك بالإنترنت وحاول مرة أخرى.'
        : 'Sorry, connection error. Please check your internet and try again.';
    }
  }
  // ════════════════════════════════════════════════
  //  FOOD NUTRITION LOOKUP
  // ════════════════════════════════════════════════
  
  // ── Local food database (works without internet) ────────
  static Map<String, dynamic>? _localLookup(String name) {
    final n = name.toLowerCase().trim();
    // Map common foods to real values
    const foods = {
      'honey': {'name_ar': 'عسل', 'name_en': 'Honey', 'kcal': 304, 'protein_g': 0.3, 'carbs_g': 82.0, 'fat_g': 0.0, 'halal': true},
      'عسل': {'name_ar': 'عسل', 'name_en': 'Honey', 'kcal': 304, 'protein_g': 0.3, 'carbs_g': 82.0, 'fat_g': 0.0, 'halal': true},
      'date': {'name_ar': 'تمر', 'name_en': 'Dates', 'kcal': 277, 'protein_g': 1.8, 'carbs_g': 75.0, 'fat_g': 0.2, 'halal': true},
      'dates': {'name_ar': 'تمر', 'name_en': 'Dates', 'kcal': 277, 'protein_g': 1.8, 'carbs_g': 75.0, 'fat_g': 0.2, 'halal': true},
      'تمر': {'name_ar': 'تمر', 'name_en': 'Dates', 'kcal': 277, 'protein_g': 1.8, 'carbs_g': 75.0, 'fat_g': 0.2, 'halal': true},
      'chicken': {'name_ar': 'دجاج مشوي', 'name_en': 'Grilled Chicken', 'kcal': 165, 'protein_g': 31.0, 'carbs_g': 0.0, 'fat_g': 4.0, 'halal': true},
      'دجاج': {'name_ar': 'دجاج مشوي', 'name_en': 'Grilled Chicken', 'kcal': 165, 'protein_g': 31.0, 'carbs_g': 0.0, 'fat_g': 4.0, 'halal': true},
      'egg': {'name_ar': 'بيضة', 'name_en': 'Egg', 'kcal': 78, 'protein_g': 6.0, 'carbs_g': 1.0, 'fat_g': 5.0, 'halal': true},
      'eggs': {'name_ar': 'بيضة', 'name_en': 'Egg', 'kcal': 78, 'protein_g': 6.0, 'carbs_g': 1.0, 'fat_g': 5.0, 'halal': true},
      'بيض': {'name_ar': 'بيضة', 'name_en': 'Egg', 'kcal': 78, 'protein_g': 6.0, 'carbs_g': 1.0, 'fat_g': 5.0, 'halal': true},
      'rice': {'name_ar': 'أرز أبيض', 'name_en': 'White Rice', 'kcal': 206, 'protein_g': 4.0, 'carbs_g': 45.0, 'fat_g': 0.4, 'halal': true},
      'أرز': {'name_ar': 'أرز أبيض', 'name_en': 'White Rice', 'kcal': 206, 'protein_g': 4.0, 'carbs_g': 45.0, 'fat_g': 0.4, 'halal': true},
      'milk': {'name_ar': 'حليب', 'name_en': 'Milk', 'kcal': 130, 'protein_g': 7.0, 'carbs_g': 10.0, 'fat_g': 7.0, 'halal': true},
      'حليب': {'name_ar': 'حليب', 'name_en': 'Milk', 'kcal': 130, 'protein_g': 7.0, 'carbs_g': 10.0, 'fat_g': 7.0, 'halal': true},
      'banana': {'name_ar': 'موز', 'name_en': 'Banana', 'kcal': 105, 'protein_g': 1.0, 'carbs_g': 27.0, 'fat_g': 0.3, 'halal': true},
      'موز': {'name_ar': 'موز', 'name_en': 'Banana', 'kcal': 105, 'protein_g': 1.0, 'carbs_g': 27.0, 'fat_g': 0.3, 'halal': true},
      'apple': {'name_ar': 'تفاحة', 'name_en': 'Apple', 'kcal': 95, 'protein_g': 0.5, 'carbs_g': 25.0, 'fat_g': 0.3, 'halal': true},
      'تفاح': {'name_ar': 'تفاحة', 'name_en': 'Apple', 'kcal': 95, 'protein_g': 0.5, 'carbs_g': 25.0, 'fat_g': 0.3, 'halal': true},
      'olive oil': {'name_ar': 'زيت زيتون', 'name_en': 'Olive Oil', 'kcal': 119, 'protein_g': 0.0, 'carbs_g': 0.0, 'fat_g': 14.0, 'halal': true},
      'زيت زيتون': {'name_ar': 'زيت زيتون', 'name_en': 'Olive Oil', 'kcal': 119, 'protein_g': 0.0, 'carbs_g': 0.0, 'fat_g': 14.0, 'halal': true},
      'bread': {'name_ar': 'خبز', 'name_en': 'Bread', 'kcal': 265, 'protein_g': 9.0, 'carbs_g': 49.0, 'fat_g': 3.0, 'halal': true},
      'خبز': {'name_ar': 'خبز', 'name_en': 'Bread', 'kcal': 265, 'protein_g': 9.0, 'carbs_g': 49.0, 'fat_g': 3.0, 'halal': true},
      'tuna': {'name_ar': 'تونة', 'name_en': 'Tuna', 'kcal': 116, 'protein_g': 26.0, 'carbs_g': 0.0, 'fat_g': 1.0, 'halal': true},
      'تونة': {'name_ar': 'تونة', 'name_en': 'Tuna', 'kcal': 116, 'protein_g': 26.0, 'carbs_g': 0.0, 'fat_g': 1.0, 'halal': true},
      'oats': {'name_ar': 'شوفان', 'name_en': 'Oats', 'kcal': 166, 'protein_g': 6.0, 'carbs_g': 28.0, 'fat_g': 4.0, 'halal': true},
      'شوفان': {'name_ar': 'شوفان', 'name_en': 'Oats', 'kcal': 166, 'protein_g': 6.0, 'carbs_g': 28.0, 'fat_g': 4.0, 'halal': true},
      'yogurt': {'name_ar': 'زبادي', 'name_en': 'Yogurt', 'kcal': 150, 'protein_g': 8.0, 'carbs_g': 11.0, 'fat_g': 8.0, 'halal': true},
      'زبادي': {'name_ar': 'زبادي', 'name_en': 'Yogurt', 'kcal': 150, 'protein_g': 8.0, 'carbs_g': 11.0, 'fat_g': 8.0, 'halal': true},
      'lentils': {'name_ar': 'عدس', 'name_en': 'Lentils', 'kcal': 230, 'protein_g': 18.0, 'carbs_g': 40.0, 'fat_g': 1.0, 'halal': true},
      'عدس': {'name_ar': 'عدس', 'name_en': 'Lentils', 'kcal': 230, 'protein_g': 18.0, 'carbs_g': 40.0, 'fat_g': 1.0, 'halal': true},
      'beef': {'name_ar': 'لحم بقر', 'name_en': 'Beef', 'kcal': 215, 'protein_g': 26.0, 'carbs_g': 0.0, 'fat_g': 12.0, 'halal': true},
      'لحم': {'name_ar': 'لحم بقر', 'name_en': 'Beef', 'kcal': 215, 'protein_g': 26.0, 'carbs_g': 0.0, 'fat_g': 12.0, 'halal': true},
      'pork': {'name_ar': 'لحم خنزير', 'name_en': 'Pork', 'kcal': 242, 'protein_g': 27.0, 'carbs_g': 0.0, 'fat_g': 14.0, 'halal': false},
      'خنزير': {'name_ar': 'لحم خنزير', 'name_en': 'Pork', 'kcal': 242, 'protein_g': 27.0, 'carbs_g': 0.0, 'fat_g': 14.0, 'halal': false},
    };
    // Extended local database — works offline instantly
    const extraFoods = {
      'كشري': {'name_ar': 'كشري', 'name_en': 'Koshari', 'kcal': 430, 'protein_g': 15.0, 'carbs_g': 85.0, 'fat_g': 5.0, 'halal': true},
      'koshari': {'name_ar': 'كشري', 'name_en': 'Koshari', 'kcal': 430, 'protein_g': 15.0, 'carbs_g': 85.0, 'fat_g': 5.0, 'halal': true},
      'falafel': {'name_ar': 'فلافل', 'name_en': 'Falafel', 'kcal': 180, 'protein_g': 7.0, 'carbs_g': 18.0, 'fat_g': 9.0, 'halal': true},
      'فلافل': {'name_ar': 'فلافل', 'name_en': 'Falafel', 'kcal': 180, 'protein_g': 7.0, 'carbs_g': 18.0, 'fat_g': 9.0, 'halal': true},
      'hummus': {'name_ar': 'حمص', 'name_en': 'Hummus', 'kcal': 166, 'protein_g': 8.0, 'carbs_g': 14.0, 'fat_g': 10.0, 'halal': true},
      'حمص': {'name_ar': 'حمص', 'name_en': 'Hummus', 'kcal': 166, 'protein_g': 8.0, 'carbs_g': 14.0, 'fat_g': 10.0, 'halal': true},
      'shawarma': {'name_ar': 'شاورما دجاج', 'name_en': 'Chicken Shawarma', 'kcal': 440, 'protein_g': 30.0, 'carbs_g': 45.0, 'fat_g': 14.0, 'halal': true},
      'شاورما': {'name_ar': 'شاورما دجاج', 'name_en': 'Chicken Shawarma', 'kcal': 440, 'protein_g': 30.0, 'carbs_g': 45.0, 'fat_g': 14.0, 'halal': true},
      'kabsa': {'name_ar': 'كبسة', 'name_en': 'Kabsa', 'kcal': 580, 'protein_g': 38.0, 'carbs_g': 68.0, 'fat_g': 16.0, 'halal': true},
      'كبسة': {'name_ar': 'كبسة', 'name_en': 'Kabsa', 'kcal': 580, 'protein_g': 38.0, 'carbs_g': 68.0, 'fat_g': 16.0, 'halal': true},
      'lamb': {'name_ar': 'لحم غنم', 'name_en': 'Lamb', 'kcal': 258, 'protein_g': 25.0, 'carbs_g': 0.0, 'fat_g': 17.0, 'halal': true},
      'لحم غنم': {'name_ar': 'لحم غنم', 'name_en': 'Lamb', 'kcal': 258, 'protein_g': 25.0, 'carbs_g': 0.0, 'fat_g': 17.0, 'halal': true},
      'shrimp': {'name_ar': 'جمبري', 'name_en': 'Shrimp', 'kcal': 99, 'protein_g': 24.0, 'carbs_g': 0.0, 'fat_g': 1.0, 'halal': true},
      'جمبري': {'name_ar': 'جمبري', 'name_en': 'Shrimp', 'kcal': 99, 'protein_g': 24.0, 'carbs_g': 0.0, 'fat_g': 1.0, 'halal': true},
      'labneh': {'name_ar': 'لبنة', 'name_en': 'Labneh', 'kcal': 150, 'protein_g': 10.0, 'carbs_g': 6.0, 'fat_g': 10.0, 'halal': true},
      'لبنة': {'name_ar': 'لبنة', 'name_en': 'Labneh', 'kcal': 150, 'protein_g': 10.0, 'carbs_g': 6.0, 'fat_g': 10.0, 'halal': true},
      'pomegranate': {'name_ar': 'رمان', 'name_en': 'Pomegranate', 'kcal': 83, 'protein_g': 1.7, 'carbs_g': 19.0, 'fat_g': 1.2, 'halal': true},
      'رمان': {'name_ar': 'رمان', 'name_en': 'Pomegranate', 'kcal': 83, 'protein_g': 1.7, 'carbs_g': 19.0, 'fat_g': 1.2, 'halal': true},
      'fig': {'name_ar': 'تين', 'name_en': 'Fig', 'kcal': 74, 'protein_g': 1.0, 'carbs_g': 19.0, 'fat_g': 0.3, 'halal': true},
      'تين': {'name_ar': 'تين', 'name_en': 'Fig', 'kcal': 74, 'protein_g': 1.0, 'carbs_g': 19.0, 'fat_g': 0.3, 'halal': true},
      'strawberry': {'name_ar': 'فراولة', 'name_en': 'Strawberry', 'kcal': 32, 'protein_g': 0.7, 'carbs_g': 8.0, 'fat_g': 0.3, 'halal': true},
      'فراولة': {'name_ar': 'فراولة', 'name_en': 'Strawberry', 'kcal': 32, 'protein_g': 0.7, 'carbs_g': 8.0, 'fat_g': 0.3, 'halal': true},
      'green tea': {'name_ar': 'شاي أخضر', 'name_en': 'Green Tea', 'kcal': 2, 'protein_g': 0.0, 'carbs_g': 0.0, 'fat_g': 0.0, 'halal': true},
      'شاي أخضر': {'name_ar': 'شاي أخضر', 'name_en': 'Green Tea', 'kcal': 2, 'protein_g': 0.0, 'carbs_g': 0.0, 'fat_g': 0.0, 'halal': true},
      'coffee': {'name_ar': 'قهوة', 'name_en': 'Coffee', 'kcal': 2, 'protein_g': 0.0, 'carbs_g': 0.0, 'fat_g': 0.0, 'halal': true},
      'قهوة': {'name_ar': 'قهوة', 'name_en': 'Coffee', 'kcal': 2, 'protein_g': 0.0, 'carbs_g': 0.0, 'fat_g': 0.0, 'halal': true},

      // Gulf & Saudi
       'مندي': {'name_ar': 'مندي', 'name_en': 'Mandi', 'kcal': 620, 'protein_g': 42.0, 'carbs_g': 65.0, 'fat_g': 18.0, 'halal': true},
      'saleeg': {'name_ar': 'سليق', 'name_en': 'Saleeg', 'kcal': 520, 'protein_g': 30.0, 'carbs_g': 62.0, 'fat_g': 14.0, 'halal': true},
      'قهوة عربية': {'name_ar': 'قهوة عربية', 'name_en': 'Arabic Coffee', 'kcal': 5, 'protein_g': 0.0, 'carbs_g': 1.0, 'fat_g': 0.0, 'halal': true},
      'arabic coffee': {'name_ar': 'قهوة عربية', 'name_en': 'Arabic Coffee', 'kcal': 5, 'protein_g': 0.0, 'carbs_g': 1.0, 'fat_g': 0.0, 'halal': true},
      // Western
      'pizza': {'name_ar': 'بيتزا', 'name_en': 'Pizza slice', 'kcal': 272, 'protein_g': 12.0, 'carbs_g': 34.0, 'fat_g': 10.0, 'halal': true},
      'بيتزا': {'name_ar': 'بيتزا', 'name_en': 'Pizza', 'kcal': 272, 'protein_g': 12.0, 'carbs_g': 34.0, 'fat_g': 10.0, 'halal': true},
      'burger': {'name_ar': 'برجر', 'name_en': 'Burger', 'kcal': 490, 'protein_g': 30.0, 'carbs_g': 44.0, 'fat_g': 20.0, 'halal': true},
      'برجر': {'name_ar': 'برجر', 'name_en': 'Burger', 'kcal': 490, 'protein_g': 30.0, 'carbs_g': 44.0, 'fat_g': 20.0, 'halal': true},
      'pasta': {'name_ar': 'باستا', 'name_en': 'Pasta', 'kcal': 350, 'protein_g': 14.0, 'carbs_g': 58.0, 'fat_g': 8.0, 'halal': true},
      'باستا': {'name_ar': 'باستا', 'name_en': 'Pasta', 'kcal': 350, 'protein_g': 14.0, 'carbs_g': 58.0, 'fat_g': 8.0, 'halal': true},
      'salmon': {'name_ar': 'سالمون', 'name_en': 'Salmon', 'kcal': 280, 'protein_g': 34.0, 'carbs_g': 0.0, 'fat_g': 16.0, 'halal': true},
      'سالمون': {'name_ar': 'سالمون', 'name_en': 'Salmon', 'kcal': 280, 'protein_g': 34.0, 'carbs_g': 0.0, 'fat_g': 16.0, 'halal': true},
      'nutella': {'name_ar': 'نوتيلا', 'name_en': 'Nutella (2 tbsp)', 'kcal': 200, 'protein_g': 2.0, 'carbs_g': 23.0, 'fat_g': 11.0, 'halal': true},
      'نوتيلا': {'name_ar': 'نوتيلا', 'name_en': 'Nutella', 'kcal': 200, 'protein_g': 2.0, 'carbs_g': 23.0, 'fat_g': 11.0, 'halal': true},
      'whey protein': {'name_ar': 'بروتين واي', 'name_en': 'Whey protein', 'kcal': 120, 'protein_g': 25.0, 'carbs_g': 3.0, 'fat_g': 2.0, 'halal': true},
      'protein': {'name_ar': 'بروتين واي', 'name_en': 'Whey protein', 'kcal': 120, 'protein_g': 25.0, 'carbs_g': 3.0, 'fat_g': 2.0, 'halal': true},
      'latte': {'name_ar': 'لاتيه', 'name_en': 'Latte', 'kcal': 190, 'protein_g': 7.0, 'carbs_g': 18.0, 'fat_g': 7.0, 'halal': true},
      'cappuccino': {'name_ar': 'كابوتشينو', 'name_en': 'Cappuccino', 'kcal': 120, 'protein_g': 5.0, 'carbs_g': 10.0, 'fat_g': 5.0, 'halal': true},
      'smoothie': {'name_ar': 'سموذي', 'name_en': 'Smoothie', 'kcal': 200, 'protein_g': 4.0, 'carbs_g': 45.0, 'fat_g': 1.0, 'halal': true},
      'dark chocolate': {'name_ar': 'شوكولاتة داكنة', 'name_en': 'Dark chocolate', 'kcal': 170, 'protein_g': 2.0, 'carbs_g': 13.0, 'fat_g': 12.0, 'halal': true},
      'شوكولاتة': {'name_ar': 'شوكولاتة داكنة', 'name_en': 'Dark chocolate', 'kcal': 170, 'protein_g': 2.0, 'carbs_g': 13.0, 'fat_g': 12.0, 'halal': true},
    };
    // Check extra foods first
    if (extraFoods.containsKey(n)) return Map<String, dynamic>.from(extraFoods[n]!);
    for (final key in extraFoods.keys) {
      if (n.contains(key) || key.contains(n)) {
        return Map<String, dynamic>.from(extraFoods[key]!);
      }
    }
    // Check exact match first
    if (foods.containsKey(n)) return Map<String, dynamic>.from(foods[n]!);
    // Check partial match
    for (final key in foods.keys) {
      if (n.contains(key) || key.contains(n)) {
        return Map<String, dynamic>.from(foods[key]!);
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> lookupFood(String foodName, {String language = 'ar', bool isPremium = false}) async {
    final isAr = language == 'ar';
    // Check local database first (works offline, instant)
    final local = _localLookup(foodName);
    if (local != null) {
      local['serving_size'] = '100g';
      return local;
    }
    final jsonFmt = isPremium 
        ? '{"name_ar":"...","name_en":"...","kcal":0,"protein_g":0.0,"carbs_g":0.0,"fat_g":0.0,"vitamin_c_mg":0.0,"iron_mg":0.0,"calcium_mg":0.0,"potassium_mg":0.0,"serving_size":"100g","halal":true}'
        : '{"name_ar":"...","name_en":"...","kcal":0,"protein_g":0.0,"carbs_g":0.0,"fat_g":0.0,"serving_size":"100g","halal":true}';

    final system = 'You are a nutrition database expert. When given a food name, return ONLY a JSON object with exact nutritional values per 100g serving. Return ONLY valid JSON, no other text. Required format: ' + jsonFmt;

    final prompt = isAr
        ? 'القيم الغذائية لـ: $foodName'
        : 'Nutritional values for: $foodName';

    if (_apiKey.isEmpty) {
      return {'name_ar': foodName, 'name_en': foodName,
        'kcal': 100, 'protein_g': 5.0, 'carbs_g': 15.0,
        'fat_g': 3.0, 'serving_size': '100g', 'halal': true};
    }
    try {
      final body = jsonEncode({
        'model': _model,
        'max_tokens': 400,
        'system': system,
        'messages': [{'role': 'user', 'content': prompt}],
      });

      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json', 'anthropic-version': _version, 'x-api-key': _apiKey},
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final content = data['content'];
        if (content is! List || content.isEmpty) throw Exception('empty');
        final block = content.firstWhere(
          (c) => c is Map && c['type'] == 'text',
          orElse: () => <String, dynamic>{'text': '{}'},
        );
        final text = (block is Map ? block['text'] : null)?.toString() ?? '{}';
        final clean = _extractJson(text);
        return jsonDecode(clean) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'name_ar': foodName, 'name_en': foodName,
      'kcal': 100, 'protein_g': 5.0, 'carbs_g': 15.0,
      'fat_g': 3.0, 'serving_size': '100g', 'halal': true,
    };
  }

  // ── Safe type conversion (prevents runtime cast errors) ──

  static HalalStatus _parseHalalStatus(String s) {
    switch (s.toLowerCase()) {
      case 'halal':    return HalalStatus.halal;
      case 'haram':    return HalalStatus.haram;
      case 'doubtful': return HalalStatus.doubtful;
      default:         return HalalStatus.unknown;
    }
  }

  static double _safeDouble(dynamic v, [double fb = 0.0]) {
    if (v == null) return fb;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? fb;
  }

  static int _safeInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? fb;
  }


}
