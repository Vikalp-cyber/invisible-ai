import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/chat_message.dart';

/// ── Message Bubble ─────────────────────────────────────────────────────────
/// Renders a single chat message with distinct styling for user vs assistant:
/// - **User**: Right-aligned, primary gradient background, rounded corners
/// - **Assistant**: Left-aligned, glass surface background, rounded corners
///
/// Features:
/// - Timestamp display
/// - Copy-to-clipboard on long press
/// - Smooth entry animation (fade + slide from bottom)
class MessageBubble extends StatelessWidget {
  /// The chat message to display.
  final ChatMessage message;

  /// Index in the message list, used for staggered animation delays.
  final int index;

  const MessageBubble({super.key, required this.message, required this.index});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
          padding: EdgeInsets.only(
            left: isUser ? 48 : AppConstants.horizontalPadding,
            right: isUser ? AppConstants.horizontalPadding : 48,
            bottom: 12,
          ),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // ── Message Bubble ───────────────────────────────────────────────
              GestureDetector(
                onLongPress: () => _copyToClipboard(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    // User: gradient with glow, Assistant: dark glass surface.
                    gradient: isUser ? AppColors.primaryGradient : null,
                    color: isUser
                        ? null
                        : AppColors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(
                        AppConstants.cardBorderRadius,
                      ),
                      topRight: const Radius.circular(
                        AppConstants.cardBorderRadius,
                      ),
                      // Asymmetric corners for chat-like appearance.
                      bottomLeft: Radius.circular(
                        isUser ? AppConstants.cardBorderRadius : 6,
                      ),
                      bottomRight: Radius.circular(
                        isUser ? 6 : AppConstants.cardBorderRadius,
                      ),
                    ),
                    border: Border.all(
                      color: isUser
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.glassBorder,
                      width: 0.8,
                    ),
                    boxShadow: [
                      if (isUser)
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role label for assistant messages.
                      if (!isUser) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 12,
                              color: AppColors.primary.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Flowdesk',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      // User attached image
                      if (message.imageData != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            message.imageData!,
                            width: 250,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Message content.
                      if (isUser)
                        SelectableText(
                          message.content,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textOnPrimary,
                                height: 1.45,
                              ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MarkdownBody(
                              data: message.content,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet(
                                p: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      height: 1.45,
                                    ),
                                code: const TextStyle(
                                  fontFamily: 'Consolas',
                                  backgroundColor: Colors.transparent,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: AppColors.backgroundDark,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              builders: {'code': CodeElementBuilder()},
                            ),
                            // Blinking cursor if streaming
                            if (message.isStreaming)
                              Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    width: 8,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .fade(duration: 400.ms),
                            if (message.isError)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: AppColors.error,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Generation failed',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.error),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // ── Footer (Timestamp & Usage) ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isUser && message.usage != null) ...[
                      Icon(
                        Icons.data_usage_rounded,
                        size: 10,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${message.usage!.totalTokens} tokens',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: AppColors.textMuted.withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 8,
                        color: AppColors.textMuted.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      message.formattedTime,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        // Entry animation: fade in + slide up from bottom.
        .animate()
        .fadeIn(
          duration: AppConstants.messageEntryAnimation,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.15,
          end: 0,
          duration: AppConstants.messageEntryAnimation,
          curve: Curves.easeOutCubic,
        );
  }

  /// Copies the message content to the clipboard and shows a snackbar.
  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// ── Code Element Builder ───────────────────────────────────────────────────
/// Custom Markdown builder for rendering code blocks with syntax highlighting
/// and a copy button.
class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    String language = '';

    if (element.attributes['class'] != null) {
      String lgPattern = element.attributes['class'] as String;
      if (lgPattern.startsWith('language-')) {
        language = lgPattern.substring(9);
      }
    }

    // Markdown parser might add a trailing newline
    final text = element.textContent.endsWith('\n')
        ? element.textContent.substring(0, element.textContent.length - 1)
        : element.textContent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.glassBorder, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language.isEmpty ? 'code' : language,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                ),
              ],
            ),
          ),
          // Code content with syntax highlighting
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: HighlightView(
                text,
                language: language.isEmpty ? 'plaintext' : language,
                theme: atomOneDarkTheme,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
