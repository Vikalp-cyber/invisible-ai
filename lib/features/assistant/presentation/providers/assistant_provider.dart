import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/preference_service.dart';
import '../../../../services/window_service.dart';
import '../../../../services/hotkey_service.dart';
import '../../../../services/tray_service.dart';
import '../../../../services/secure_storage_service.dart';
import '../../../../services/virtual_audio_cable_service.dart';
import '../../../../services/interview_audio_copilot_service.dart';
import '../../domain/repositories/ai_provider_interface.dart';
import '../../data/ai_repository_impl.dart';
import '../../data/providers/groq_config_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/audio_input_device.dart';
import '../../../../services/screen_capture_service.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../usage/presentation/providers/usage_provider.dart';
import '../../../usage/domain/models/usage_exception.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ── State Class ─────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

/// Immutable state for the assistant feature.
/// Holds the conversation messages, typing indicator, window state,
/// and overlay visibility.
class AssistantState {
  /// List of all chat messages in the conversation.
  final List<ChatMessage> messages;

  /// Whether the AI is currently "thinking" (typing indicator shown).
  final bool isTyping;

  /// Current always-on-top window state.
  final bool isAlwaysOnTop;

  /// Whether the overlay window is currently visible.
  final bool isOverlayVisible;

  /// Whether the input field should request focus (set true after hotkey toggle).
  final bool shouldFocusInput;

  /// The currently captured image ready to be sent.
  final Uint8List? selectedImage;
  final bool isInterviewCopilotActive;
  final String transcriptPreview;
  final List<AudioInputDevice> audioDevices;
  final String? selectedAudioDeviceId;

  const AssistantState({
    this.messages = const [],
    this.isTyping = false,
    this.isAlwaysOnTop = true,
    this.isOverlayVisible = true,
    this.shouldFocusInput = false,
    this.selectedImage,
    this.isInterviewCopilotActive = false,
    this.transcriptPreview = '',
    this.audioDevices = const [],
    this.selectedAudioDeviceId,
  });

  /// Creates a copy with optional overrides.
  AssistantState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    bool? isAlwaysOnTop,
    bool? isOverlayVisible,
    bool? shouldFocusInput,
    Uint8List? selectedImage,
    bool? isInterviewCopilotActive,
    String? transcriptPreview,
    List<AudioInputDevice>? audioDevices,
    String? selectedAudioDeviceId,
    bool clearImage = false,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      isAlwaysOnTop: isAlwaysOnTop ?? this.isAlwaysOnTop,
      isOverlayVisible: isOverlayVisible ?? this.isOverlayVisible,
      shouldFocusInput: shouldFocusInput ?? this.shouldFocusInput,
      selectedImage: clearImage ? null : (selectedImage ?? this.selectedImage),
      isInterviewCopilotActive:
          isInterviewCopilotActive ?? this.isInterviewCopilotActive,
      transcriptPreview: transcriptPreview ?? this.transcriptPreview,
      audioDevices: audioDevices ?? this.audioDevices,
      selectedAudioDeviceId:
          selectedAudioDeviceId ?? this.selectedAudioDeviceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantState &&
          runtimeType == other.runtimeType &&
          messages.length == other.messages.length &&
          isTyping == other.isTyping &&
          isAlwaysOnTop == other.isAlwaysOnTop &&
          isOverlayVisible == other.isOverlayVisible &&
          shouldFocusInput == other.shouldFocusInput &&
          isInterviewCopilotActive == other.isInterviewCopilotActive &&
          transcriptPreview == other.transcriptPreview &&
          selectedAudioDeviceId == other.selectedAudioDeviceId;

  @override
  int get hashCode =>
      messages.length.hashCode ^
      isTyping.hashCode ^
      isAlwaysOnTop.hashCode ^
      isOverlayVisible.hashCode ^
      shouldFocusInput.hashCode ^
      isInterviewCopilotActive.hashCode ^
      transcriptPreview.hashCode ^
      selectedAudioDeviceId.hashCode;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Providers — Services ────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

/// Singleton provider for the PreferenceService.
final preferenceServiceProvider = Provider<PreferenceService>((ref) {
  return PreferenceService();
});

/// Singleton provider for the SecureStorageService.
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Singleton provider for the AIRepository.
final aiRepositoryProvider = Provider<AIRepository>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final prefs = ref.watch(preferenceServiceProvider);
  return AIRepository(secureStorage, prefs);
});

