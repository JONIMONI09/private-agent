import 'package:flutter/material.dart';
import '../models/chat_message.dart';

import 'dart:math';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.message.isError) {
      _shakeController.forward();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final isError = widget.message.isError;

    Widget bubble = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: EdgeInsets.only(
          left: isUser ? 48 : 8,
          right: isUser ? 8 : 48,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isError
              ? Theme.of(context).colorScheme.errorContainer
              : isUser
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: isError
              ? Border.all(color: Theme.of(context).colorScheme.error, width: 1.5)
              : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isError) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 16, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 4),
                  Text('Format Error', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            // Action result badge
            if (widget.message.actionResult != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: widget.message.actionResult!.success
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                      : Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.message.actionResult!.success
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 14,
                      color: widget.message.actionResult!.success
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.message.actionResult!.actionType.replaceAll('_', ' '),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.message.actionResult!.success
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Message text
            ..._buildMessageWidgets(context, widget.message.content, isUser, isError),
            // Timestamp
            const SizedBox(height: 4),
            Text(
              _formatTime(widget.message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: isError
                    ? Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.6)
                    : isUser
                        ? Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.6)
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isError) return bubble;

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        // Shake animation using sine wave
        final sineValue = sin(_shakeController.value * 3 * pi);
        return Transform.translate(
          offset: Offset(sineValue * 8, 0),
          child: child,
        );
      },
      child: bubble,
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<Widget> _buildMessageWidgets(BuildContext context, String text, bool isUser, bool isError) {
    if (!isUser && text.contains('</thought>') && !text.contains('<thought>')) {
      text = '<thought>\n$text';
    }
    
    final List<Widget> widgets = [];
    final regex = RegExp(r'<thought>([\s\S]*?)(?:</thought>|$)', multiLine: true);
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        final textPart = text.substring(lastMatchEnd, match.start).trim();
        if (textPart.isNotEmpty) {
          widgets.add(SelectableText.rich(_buildMessageSpans(context, textPart, isUser, isError)));
          widgets.add(const SizedBox(height: 8));
        }
      }

      final thoughtContent = match.group(1)?.trim() ?? '';
      if (thoughtContent.isNotEmpty) {
        widgets.add(
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              leading: Icon(Icons.psychology, size: 20, color: Theme.of(context).colorScheme.outline),
              title: Text(
                'KI Denkprozess',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              children: [
                SelectableText(
                  thoughtContent,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      final textPart = text.substring(lastMatchEnd).trim();
      if (textPart.isNotEmpty) {
        widgets.add(SelectableText.rich(_buildMessageSpans(context, textPart, isUser, isError)));
      }
    }

    if (widgets.isNotEmpty && widgets.last is SizedBox) {
      widgets.removeLast();
    }

    if (widgets.isEmpty) {
      widgets.add(SelectableText.rich(_buildMessageSpans(context, '', isUser, isError)));
    }

    return widgets;
  }

  TextSpan _buildMessageSpans(BuildContext context, String text, bool isUser, bool isError) {
    final baseStyle = TextStyle(
      color: isError
          ? Theme.of(context).colorScheme.onErrorContainer
          : isUser
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
      fontSize: 15,
      height: 1.4,
    );

    final trimmedText = text.trimLeft();
    if (trimmedText.startsWith('/')) {
      final match = RegExp(r'^/\S+').firstMatch(trimmedText);
      if (match != null) {
        final command = match.group(0)!;
        final startIndex = text.indexOf(command);
        final before = text.substring(0, startIndex);
        final rest = text.substring(startIndex + command.length);
        
        return TextSpan(
          style: baseStyle,
          children: [
            if (before.isNotEmpty) TextSpan(text: before),
            TextSpan(
              text: command,
              style: TextStyle(
                color: isUser ? Theme.of(context).colorScheme.inversePrimary : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(text: rest),
          ],
        );
      }
    }
    return TextSpan(text: text, style: baseStyle);
  }
}
