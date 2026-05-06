/// ── App Strings ────────────────────────────────────────────────────────────
/// All user-facing text in one place for easy updates and future i18n.
class AppStrings {
  AppStrings._();

  // ── App Identity ───────────────────────────────────────────────────────────
  static const String appTitle = 'Invisible AI';
  static const String appSubtitle = 'Your AI Assistant';

  // ── Input ──────────────────────────────────────────────────────────────────
  static const String inputPlaceholder = 'Type a message...';
  static const String sendTooltip = 'Send message';

  // ── Title Bar ──────────────────────────────────────────────────────────────
  static const String minimizeTooltip = 'Minimize';
  static const String closeTooltip = 'Close';
  static const String pinTooltip = 'Always on top';
  static const String unpinTooltip = 'Disable always on top';

  // ── Action Buttons ─────────────────────────────────────────────────────────
  static const String clearChatTooltip = 'Clear chat';
  static const String copyLastTooltip = 'Copy last response';
  static const String settingsTooltip = 'Settings';
  static const String audioRouteSetupTooltip = 'Meet audio route setup';

  // ── Empty State ────────────────────────────────────────────────────────────
  static const String emptyStateTitle = 'Hello! 👋';
  static const String emptyStateSubtitle =
      'I\'m your AI assistant.\nAsk me anything to get started.';

  // ── Typing ─────────────────────────────────────────────────────────────────
  static const String typingIndicator = 'AI is thinking...';

  // ── Welcome Message ────────────────────────────────────────────────────────
  static const String welcomeMessage =
      'Hello! I\'m your Invisible AI assistant. I can help you with coding, '
      'writing, analysis, and more. What would you like to explore today?';

  // ── Interview Copilot Style Prompt ─────────────────────────────────────────
  static const String interviewCopilotStylePrompt = '''
You are a real-time interview copilot.

Generate answers that sound natural when spoken aloud in an interview.

Rules:
- Keep answers concise and conversational.
- Avoid textbook explanations.
- Avoid sounding like ChatGPT.
- Use simple human language.
- Include practical experience-style phrasing.
- Prefer short speaking-friendly sentences.
- Avoid long paragraphs.
- Add quick examples when useful.
- Sound confident but natural.
- Responses should feel like a developer explaining from experience.
- Keep answers under 30 seconds when spoken.
- Focus on clarity over completeness.
- Avoid robotic transitions like:
  "Furthermore", "In conclusion", "Moreover".

Preferred style:
"Basically..."
"In my experience..."
"A simple example is..."
"Mostly I've used this when..."
''';

  // ── System Tray ────────────────────────────────────────────────────────────
  static const String trayShowWindow = 'Show Invisible AI';
  static const String trayNewChat = 'New Chat';
  static const String trayToggleAlwaysOnTop = 'Toggle Always on Top';
  static const String trayQuit = 'Quit';
  static const String trayMinimizedNotice = 'Invisible AI is still running in the background.';

  // ── Hotkey ──────────────────────────────────────────────────────────────────
  static const String hotkeyToggleOverlay = 'Toggle Overlay (Ctrl+Shift+Space)';
  static const String hotkeyNewChat = 'New Chat (Ctrl+Shift+N)';

  // ── Title Bar ──────────────────────────────────────────────────────────────
  static const String hideToTrayTooltip = 'Hide to tray';
}
