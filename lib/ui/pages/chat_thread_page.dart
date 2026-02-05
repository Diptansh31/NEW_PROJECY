import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../chat/firestore_chat_models.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import 'reaction_row.dart';
import 'swipe_to_reply.dart';

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.currentUser,
    required this.otherUser,
    required this.thread,
    required this.chat,
    required this.social,
    this.isMatchChat = false,
  });

  final AppUser currentUser;
  final AppUser otherUser;
  final FirestoreChatThread thread;
  final FirestoreChatController chat;
  final FirestoreSocialGraphController social;
  final bool isMatchChat;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final hour12 = (h % 12 == 0) ? 12 : (h % 12);
    final ampm = h >= 12 ? 'PM' : 'AM';
    return '$hour12:$m $ampm';
  }

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showEmojiPicker = false;

  FirestoreMessage? _replyTo;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() => _showEmojiPicker = !_showEmojiPicker);
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji.emoji,
    );
    final newCursorPosition = selection.start + emoji.emoji.length;
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: newCursorPosition);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: widget.social.friendsStream(uid: widget.currentUser.uid),
      builder: (context, snap) {
        final friends = snap.data;
        if (friends == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final areFriends = friends.contains(widget.otherUser.uid);
        final isMatch = widget.isMatchChat;
        final canChat = areFriends || isMatch;

        final theme = Theme.of(context);
        final love = theme.colorScheme.secondary;
        final loveSoft = love.withValues(alpha: 0.14);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                if (isMatch) ...[
                  Icon(Icons.favorite, color: love),
                  const SizedBox(width: 8),
                ],
                Text(widget.otherUser.username),
              ],
            ),
          ),
          body: DecoratedBox(
            decoration: isMatch
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [loveSoft, theme.colorScheme.surface],
                    ),
                  )
                : const BoxDecoration(),
            child: Column(
              children: [
                if (!canChat)
                  MaterialBanner(
                    content: const Text('You can only chat with friends. Send/accept a friend request first.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                Expanded(
                  child: StreamBuilder<List<FirestoreMessage>>(
                    stream: widget.chat.messagesStream(threadId: widget.thread.id),
                    builder: (context, snap) {
                      final messages = snap.data;
                      if (messages == null) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final m = messages[messages.length - 1 - index];
                          final isMe = m.fromUid == widget.currentUser.uid;
                          final text = widget.chat.displayText(m);

                          // WhatsApp-like colors: outgoing slightly tinted, incoming neutral.
                          final myBubble = isMatch
                              ? theme.colorScheme.secondary.withValues(alpha: 0.22)
                              : theme.colorScheme.primary.withValues(alpha: 0.12);
                          final otherBubble = isMatch
                              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.70)
                              : theme.colorScheme.surfaceContainerHighest;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SizedBox(
                              width: double.infinity,
                              child: SwipeToReply(
                                replyFromRight: isMe,
                                onReply: () => setState(() => _replyTo = m),
                                child: Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onLongPress: () => _showMessageActions(context, m),
                                      child: IntrinsicWidth(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isMe ? myBubble : otherBubble,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(16),
                                              topRight: const Radius.circular(16),
                                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                                              bottomRight: Radius.circular(isMe ? 4 : 16),
                                            ),
                                          ),
                                          padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                                          child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (m.replyToText != null)
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                margin: const EdgeInsets.only(bottom: 8),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    left: BorderSide(
                                                      color: theme.colorScheme.primary,
                                                      width: 3,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  m.replyToText!,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme.textTheme.bodySmall,
                                                ),
                                              ),
                                            Stack(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 54, bottom: 14),
                                                  child: Text(text),
                                                ),
                                                Positioned(
                                                  right: 0,
                                                  bottom: 0,
                                                  child: Text(
                                                    _formatTime(m.sentAt),
                                                    style: theme.textTheme.labelSmall?.copyWith(
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (m.reactions.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              ReactionRow(
                                                reactions: m.reactions,
                                                myUid: widget.currentUser.uid,
                                                onToggle: (emoji) => widget.chat.toggleReaction(
                                                  threadId: widget.thread.id,
                                                  messageId: m.id,
                                                  emoji: emoji,
                                                  uid: widget.currentUser.uid,
                                                ),
                                              ),
                                            ],
                                          ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyTo != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Replying',
                                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.chat.displayText(_replyTo!),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _replyTo = null),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: canChat ? _toggleEmojiPicker : null,
                              icon: Icon(
                                _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                enabled: canChat,
                                decoration: const InputDecoration(
                                  hintText: 'Message…',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onSubmitted: canChat ? (_) => _send() : null,
                                onTap: () {
                                  if (_showEmojiPicker) {
                                    setState(() => _showEmojiPicker = false);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: canChat ? _send : null,
                              icon: const Icon(Icons.send),
                            ),
                          ],
                        ),
                        if (_showEmojiPicker)
                          SizedBox(
                            height: 280,
                            child: EmojiPicker(
                              onEmojiSelected: _onEmojiSelected,
                              config: Config(
                                height: 280,
                                checkPlatformCompatibility: true,
                                emojiViewConfig: EmojiViewConfig(
                                  emojiSizeMax: 28 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                                ),
                                viewOrderConfig: const ViewOrderConfig(
                                  top: EmojiPickerItem.searchBar,
                                  middle: EmojiPickerItem.categoryBar,
                                  bottom: EmojiPickerItem.emojiView,
                                ),
                                skinToneConfig: const SkinToneConfig(),
                                categoryViewConfig: CategoryViewConfig(
                                  backgroundColor: theme.colorScheme.surface,
                                  indicatorColor: theme.colorScheme.primary,
                                  iconColorSelected: theme.colorScheme.primary,
                                ),
                                bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                                searchViewConfig: SearchViewConfig(
                                  backgroundColor: theme.colorScheme.surface,
                                  buttonIconColor: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMessageActions(BuildContext context, FirestoreMessage message) async {
    final theme = Theme.of(context);
    final quick = <String>['❤️', '😂', '😮', '😢', '😡', '👍'];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('React', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final e in quick)
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          fireAndForget(
                            widget.chat.toggleReaction(
                              threadId: widget.thread.id,
                              messageId: message.id,
                              emoji: e,
                              uid: widget.currentUser.uid,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() => _replyTo = message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('Copy'),
                  onTap: () {
                    // Clipboard import avoided; implement later if needed.
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await runAsyncAction(context, () async {
      await widget.chat.sendMessagePlaintext(
        threadId: widget.thread.id,
        fromUid: widget.currentUser.uid,
        fromEmail: widget.currentUser.email,
        toUid: widget.otherUser.uid,
        toEmail: widget.otherUser.email,
        text: text,
        replyToMessageId: _replyTo?.id,
        replyToFromUid: _replyTo?.fromUid,
        replyToText: _replyTo == null ? null : widget.chat.displayText(_replyTo!),
      );
      _controller.clear();
      setState(() {
        _replyTo = null;
      });
    });
  }
}
