import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../call/voice_call_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../chat/firestore_chat_models.dart' show FirestoreChatThread, FirestoreMessage, CallMessageStatus;
import '../../notifications/firestore_notifications_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import 'reaction_row.dart';
import 'swipe_to_reply.dart';
import 'voice_call_page.dart';

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.currentUser,
    required this.otherUser,
    required this.thread,
    required this.chat,
    required this.social,
    required this.notifications,
    required this.callController,
    this.isMatchChat = false,
  });

  final AppUser currentUser;
  final AppUser otherUser;
  final FirestoreChatThread thread;
  final FirestoreChatController chat;
  final FirestoreSocialGraphController social;
  final FirestoreNotificationsController notifications;
  final VoiceCallController callController;
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

  // Selection mode state
  bool _selectionMode = false;
  final Set<String> _selectedMessageIds = {};
  
  // For showing reaction picker above message
  final Map<String, GlobalKey> _messageKeys = {};
  OverlayEntry? _reactionOverlay;
  bool _showingFullEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    // Mark message notifications for this thread as read when chat is opened
    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    await widget.notifications.markMessageNotificationsRead(
      uid: widget.currentUser.uid,
      threadId: widget.thread.id,
    );
  }

  @override
  void dispose() {
    _removeReactionOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  void _removeReactionOverlay() {
    _reactionOverlay?.remove();
    _reactionOverlay = null;
  }
  
  GlobalKey _getMessageKey(String messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
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
            leading: _selectionMode
                ? IconButton(
                    onPressed: _exitSelectionMode,
                    icon: const Icon(Icons.close),
                  )
                : null,
            title: _selectionMode
                ? Text('${_selectedMessageIds.length} selected')
                : Row(
                    children: [
                      if (isMatch) ...[
                        Icon(Icons.favorite, color: love),
                        const SizedBox(width: 8),
                      ],
                      Text(widget.otherUser.username),
                    ],
                  ),
            actions: [
              if (_selectionMode) ...[
                // Show reaction button only when exactly one message is selected
                if (_selectedMessageIds.length == 1)
                  IconButton(
                    onPressed: () => _showReactionPicker(_selectedMessageIds.first),
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    tooltip: 'React',
                  ),
                IconButton(
                  onPressed: _selectedMessageIds.isNotEmpty
                      ? () => _showDeleteDialog(context)
                      : null,
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                ),
              ] else if (canChat)
                IconButton(
                  onPressed: () => _startVoiceCall(context),
                  icon: const Icon(Icons.call),
                  tooltip: 'Voice Call',
                ),
            ],
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
                          final isDeleted = m.isDeletedFor(widget.currentUser.uid);
                          final text = widget.chat.displayText(m, forUid: widget.currentUser.uid);
                          final isSelected = _selectedMessageIds.contains(m.id);

                          // Skip messages deleted for this user (don't show at all)
                          // Or show "This message was deleted" - we'll show it
                          
                          // WhatsApp-like colors: outgoing slightly tinted, incoming neutral.
                          final myBubble = isMatch
                              ? theme.colorScheme.secondary.withValues(alpha: 0.22)
                              : theme.colorScheme.primary.withValues(alpha: 0.12);
                          final otherBubble = isMatch
                              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.70)
                              : theme.colorScheme.surfaceContainerHighest;

                          // Special rendering for call messages (if not deleted)
                          if (m.isCallMessage && !isDeleted) {
                            return _buildCallMessageBubble(
                              context: context,
                              message: m,
                              isMe: isMe,
                              theme: theme,
                            );
                          }

                          // Add extra bottom padding if message has reactions (for the overlapping badge)
                          final hasReactions = m.reactions.isNotEmpty && !isDeleted;
                          
                          return Padding(
                            padding: EdgeInsets.only(bottom: hasReactions ? 22 : 4),
                            child: SwipeToReply(
                              replyFromRight: isMe,
                              onReply: isDeleted ? () {} : () => setState(() => _replyTo = m),
                              child: GestureDetector(
                                onTap: _selectionMode
                                    ? () => _toggleMessageSelection(m.id)
                                    : null,
                                onLongPress: isDeleted
                                    ? null
                                    : () => _enterSelectionMode(m.id),
                                child: Container(
                                  key: _getMessageKey(m.id),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  color: isSelected
                                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  child: Row(
                                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            // Message bubble
                                            Container(
                                              constraints: BoxConstraints(
                                                maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDeleted
                                                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                                                    : (isMe ? myBubble : otherBubble),
                                                borderRadius: BorderRadius.only(
                                                  topLeft: const Radius.circular(18),
                                                  topRight: const Radius.circular(18),
                                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.only(
                                                  topLeft: const Radius.circular(18),
                                                  topRight: const Radius.circular(18),
                                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    // Reply preview
                                                    if (m.replyToText != null && !isDeleted)
                                                      Container(
                                                        width: double.infinity,
                                                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                                        decoration: BoxDecoration(
                                                          color: isMe 
                                                              ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                                              : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                                          border: Border(
                                                            left: BorderSide(
                                                              color: isMe 
                                                                  ? theme.colorScheme.primary
                                                                  : theme.colorScheme.secondary,
                                                              width: 4,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          m.replyToText!,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: theme.textTheme.bodySmall?.copyWith(
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                    // Message content with timestamp
                                                    Padding(
                                                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          // Message text
                                                          Flexible(
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                if (isDeleted)
                                                                  Padding(
                                                                    padding: const EdgeInsets.only(right: 4),
                                                                    child: Icon(
                                                                      Icons.block,
                                                                      size: 16,
                                                                      color: theme.colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                Flexible(
                                                                  child: Text(
                                                                    text,
                                                                    style: isDeleted
                                                                        ? theme.textTheme.bodyLarge?.copyWith(
                                                                            fontStyle: FontStyle.italic,
                                                                            color: theme.colorScheme.onSurfaceVariant,
                                                                          )
                                                                        : theme.textTheme.bodyLarge,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          // Timestamp
                                                          const SizedBox(width: 8),
                                                          Padding(
                                                            padding: const EdgeInsets.only(bottom: 0),
                                                            child: Text(
                                                              _formatTime(m.sentAt),
                                                              style: theme.textTheme.labelSmall?.copyWith(
                                                                fontSize: 11,
                                                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // WhatsApp-style reaction badge
                                            if (hasReactions)
                                              Positioned(
                                                bottom: -18,
                                                // Place on left side for both sender and receiver
                                                left: 12,
                                                child: ReactionRow(
                                                  reactions: m.reactions,
                                                  myUid: widget.currentUser.uid,
                                                  isMe: isMe,
                                                  onToggle: (emoji) => widget.chat.toggleReaction(
                                                    threadId: widget.thread.id,
                                                    messageId: m.id,
                                                    emoji: emoji,
                                                    uid: widget.currentUser.uid,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                          Container(
                            height: 300,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: EmojiPicker(
                                onEmojiSelected: _onEmojiSelected,
                                config: Config(
                                  height: 300,
                                  checkPlatformCompatibility: true,
                                  emojiViewConfig: EmojiViewConfig(
                                    emojiSizeMax: 28 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                                    verticalSpacing: 0,
                                    horizontalSpacing: 0,
                                    gridPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    recentsLimit: 28,
                                    backgroundColor: theme.colorScheme.surface,
                                    noRecents: Text(
                                      'No Recents',
                                      style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                    buttonMode: ButtonMode.MATERIAL,
                                  ),
                                  viewOrderConfig: const ViewOrderConfig(
                                    top: EmojiPickerItem.categoryBar,
                                    middle: EmojiPickerItem.emojiView,
                                    bottom: EmojiPickerItem.searchBar,
                                  ),
                                  skinToneConfig: SkinToneConfig(
                                    enabled: true,
                                    dialogBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                                    indicatorColor: theme.colorScheme.primary,
                                  ),
                                  categoryViewConfig: CategoryViewConfig(
                                    initCategory: Category.SMILEYS,
                                    backgroundColor: theme.colorScheme.surface,
                                    dividerColor: theme.colorScheme.outlineVariant,
                                    indicatorColor: theme.colorScheme.primary,
                                    iconColor: theme.colorScheme.onSurfaceVariant,
                                    iconColorSelected: theme.colorScheme.primary,
                                    categoryIcons: const CategoryIcons(),
                                  ),
                                  bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                                  searchViewConfig: SearchViewConfig(
                                    backgroundColor: theme.colorScheme.surface,
                                    buttonIconColor: theme.colorScheme.primary,
                                    hintText: 'Search emoji...',
                                  ),
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

  void _startVoiceCall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoiceCallPage(
          currentUser: widget.currentUser,
          otherUser: widget.otherUser,
          callController: widget.callController,
        ),
      ),
    );
  }

  void _enterSelectionMode(String messageId) {
    setState(() {
      _selectionMode = true;
      _selectedMessageIds.add(messageId);
    });
    // Show reaction picker above the selected message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showReactionPickerAboveMessage(messageId);
    });
  }

  void _showReactionPickerAboveMessage(String messageId) {
    _removeReactionOverlay();
    
    final messageKey = _messageKeys[messageId];
    if (messageKey == null || messageKey.currentContext == null) return;
    
    final RenderBox renderBox = messageKey.currentContext!.findRenderObject() as RenderBox;
    final Offset messagePosition = renderBox.localToGlobal(Offset.zero);
    final Size messageSize = renderBox.size;
    final Size screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    
    // Quick reactions - 6 emojis like WhatsApp
    final quickReactions = ['❤️', '😂', '😮', '😢', '😡', '👍'];
    
    _reactionOverlay = OverlayEntry(
      builder: (context) {
        // Calculate position - show above the message
        const pickerHeight = 56.0;
        const pickerWidth = 280.0;
        
        double top = messagePosition.dy - pickerHeight - 8;
        // If not enough space above, show below
        if (top < MediaQuery.of(context).padding.top + kToolbarHeight) {
          top = messagePosition.dy + messageSize.height + 8;
        }
        
        // Center horizontally relative to message, but keep within screen
        double left = messagePosition.dx + (messageSize.width - pickerWidth) / 2;
        left = left.clamp(16.0, screenSize.width - pickerWidth - 16);
        
        return Stack(
          children: [
            // Dismiss overlay when tapping outside
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _removeReactionOverlay();
                  if (!_showingFullEmojiPicker) {
                    _exitSelectionMode();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Reaction picker
            Positioned(
              top: top,
              left: left,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final emoji in quickReactions)
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            _removeReactionOverlay();
                            widget.chat.toggleReaction(
                              threadId: widget.thread.id,
                              messageId: messageId,
                              emoji: emoji,
                              uid: widget.currentUser.uid,
                            );
                            _exitSelectionMode();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(emoji, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                      Container(
                        width: 1,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: theme.colorScheme.outlineVariant,
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          _removeReactionOverlay();
                          _showingFullEmojiPicker = true;
                          setState(() {});
                          _showFullEmojiPickerInline(messageId);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.add_circle_outline, size: 24, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    
    Overlay.of(context).insert(_reactionOverlay!);
  }

  void _showFullEmojiPickerInline(String messageId) {
    final theme = Theme.of(context);
    
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.45,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    Navigator.of(ctx).pop();
                    widget.chat.toggleReaction(
                      threadId: widget.thread.id,
                      messageId: messageId,
                      emoji: emoji.emoji,
                      uid: widget.currentUser.uid,
                    );
                    _showingFullEmojiPicker = false;
                    _exitSelectionMode();
                  },
                  config: Config(
                    height: 300,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      emojiSizeMax: 28 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                      verticalSpacing: 0,
                      horizontalSpacing: 0,
                      gridPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      recentsLimit: 28,
                      backgroundColor: theme.colorScheme.surface,
                      noRecents: Text(
                        'No Recents',
                        style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      buttonMode: ButtonMode.MATERIAL,
                    ),
                    viewOrderConfig: const ViewOrderConfig(
                      top: EmojiPickerItem.categoryBar,
                      middle: EmojiPickerItem.emojiView,
                      bottom: EmojiPickerItem.searchBar,
                    ),
                    skinToneConfig: SkinToneConfig(
                      enabled: true,
                      dialogBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                      indicatorColor: theme.colorScheme.primary,
                    ),
                    categoryViewConfig: CategoryViewConfig(
                      initCategory: Category.SMILEYS,
                      backgroundColor: theme.colorScheme.surface,
                      dividerColor: theme.colorScheme.outlineVariant,
                      indicatorColor: theme.colorScheme.primary,
                      iconColor: theme.colorScheme.onSurfaceVariant,
                      iconColorSelected: theme.colorScheme.primary,
                      categoryIcons: const CategoryIcons(),
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                    searchViewConfig: SearchViewConfig(
                      backgroundColor: theme.colorScheme.surface,
                      buttonIconColor: theme.colorScheme.primary,
                      hintText: 'Search emoji...',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _showingFullEmojiPicker = false;
      _exitSelectionMode();
    });
  }
  
  void _showReactionPicker(String messageId) {
    // Called from app bar button - show above the message if possible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showReactionPickerAboveMessage(messageId);
    });
  }

  void _exitSelectionMode() {
    _removeReactionOverlay();
    setState(() {
      _selectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final count = _selectedMessageIds.length;
    
    // Check if any selected message can be deleted for everyone (sent by current user)
    final messagesStream = widget.chat.messagesStream(threadId: widget.thread.id);
    final messages = await messagesStream.first;
    final selectedMessages = messages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    final canDeleteForEveryone = selectedMessages.any((m) => m.fromUid == widget.currentUser.uid);
    final allMine = selectedMessages.every((m) => m.fromUid == widget.currentUser.uid);

    if (!mounted) return;

    final ctx = context;
    await showModalBottomSheet<void>(
      context: ctx,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Delete $count message${count > 1 ? 's' : ''}?',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Delete for me option
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete for me'),
                  subtitle: const Text('This message will be deleted from your device only'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _deleteForMe();
                  },
                ),

                // Delete for everyone option (only if user sent any selected message)
                if (canDeleteForEveryone)
                  ListTile(
                    leading: const Icon(Icons.delete_forever),
                    title: const Text('Delete for everyone'),
                    subtitle: Text(
                      allMine
                          ? 'This message will be deleted for all participants'
                          : 'Only your messages will be deleted for everyone',
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _deleteForEveryone();
                    },
                  ),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteForMe() async {
    final messageIds = _selectedMessageIds.toList();
    _exitSelectionMode();

    await runAsyncAction(context, () async {
      await widget.chat.deleteMessagesForMe(
        threadId: widget.thread.id,
        messageIds: messageIds,
        uid: widget.currentUser.uid,
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${messageIds.length} message${messageIds.length > 1 ? 's' : ''} deleted'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteForEveryone() async {
    final messageIds = _selectedMessageIds.toList();
    _exitSelectionMode();

    await runAsyncAction(context, () async {
      final deletedCount = await widget.chat.deleteMessagesForEveryone(
        threadId: widget.thread.id,
        messageIds: messageIds,
        senderUid: widget.currentUser.uid,
      );

      if (mounted) {
        final skipped = messageIds.length - deletedCount;
        String message = '$deletedCount message${deletedCount > 1 ? 's' : ''} deleted for everyone';
        if (skipped > 0) {
          message += ' ($skipped skipped - not your messages)';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  /// Builds a WhatsApp-style call message bubble with appropriate icons.
  Widget _buildCallMessageBubble({
    required BuildContext context,
    required FirestoreMessage message,
    required bool isMe,
    required ThemeData theme,
  }) {
    // Determine call icon and color based on status and direction
    IconData callIcon;
    Color iconColor;
    String statusText;

    final isOutgoing = message.fromUid == widget.currentUser.uid;
    
    switch (message.callStatus) {
      case CallMessageStatus.completed:
        callIcon = isOutgoing ? Icons.call_made : Icons.call_received;
        iconColor = Colors.green;
        statusText = 'Voice call · ${message.formattedCallDuration ?? '0:00'}';
        break;
      case CallMessageStatus.missed:
        callIcon = Icons.call_missed;
        iconColor = Colors.red;
        statusText = isOutgoing ? 'No answer' : 'Missed voice call';
        break;
      case CallMessageStatus.declined:
        callIcon = Icons.call_end;
        iconColor = Colors.red;
        statusText = isOutgoing ? 'Call declined' : 'Declined voice call';
        break;
      case CallMessageStatus.cancelled:
        callIcon = Icons.call_end;
        iconColor = Colors.orange;
        statusText = 'Cancelled call';
        break;
      default:
        callIcon = Icons.call;
        iconColor = theme.colorScheme.primary;
        statusText = 'Voice call';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Call icon with background
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  callIcon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Call info
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(message.sentAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Call back button (for missed/declined calls)
              if (message.callStatus == CallMessageStatus.missed ||
                  message.callStatus == CallMessageStatus.declined)
                IconButton(
                  onPressed: () => _startVoiceCall(context),
                  icon: Icon(
                    Icons.call,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: 'Call back',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
