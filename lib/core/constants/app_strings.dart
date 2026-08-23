/// ── App Strings ────────────────────────────────────────────────────────────
/// All user-facing text in one place for easy updates and future i18n.
class AppStrings {
  AppStrings._();

  // ── App Identity ───────────────────────────────────────────────────────────
  static const String appTitle = 'Flowdesk';
  static const String appSubtitle = 'Your AI assistant overlay';

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
      'Hello! I\'m Flowdesk. I can help you with coding, '
      'writing, analysis, and more. What would you like to explore today?';

  // ── Interview Copilot Style Prompt ─────────────────────────────────────────
  static const String interviewCopilotStylePrompt = '''
You are a real-time interview copilot helping the candidate answer out loud.

Speak as the candidate in first person ("I", "my", "I've").
Generate answers that sound natural when spoken in an interview.

Rules:
- Ground answers in the candidate resume when one is provided.
- Do not invent employers, job titles, degrees, or technologies that are not in the resume.
- If the resume lacks detail for a question, say so briefly and give an honest, speakable answer.
- Keep answers concise and conversational.
- Avoid textbook explanations and ChatGPT-sounding phrasing.
- Use simple human language and short speaking-friendly sentences.
- Prefer practical experience-style phrasing and quick examples when useful.
- Sound confident but natural.
- Keep answers under about 30 seconds when spoken.
- Focus on clarity over completeness.
- Avoid robotic transitions like "Furthermore", "In conclusion", "Moreover".

Preferred style:
"Basically..."
"In my experience..."
"A simple example is..."
"Mostly I've used this when..."
''';

  // ── System Tray ────────────────────────────────────────────────────────────
  static const String trayShowWindow = 'Show Flowdesk';
  static const String trayNewChat = 'New Chat';
  static const String trayToggleAlwaysOnTop = 'Toggle Always on Top';
  static const String trayQuit = 'Quit';
  static const String trayMinimizedNotice = 'Flowdesk is still running in the background.';

  // ── Hotkey ──────────────────────────────────────────────────────────────────
  static const String hotkeyToggleOverlay = 'Toggle Overlay (Ctrl+Shift+Space)';
  static const String hotkeyNewChat = 'New Chat (Ctrl+Shift+N)';

  // ── Title Bar ──────────────────────────────────────────────────────────────
  static const String hideToTrayTooltip = 'Hide to tray';
}
