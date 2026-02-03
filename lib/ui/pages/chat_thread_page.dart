import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../chat/firestore_chat_models.dart';
import '../../social/social_graph_controller.dart';

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
  final SocialGraphController social;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = widget.currentUser.email;
    final otherEmail = widget.otherUser.email;

    final areFriends = widget.social.areFriends(currentEmail, otherEmail);

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
            child: StreamBuilder<List<FirestoreEncryptedMessage>>(
              stream: widget.chat.encryptedMessagesStream(threadId: widget.thread.id),
              builder: (context, snap) {
                final encrypted = snap.data;
                if (encrypted == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                return FutureBuilder<List<_UiMessage>>(
                  future: _decryptAll(encrypted),
                  builder: (context, decSnap) {
                    final messages = decSnap.data;
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

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Card(
                              elevation: 0,
                              color: isMe
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Text(m.text),
                              ),
                            ),
                          ),
                        );
                      },
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
              child: Row(
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
            ),
          ),
        ],
      ),
    );
  }

  Future<List<_UiMessage>> _decryptAll(List<FirestoreEncryptedMessage> encrypted) async {
    final out = <_UiMessage>[];

    for (final m in encrypted) {
      try {
        final text = await widget.chat.decryptMessage(
          threadId: widget.thread.id,
          message: m,
          myUid: widget.currentUser.uid,
          otherUid: widget.otherUser.uid,
        );
        out.add(_UiMessage(fromUid: m.fromUid, text: text));
      } catch (_) {
        out.add(_UiMessage(fromUid: m.fromUid, text: '[Unable to decrypt]'));
      }
    }

    return out;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    await widget.chat.sendEncryptedMessage(
      threadId: widget.thread.id,
      fromUid: widget.currentUser.uid,
      fromEmail: widget.currentUser.email,
      toUid: widget.otherUser.uid,
      toEmail: widget.otherUser.email,
      plaintext: text,
    );
  }
}

class _UiMessage {
  const _UiMessage({required this.fromUid, required this.text});

  final String fromUid;
  final String text;
}