/// Singleton provider for the ScreenCaptureService.
final screenCaptureServiceProvider = Provider<ScreenCaptureService>((ref) {
  return ScreenCaptureService();
});

/// Singleton provider for virtual audio cable setup helpers.
final virtualAudioCableServiceProvider = Provider<VirtualAudioCableService>((
  ref,
) {
  return VirtualAudioCableService();
});

final interviewAudioCopilotServiceProvider =
    Provider<InterviewAudioCopilotService>((ref) {
      final service = InterviewAudioCopilotService();
      ref.onDispose(() {
        service.dispose();
      });
      return service;
    });

/// Singleton provider for the WindowService.
/// Depends on PreferenceService for state persistence.
final windowServiceProvider = Provider<WindowService>((ref) {
  final prefs = ref.watch(preferenceServiceProvider);
  return WindowService(prefs);
});

/// Provider for the HotkeyService. Overridden in main.dart with callbacks.
final hotkeyServiceProvider = Provider<HotkeyService>((ref) {
  return HotkeyService();
});

/// Provider for the TrayService. Overridden in main.dart with callbacks.
final trayServiceProvider = Provider<TrayService>((ref) {
  return TrayService();
});

// ═══════════════════════════════════════════════════════════════════════════════
// ── Notifier ────────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

/// Manages the assistant state: sending messages, toggling always-on-top,
/// overlay visibility, tray integration, clearing chat, and coordinating
/// with the mock AI service.
///
/// Uses Riverpod 3.x [Notifier] API (replaces the legacy StateNotifier).
class AssistantNotifier extends Notifier<AssistantState> {
  // Must not be `late final`: [build] runs again when e.g. [groqClientConfigProvider] resolves.
  late WindowService _windowService;
  late AIRepository _aiRepository;
  late ScreenCaptureService _screenCaptureService;
  late VirtualAudioCableService _virtualAudioCableService;
  late InterviewAudioCopilotService _interviewAudioCopilotService;

  @override
  AssistantState build() {
    // Resolve dependencies from the provider graph.
    _windowService = ref.watch(windowServiceProvider);
    _aiRepository = ref.watch(aiRepositoryProvider);
    _screenCaptureService = ref.watch(screenCaptureServiceProvider);
    _virtualAudioCableService = ref.watch(virtualAudioCableServiceProvider);
    _interviewAudioCopilotService = ref.watch(
      interviewAudioCopilotServiceProvider,
    );

    ref.listen(authProvider, (prev, next) {
      if (!next.isAuthenticated) {
        _aiRepository.clearGroqRuntimeConfig();
        ref.invalidate(groqClientConfigProvider);
      }
    });

    ref.listen(groqClientConfigProvider, (prev, next) {
      next.whenData((config) {
        if (config != null) {
          _aiRepository.applyGroqRuntimeConfig(config);
        }
      });
    });

    ref.watch(groqClientConfigProvider);

    // Wire up visibility change callback from WindowService → state sync.
    _windowService.onVisibilityChanged = () {
      _syncVisibility();
    };

    // Initial state: welcome message + current window preferences.
    return AssistantState(
      isAlwaysOnTop: _windowService.isAlwaysOnTop,
      isOverlayVisible: _windowService.isVisible,
      messages: [ChatMessage.assistant(AppStrings.welcomeMessage)],
    );
  }

