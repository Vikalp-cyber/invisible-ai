import 'dart:math';

/// ── Mock AI Service ────────────────────────────────────────────────────────
/// Simulates AI responses with realistic delays. Easy to replace with a real
/// API integration (OpenAI, Gemini, local Ollama) by implementing the same
/// interface.
class MockAIService {
  final _random = Random();

  // ── Response Pool ──────────────────────────────────────────────────────────
  // Contextual responses based on keywords in the user's message.
  static const Map<String, List<String>> _contextualResponses = {
    'hello': [
      'Hey there! 👋 Great to see you. What can I help you with today?',
      'Hello! I\'m ready to assist. What\'s on your mind?',
      'Hi! Welcome back. How can I make your day easier?',
    ],
    'help': [
      'I can help with a wide range of tasks:\n\n'
          '• 💻 **Coding** — Write, debug, and explain code\n'
          '• ✍️ **Writing** — Draft emails, docs, and content\n'
          '• 📊 **Analysis** — Break down data and problems\n'
          '• 🧠 **Brainstorming** — Generate ideas and solutions\n'
          '• 📚 **Learning** — Explain concepts in simple terms\n\n'
          'What would you like to explore?',
    ],
    'code': [
      'I\'d be happy to help with code! Here\'s a quick example:\n\n'
          '```dart\n'
          'Future<String> fetchData() async {\n'
          '  final response = await http.get(url);\n'
          '  return response.body;\n'
          '}\n'
          '```\n\n'
          'What language or framework are you working with?',
      'Sure! What programming language are you using? I can help with:\n'
          '• Dart/Flutter\n'
          '• Python\n'
          '• JavaScript/TypeScript\n'
          '• And many more!',
    ],
    'flutter': [
      'Flutter is a great choice! 🎯 Here are some tips:\n\n'
          '1. Use `const` constructors to improve rebuild performance\n'
          '2. Keep widget trees shallow — extract into separate widgets\n'
          '3. Use Riverpod or Bloc for clean state management\n'
          '4. Leverage `flutter_animate` for smooth micro-animations\n\n'
          'What specific Flutter topic can I help with?',
    ],
    'thanks': [
      'You\'re welcome! 😊 Let me know if there\'s anything else I can help with.',
      'Happy to help! Don\'t hesitate to ask if you need more assistance.',
      'Glad I could help! I\'m here whenever you need me. 👍',
    ],
  };

  // ── Generic Fallback Responses ─────────────────────────────────────────────
  static const List<String> _genericResponses = [
    'That\'s a great question! Let me think about it...\n\n'
        'Based on my analysis, here are some key points to consider:\n\n'
        '1. **Context matters** — The best approach depends on your specific use case\n'
        '2. **Start simple** — Begin with the straightforward solution, then optimize\n'
        '3. **Test iteratively** — Validate each step before moving forward\n\n'
        'Would you like me to dive deeper into any of these?',
    'Interesting! Here\'s my take on that:\n\n'
        'The most effective approach would be to break this down into smaller, '
        'manageable steps. This makes it easier to debug and iterate.\n\n'
        'Shall I outline a step-by-step plan?',
    'I\'ve analyzed your request and here\'s what I suggest:\n\n'
        '🔍 **First**, let\'s understand the core requirement\n'
        '🛠️ **Then**, we\'ll build the solution piece by piece\n'
        '✅ **Finally**, we\'ll verify everything works correctly\n\n'
        'What aspect would you like to start with?',
    'Great topic! There are several ways to approach this:\n\n'
        '• **Option A**: Quick and straightforward — good for prototyping\n'
        '• **Option B**: More structured — better for production\n'
        '• **Option C**: Comprehensive — covers edge cases\n\n'
        'Which approach interests you?',
    'I understand what you\'re looking for. Let me provide a thorough response:\n\n'
        'The key insight here is that simplicity often leads to the best results. '
        'Complex solutions can introduce unnecessary maintenance burden.\n\n'
        'Would you like me to elaborate on any specific part?',
  ];

  /// ── Generate Response ─────────────────────────────────────────────────────
  /// Returns a simulated AI response based on the user's message.
  /// Matches keywords for contextual responses, falls back to generic ones.
  Future<String> generateResponse(String userMessage) async {
    // Simulate AI thinking time (800ms–2000ms).
    final delay = Duration(
      milliseconds: 800 + _random.nextInt(1200),
    );
    await Future.delayed(delay);

    final messageLower = userMessage.toLowerCase().trim();

    // Try to find a contextual response based on keywords.
    for (final entry in _contextualResponses.entries) {
      if (messageLower.contains(entry.key)) {
        final responses = entry.value;
        return responses[_random.nextInt(responses.length)];
      }
    }

    // Fall back to a generic response.
    return _genericResponses[_random.nextInt(_genericResponses.length)];
  }
}
