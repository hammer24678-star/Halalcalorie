// ai_config.dart — HalalCalorie v61 (PATCH_V61_AI)
// One place for the AI provider. Everything is a build-time --dart-define, so
// switching provider or model never needs a code change:
//   --dart-define=GEMINI_API_KEY=...        (free key from aistudio.google.com)
//   --dart-define=AI_ENDPOINT=...           any OpenAI-compatible chat/completions URL
//   --dart-define=AI_TEXT_MODEL=...         default gemini-flash-latest
//   --dart-define=AI_VISION_MODEL=...       default gemini-flash-latest
//   --dart-define=AI_REASONING=...          low | none | minimal | '' (omit the field)
class AiConfig {
  static const String _gemini = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _generic = String.fromEnvironment('AI_API_KEY', defaultValue: '');
  static const String apiKey = _gemini != '' ? _gemini : _generic;

  static const String endpoint = String.fromEnvironment('AI_ENDPOINT',
      defaultValue: 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions');
  static const String textModel =
      String.fromEnvironment('AI_TEXT_MODEL', defaultValue: 'gemini-flash-latest');
  static const String visionModel =
      String.fromEnvironment('AI_VISION_MODEL', defaultValue: 'gemini-flash-latest');
  static const String reasoning = String.fromEnvironment('AI_REASONING', defaultValue: 'low');

  /// Gemini counts internal reasoning against max_tokens, so leave headroom.
  static int cap(int n) => n + 1024;
}
