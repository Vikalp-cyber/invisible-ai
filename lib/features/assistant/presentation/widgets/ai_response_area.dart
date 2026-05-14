import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/assistant_provider.dart';
import 'message_bubble.dart';
import 'typing_indicator.dart';

/// ── AI Response Area ───────────────────────────────────────────────────────
/// The main scrollable area displaying the conversation between user and AI.
///
/// Features:
/// - Auto-scrolls to the latest message on new entries
/// - Animated empty state with AI icon when no messages exist
/// - Typing indicator at the bottom during AI "thinking"
/// - Each message enters with a smooth fade + slide animation
class AIResponseArea extends ConsumerStatefulWidget {
  const AIResponseArea({super.key});

  @override
  ConsumerState<AIResponseArea> createState() => _AIResponseAreaState();
}

class _AIResponseAreaState extends ConsumerState<AIResponseArea> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls to the bottom of the list after a new message is added.
  void _scrollToBottom() {
    // Use a post-frame callback to ensure the list has been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppConstants.normalAnimation,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);
    final messages = state.messages;
    final isTyping = state.isTyping;

    // Trigger auto-scroll whenever messages change or typing state changes.
    ref.listen<AssistantState>(assistantProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.isTyping != next.isTyping ||
          previous?.listenFinalizedText != next.listenFinalizedText ||
          previous?.listenPartialText != next.listenPartialText) {
        _scrollToBottom();
      }
    });

    // ── Empty State ──────────────────────────────────────────────────────────
    if (messages.isEmpty) {
      return _buildEmptyState(context);
    }

    // ── Message List ─────────────────────────────────────────────────────────
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      itemCount: messages.length + (isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        // Show typing indicator as the last item when AI is thinking.
        if (index == messages.length && isTyping) {
          return const TypingIndicator();
        }

        final message = messages[index];
        return MessageBubble(
          key: ValueKey(message.id),
          message: message,
          index: index,
        );
      },
    );
  }

  /// Animated empty state with a pulsing AI icon and welcome text.
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated AI icon.
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: AppColors.textOnPrimary,
              size: 36,
            ),
          )
              .animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              )
              .scaleXY(
                begin: 0.95,
                end: 1.05,
                duration: 2.seconds,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 20),

          // Welcome title.
          Text(
            AppStrings.emptyStateTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),

          // Welcome subtitle.
          Text(
            AppStrings.emptyStateSubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOut);
  }
}
