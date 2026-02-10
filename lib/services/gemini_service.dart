/// Service to interact with Google Gemini AI
library;

import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_keys.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: ApiKeys.geminiApiKey,
    );
  }

  /// Send a message to Gemini with optional images and user context
  Future<String> sendMessage({
    required String prompt,
    List<File>? images,
    Map<String, dynamic>? userContext,
    bool isDetailed = false,
  }) async {
    try {
      // Build system prompt with user context and response style
      final systemPrompt = _buildSystemPrompt(userContext, isDetailed);
      final fullPrompt = '$systemPrompt\n\nUser: $prompt';

      // Prepare content
      final content = <Content>[];

      if (images != null && images.isNotEmpty) {
        // Multi-modal request with images
        final parts = <Part>[TextPart(fullPrompt)];

        for (final image in images) {
          final bytes = await image.readAsBytes();
          parts.add(DataPart('image/jpeg', bytes));
        }

        content.add(Content.multi(parts));
      } else {
        // Text-only request
        content.add(Content.text(fullPrompt));
      }

      final response = await _model.generateContent(content);
      return response.text ?? 'Sorry, I could not generate a response.';
    } on GenerativeAIException catch (e) {
      print('❌ Gemini API Error: ${e.message}');
      if (e.message.contains('API_KEY_INVALID') ||
          e.message.contains('API key')) {
        return '⚠️ Invalid API key. Please check your Gemini API key.';
      }
      if (e.message.contains('quota') || e.message.contains('limit')) {
        return '⚠️ API quota exceeded. Please try again later.';
      }
      return '⚠️ API Error: ${e.message}';
    } catch (e) {
      print('❌ Unexpected Error: $e');
      return '⚠️ Error: $e';
    }
  }

  /// Build system prompt with user context and response style
  String _buildSystemPrompt(Map<String, dynamic>? context, bool isDetailed) {
    final responseStyle = isDetailed
        ? '''Response Style: DETAILED (but not overwhelming)
- Provide helpful context and brief explanations
- Include 1-2 relevant reasons behind recommendations
- Keep responses to 5-8 sentences maximum
- Use simple bullet points when listing multiple items
- Be informative but avoid lengthy paragraphs'''
        : '''Response Style: CONCISE
- Give brief, to-the-point answers
- Focus on actionable advice only
- Keep explanations minimal
- Maximum 3-4 sentences per response
- Get straight to the point''';

    if (context == null) {
      return '''You are a friendly and knowledgeable fitness assistant. Provide helpful, evidence-based fitness and nutrition advice. Be encouraging and supportive.

$responseStyle

Important: Always add this disclaimer at the end of health advice: "Note: This is general guidance, not medical advice. Consult a healthcare professional for personalized recommendations."''';
    }

    final age = context['age'] ?? 'unknown';
    final gender = context['gender'] ?? 'unknown';
    final weight = context['weight'] ?? 'unknown';
    final height = context['height'] ?? 'unknown';
    final bmi = context['bmi'] ?? 'unknown';
    final goal = context['goal'] ?? 'unknown';
    final steps = context['steps'] ?? 'unknown';
    final activityLevel = context['activityLevel'] ?? 'unknown';

    return '''You are a friendly and knowledgeable fitness assistant helping a specific user. Provide helpful, evidence-based fitness and nutrition advice tailored to their profile.

User Profile:
- Age: $age, Gender: $gender
- Weight: $weight kg, Height: $height cm, BMI: $bmi
- Daily step goal: $goal, Today's steps: $steps
- Activity level: $activityLevel

$responseStyle

Guidelines:
- Be encouraging and supportive
- Provide specific, actionable advice
- Reference the user's data when relevant (e.g., "Based on your BMI of $bmi...")
- For food images, estimate calories and macros
- Be conversational and friendly

Important: Always add this disclaimer at the end of health advice: "Note: This is general guidance, not medical advice. Consult a healthcare professional for personalized recommendations."''';
  }
}
