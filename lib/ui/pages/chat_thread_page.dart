import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../chat/firestore_chat_models.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.currentUser,
    required this.otherUser,
    required this.thread,
    required this.chat,
    required this.social,
  });

  final AppUser currentUser;
  final AppUser otherUser;
  final FirestoreChatThread thread;
  final FirestoreChatController chat;
  final FirestoreSocialGraphController social;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final _controller = TextEditingController();

  FirestoreMessage? _replyTo;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

        return Scaffold(
          appBar: AppBar(title: Text(widget.otherUser.username)),
          body: Column(
            children: [
              if (!areFriends)
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

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onLongPress: () {
                                setState(() {
                                  _replyTo = m;
                                });
                              },
                              child: Card(
                                elevation: 0,
                                color: isMe
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                                color: Theme.of(context).colorScheme.primary,
                                                width: 3,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            m.replyToText!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ),
                                      Text(text),
                                    ],
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
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Replying',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(fontWeight: FontWeight.w800),
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
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: areFriends,
                          decoration: const InputDecoration(
                            hintText: 'Message…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: areFriends ? (_) => _send() : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: areFriends ? _send : null,
                        icon: const Icon(Icons.send),
                      ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
