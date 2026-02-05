import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 20});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage:
          user.profileImageBytes == null ? null : MemoryImage(Uint8List.fromList(user.profileImageBytes!)),
      child: user.profileImageBytes == null ? const Icon(Icons.person) : null,
    );
  }
}

class UserStartTile extends StatelessWidget {
  const UserStartTile({super.key, required this.user, required this.onTap});

  final AppUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: UserAvatar(user: user),
        title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.otherUser,
    required this.lastMessageText,
    required this.unread,
    required this.onTap,
  });

  final AppUser otherUser;
  final String? lastMessageText;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = (lastMessageText != null && lastMessageText!.isNotEmpty) 
        ? lastMessageText! 
        : 'Say hi…';

    return Card(
      elevation: 0,
      child: ListTile(
        leading: UserAvatar(user: otherUser),
        title: Text(otherUser.username, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: unread > 0
            ? CircleAvatar(
                radius: 12,
                child: Text(
                  unread.toString(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