  /// ── Sync Visibility from WindowService ────────────────────────────────────
  /// Called by the WindowService callback when visibility changes externally
  /// (e.g., from tray click or hotkey).
  void _syncVisibility() {
    state = state.copyWith(isOverlayVisible: _windowService.isVisible);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Overlay Visibility (NEW) ──────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// ── Toggle Overlay Visibility ─────────────────────────────────────────────
  /// Shows or hides the overlay. When showing, requests input focus.
  Future<void> toggleOverlayVisibility() async {
    final newVisible = await _windowService.toggleVisibility();
    state = state.copyWith(
      isOverlayVisible: newVisible,
      // Auto-focus input when overlay becomes visible.
      shouldFocusInput: newVisible,
    );
  }

  /// ── Show Overlay ──────────────────────────────────────────────────────────
  /// Explicitly shows the overlay and focuses the input field.
  Future<void> showOverlay() async {
    if (!_windowService.isVisible) {
      await _windowService.showWindow();
    } else {
      await _windowService.bringToFront();
    }
    state = state.copyWith(isOverlayVisible: true, shouldFocusInput: true);
  }

  /// ── Hide Overlay ──────────────────────────────────────────────────────────
  /// Hides the overlay to the system tray.
  Future<void> hideOverlay() async {
    await _windowService.hideWindow();
    state = state.copyWith(isOverlayVisible: false, shouldFocusInput: false);
  }

  /// ── Acknowledge Focus Request ─────────────────────────────────────────────
  /// Called by the InputTextArea widget after it has received focus,
  /// clearing the shouldFocusInput flag to prevent repeated focus grabs.
  void acknowledgeFocus() {
    if (state.shouldFocusInput) {
      state = state.copyWith(shouldFocusInput: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Screen Capture ────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> captureScreen() async {
    final image = await _screenCaptureService.captureRegion();
    if (image != null) {
      state = state.copyWith(selectedImage: image);
    }
  }

  void clearSelectedImage() {
    state = state.copyWith(clearImage: true);
  }

  Future<void> addVirtualCableSetupGuide() async {
    final guide = _virtualAudioCableService.buildGoogleMeetSetupGuide();
    state = state.copyWith(
      messages: [...state.messages, ChatMessage.assistant(guide)],
    );
  }

  Future<bool> openWindowsSoundSettings() async {
    return _virtualAudioCableService.openSoundControlPanel();
  }

  Future<void> refreshAudioInputDevices() async {
    final devices = await _interviewAudioCopilotService.listDevices();
    devices.sort((a, b) {
      if (a.isVirtualCable == b.isVirtualCable) {
        return a.label.compareTo(b.label);
      }
      return a.isVirtualCable ? -1 : 1;
    });
    final vbDevice = devices.where((d) => d.isVirtualCable).toList();
    final selected =
        state.selectedAudioDeviceId ??
        (vbDevice.isNotEmpty ? vbDevice.first.id : null) ??
        (devices.isNotEmpty ? devices.first.id : null);
    state = state.copyWith(
      audioDevices: devices,
      selectedAudioDeviceId: selected,
    );
  }

  void selectAudioInputDevice(String? deviceId) {
    state = state.copyWith(selectedAudioDeviceId: deviceId);
  }

  Future<void> startInterviewCopilot() async {
    if (state.isInterviewCopilotActive) {
      return;
    }
    await refreshAudioInputDevices();
    try {
      await _interviewAudioCopilotService.start(
        deviceId: state.selectedAudioDeviceId,
        onPartialTranscript: _onPartialTranscript,
        onFinalTranscript: _onFinalTranscript,
        onQuestionDetected: _onQuestionDetected,
        onError: _onAudioPipelineError,
      );
      state = state.copyWith(
        isInterviewCopilotActive: true,
        messages: [
          ...state.messages,
          ChatMessage.system(
            'Interview copilot listening on ${_selectedDeviceLabel()}.',
          ),
        ],
      );
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage.system('Failed to start interview copilot: $e'),
        ],
      );
    }
  }

  Future<void> toggleSpeakerCopilot() async {
    if (state.isInterviewCopilotActive) {
      await stopInterviewCopilot();
      return;
    }
    try {
      await _interviewAudioCopilotService.startSystemAudio(
        onPartialTranscript: _onPartialTranscript,
        onFinalTranscript: _onFinalTranscript,
        onQuestionDetected: _onQuestionDetected,
        onError: _onAudioPipelineError,
      );
      state = state.copyWith(
        isInterviewCopilotActive: true,
        messages: [
          ...state.messages,
          ChatMessage.system(
            'Listening to system speaker output (Meet, Zoom, browser, Translate).',
          ),
        ],
      );
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage.system('Failed to start speaker copilot: $e'),
        ],
      );
    }
  }

  Future<void> stopInterviewCopilot() async {
    if (!state.isInterviewCopilotActive) {
      return;
    }
    await _interviewAudioCopilotService.stop();
    state = state.copyWith(
      isInterviewCopilotActive: false,
      transcriptPreview: '',
      messages: [
        ...state.messages,
        ChatMessage.system('Interview copilot stopped.'),
      ],
    );
  }

  void _onPartialTranscript(String partial) {
    state = state.copyWith(transcriptPreview: partial);
  }

  void _onFinalTranscript(String finalText) {
    state = state.copyWith(transcriptPreview: finalText);
  }

