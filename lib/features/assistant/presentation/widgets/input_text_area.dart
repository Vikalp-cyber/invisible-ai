import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/assistant_provider.dart';

/// ── Input Text Area ────────────────────────────────────────────────────────
/// The message input field at the bottom of the assistant overlay.
///
/// Features:
/// - Glass-styled text field with custom decoration
/// - Multi-line support (max 4 lines, then scrolls)
/// - Animated send button that activates when text is entered
/// - Keyboard shortcuts: Enter to send, Shift+Enter for newline
/// - Subtle focus ring animation
class InputTextArea extends ConsumerStatefulWidget {
  const InputTextArea({super.key});

  @override
  ConsumerState<InputTextArea> createState() => _InputTextAreaState();
}

class _InputTextAreaState extends ConsumerState<InputTextArea> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    // Track whether the input has text for send button activation.
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Sends typed text, or while interview/speaker copilot is on with an empty
  /// field, sends the live transcript draft.
  void _sendMessage() {
    final copilot = ref.read(assistantProvider).isInterviewCopilotActive;
    final listenDraft = ref.read(assistantProvider).listenDraftDisplay.trim();
    final text = _controller.text.trim();
    if (copilot && text.isEmpty && listenDraft.isNotEmpty) {
      ref.read(assistantProvider.notifier).sendListenDraft();
      return;
    }
    if (text.isEmpty) return;

    ref.read(assistantProvider.notifier).sendMessage(text);
    _controller.clear();
    _focusNode.requestFocus(); // Keep focus on the input field.
  }

  @override
  Widget build(BuildContext context) {
    final isTyping = ref.watch(
      assistantProvider.select((state) => state.isTyping),
    );
    final selectedImage = ref.watch(
      assistantProvider.select((state) => state.selectedImage),
    );
    final copilotActive = ref.watch(
      assistantProvider.select((state) => state.isInterviewCopilotActive),
    );
    final listenDraft = ref.watch(
      assistantProvider.select((state) => state.listenDraftDisplay),
    );

    // ── Auto-Focus Management ──────────────────────────────────────────────
    // When the overlay is shown via hotkey or tray, shouldFocusInput becomes
    // true. We listen for that change and request focus on the text field.
    ref.listen<bool>(
      assistantProvider.select((state) => state.shouldFocusInput),
      (previous, shouldFocus) {
        if (shouldFocus) {
          // Delay slightly to ensure the window is fully visible.
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) {
              _focusNode.requestFocus();
              ref.read(assistantProvider.notifier).acknowledgeFocus();
            }
          });
        }
      },
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.horizontalPadding,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        // Top separator line.
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Text Input Field & Image Preview ──────────────────────────────
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            selectedImage,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, size: 18),
                            color: AppColors.textSecondary,
                            onPressed: () => ref
                                .read(assistantProvider.notifier)
                                .clearSelectedImage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                KeyboardListener(
                  focusNode: FocusNode(), // Dummy focus node for the listener.
                  onKeyEvent: (event) {
                    // Enter to send (without Shift).
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      _sendMessage();
                    }
                  },
                  child: AnimatedContainer(
                    duration: 300.ms,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _focusNode.hasFocus
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 4,
                      minLines: 1,
                      enabled: !isTyping,
                      onChanged: (_) => setState(() {}), // Trigger rebuild for focus/text state
                      textInputAction: TextInputAction.newline,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: isTyping
                            ? 'Waiting for response...'
                            : AppStrings.inputPlaceholder,
                        filled: true,
                        fillColor: _focusNode.hasFocus
                            ? AppColors.glassWhiteHover
                            : AppColors.glassWhite,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.glassBorder,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Send Button ────────────────────────────────────────────────────
          _buildSendButton(
            isTyping,
            selectedImage != null,
            copilotActive,
            listenDraft.trim().isNotEmpty,
          ),
        ],
      ),
    );
  }

  /// Animated send button that activates when text is entered, or shows Stop when typing.
  Widget _buildSendButton(
    bool isTyping,
    bool hasImage,
    bool copilotActive,
    bool hasListenDraft,
  ) {
    final isActive =
        _hasText || hasImage || isTyping || (copilotActive && hasListenDraft);

    return MouseRegion(
      cursor: isActive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: () {
          if (isTyping) {
            ref.read(assistantProvider.notifier).stopGeneration();
          } else if (isActive) {
            _sendMessage();
          }
        },
        child: AnimatedContainer(
          duration: AppConstants.fastAnimation,
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isTyping
                ? null // No gradient for stop
                : (isActive ? AppColors.primaryGradient : null),
            color: isTyping
                ? AppColors.error.withValues(alpha: 0.9)
                : (isActive
                    ? null
                    : AppColors.surface.withValues(alpha: 0.5)),
            boxShadow: isActive && !isTyping
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
            border: Border.all(
              color: isActive && !isTyping
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.glassBorder,
              width: 0.5,
            ),
          ),
          child: Icon(
            isTyping ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            size: 22,
            color: isActive ? AppColors.textOnPrimary : AppColors.textMuted,
          ),
        )
            .animate(target: isActive ? 1 : 0)
            .scaleXY(begin:0.85, end: 1.0, duration: 250.ms, curve: Curves.easeOutBack),
      ),
    );
  }
}