  Future<void> _onQuestionDetected(question) async {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage.system(
          'Detected question (${(question.confidence * 100).toStringAsFixed(0)}%): ${question.text}',
        ),
      ],
    );
    await sendMessage(question.text);
  }

  void _onAudioPipelineError(Object e) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage.system('Audio pipeline error: $e'),
      ],
    );
  }

  String _selectedDeviceLabel() {
    final matching = state.audioDevices
        .where((d) => d.id == state.selectedAudioDeviceId)
        .toList();
    if (matching.isEmpty) {
      return 'default input device';
    }
    return matching.first.label;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Chat Operations ───────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// ── Send Message ──────────────────────────────────────────────────────────
  /// Adds the user's message, then requests a streaming response from the AI.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty && state.selectedImage == null) return;
    if (state.isTyping) return;

    final isLocalProvider = _aiRepository.currentProviderType == AIProviderType.ollama;

    // --- Token Usage Pre-check ---
    if (!isLocalProvider) {
      final usageState = ref.read(usageProvider);
      
      final isUsageInactive = usageState.usage != null && 
          (!usageState.usage!.isActive || usageState.usage!.tokensRemaining <= 0);
          
      final hasLimitError = usageState.error != null && 
          (usageState.error!.contains('inactive') || usageState.error!.contains('limit'));

      if (isUsageInactive || hasLimitError) {
        state = state.copyWith(
          messages: [
            ...state.messages,
            ChatMessage.assistant(
              usageState.error ?? 'Token limit exceeded. Please upgrade to continue.',
              isError: true,
            ),
          ],
        );
        return;
      }
    }

    final userMessage = ChatMessage.user(
      text.trim(),
      imageData: state.selectedImage,
    );
    final history = List<ChatMessage>.from(state.messages);

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
      clearImage: true,
    );

    await _startStreamingResponse(
      text.trim(),
      history,
      userMessage: userMessage,
    );
  }

  Future<void> _startStreamingResponse(
    String prompt,
    List<ChatMessage> history, {
    ChatMessage? userMessage,
  }) async {
    final assistantMessageId = const Uuid().v4();
    var currentAssistantMessage = ChatMessage(
      id: assistantMessageId,
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, currentAssistantMessage],
    );

    try {
      // 3. Listen to the stream from the repository.
      final stream = _aiRepository.generateStream(
        history,
        prompt,
        imageBytes: userMessage?.imageData,
      );

      await for (final chunk in stream) {
        // Stop updating if the message was removed (e.g. chat cleared)
        if (!state.messages.any((m) => m.id == assistantMessageId)) break;

        currentAssistantMessage = currentAssistantMessage.copyWith(
          content: currentAssistantMessage.content + (chunk.delta ?? ''),
          usage: chunk.usage ?? currentAssistantMessage.usage,
        );

        state = state.copyWith(
          messages: state.messages
              .map(
                (m) => m.id == assistantMessageId ? currentAssistantMessage : m,
              )
              .toList(),
        );
      }


      // 4. Stream finished — gate the response behind usage/consume.
      if (state.messages.any((m) => m.id == assistantMessageId)) {
        currentAssistantMessage = currentAssistantMessage.copyWith(
          isStreaming: false,
        );

        final isLocalProvider = _aiRepository.currentProviderType == AIProviderType.ollama;

        if (!isLocalProvider) {
          // Determine token count: use AI metadata if available,
          // otherwise estimate (~1 token per 4 characters).
          final int tokensToConsume;
          if (currentAssistantMessage.usage != null && currentAssistantMessage.usage!.totalTokens > 0) {
            tokensToConsume = currentAssistantMessage.usage!.totalTokens;
          } else {
            tokensToConsume = (currentAssistantMessage.content.length / 4).ceil().clamp(1, 999999);
          }

          try {
            // Call POST /api/usage/consume — this is the gatekeeper.
            await ref.read(usageProvider.notifier).consumeTokens(
              tokensToConsume,
              reason: '${_aiRepository.currentProviderType.name} chat',
            );

            // ✅ Consume succeeded (200) — show the response.
            state = state.copyWith(
              messages: state.messages
                  .map((m) => m.id == assistantMessageId ? currentAssistantMessage : m)
                  .toList(),
              isTyping: false,
            );
          } on UsageException catch (e) {
            // ❌ 403 — token limit exceeded or account inactive.
            // Compulsorily REMOVE the AI response so the user cannot read it.
            final messagesWithoutResponse = state.messages
                .where((m) => m.id != assistantMessageId)
                .toList();

            state = state.copyWith(
              messages: [
                ...messagesWithoutResponse,
                ChatMessage.assistant(e.message, isError: true),
              ],
              isTyping: false,
            );
          } catch (_) {
            // Network or other errors — still show the response but log it.
            state = state.copyWith(
              messages: state.messages
                  .map((m) => m.id == assistantMessageId ? currentAssistantMessage : m)
                  .toList(),
              isTyping: false,
            );
          }
        } else {
          // Local provider (Ollama) — no consume needed, show directly.
          state = state.copyWith(
            messages: state.messages
                .map((m) => m.id == assistantMessageId ? currentAssistantMessage : m)
                .toList(),
            isTyping: false,
          );
        }
      }
    } catch (e) {
      debugPrint('AssistantNotifier: AI response error: $e');
      if (state.messages.any((m) => m.id == assistantMessageId)) {
        currentAssistantMessage = currentAssistantMessage.copyWith(
          isStreaming: false,
          isError: true,
          content: currentAssistantMessage.content.isEmpty
              ? 'Sorry, I encountered an error: $e'
              : '${currentAssistantMessage.content}\n\n[Error: $e]',
        );
        state = state.copyWith(
          messages: state.messages
              .map(
                (m) => m.id == assistantMessageId ? currentAssistantMessage : m,
              )
              .toList(),
          isTyping: false,
        );
      }
    }
  }

  /// ── Stop Generation ───────────────────────────────────────────────────────
  void stopGeneration() {
    _aiRepository.stopGeneration();
    state = state.copyWith(isTyping: false);

    // Find any streaming messages and mark them as stopped.
    final updatedMessages = state.messages.map((m) {
      if (m.isStreaming) {
        return m.copyWith(isStreaming: false);
      }
      return m;
    }).toList();

    state = state.copyWith(messages: updatedMessages);
  }

  /// ── Regenerate Last Response ──────────────────────────────────────────────
  Future<void> regenerateLastResponse() async {
    if (state.isTyping) return;

    final messages = state.messages.toList();
    if (messages.length < 2) return;

    // Find the last user message to use as the prompt.
    final lastUserIndex = messages.lastIndexWhere((m) => m.isUser);
    if (lastUserIndex == -1) return;

    final prompt = messages[lastUserIndex].content;

    // Remove the previous assistant response if it exists after the last user message.
    if (messages.last.isAssistant || messages.last.isError) {
      messages.removeLast();
    }

    state = state.copyWith(messages: messages);
    await sendMessage(prompt);
  }

  /// ── Switch AI Provider ────────────────────────────────────────────────────
  void switchProvider(AIProviderType type) {
    _aiRepository.setProvider(type);
  }

  AIProviderType get currentProviderType => _aiRepository.currentProviderType;

  /// ── Toggle Always-On-Top ──────────────────────────────────────────────────
  /// Delegates to WindowService and updates state to reflect the new value.
  Future<void> toggleAlwaysOnTop() async {
    final newValue = await _windowService.toggleAlwaysOnTop();
    state = state.copyWith(isAlwaysOnTop: newValue);
  }

  /// ── Clear Chat ────────────────────────────────────────────────────────────
  /// Resets the conversation to the initial welcome message.
  void clearChat() {
    state = state.copyWith(
      messages: [ChatMessage.assistant(AppStrings.welcomeMessage)],
      isTyping: false,
    );
  }

  /// ── New Chat (from hotkey / tray) ─────────────────────────────────────────
  /// Clears the conversation, shows the overlay, and focuses input.
  Future<void> newChat() async {
    clearChat();
    await showOverlay();
  }

  /// ── Get Last AI Response ──────────────────────────────────────────────────
  /// Returns the content of the most recent assistant message, or null.
  String? getLastAssistantMessage() {
    try {
      return state.messages.lastWhere((msg) => msg.isAssistant).content;
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Window Operations ─────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// ── Minimize Window ───────────────────────────────────────────────────────
  Future<void> minimizeWindow() async {
    await _windowService.minimizeWindow();
  }

  /// ── Close Window (Hide to Tray) ───────────────────────────────────────────
  /// Default close behavior: hides to tray instead of quitting.
  Future<void> closeWindow() async {
    await _windowService.closeWindow();
    state = state.copyWith(isOverlayVisible: false);
  }

  /// ── Force Quit Application ────────────────────────────────────────────────
  /// Actually terminates the app. Called from tray "Quit" menu item.
  Future<void> forceQuit() async {
    await _windowService.forceClose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Main Provider ───────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

/// The main assistant state provider.
/// Manages the entire conversation, window state, and overlay visibility.
final assistantProvider = NotifierProvider<AssistantNotifier, AssistantState>(
  AssistantNotifier.new,
);
