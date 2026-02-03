import 'dart:async';

import 'package:flutter/material.dart';

/// Small helper widget for consistent friend/request button states.
class FriendActionButton extends StatelessWidget {
  const FriendActionButton({
    super.key,
    required this.areFriends,
    required this.hasOutgoing,
    required this.hasIncoming,
    required this.onAdd,
    required this.onAccept,
    this.dense = false,
  });

  final bool areFriends;
  final bool hasOutgoing;
  final bool hasIncoming;
  final Future<void> Function() onAdd;
  final Future<void> Function() onAccept;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (areFriends) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.check),
        label: Text(dense ? 'Friends' : 'Already friends'),
      );
    }

    if (hasIncoming) {
      return FilledButton.icon(
        onPressed: () async => onAccept(),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(dense ? 'Accept' : 'Accept request'),
      );
    }

    if (hasOutgoing) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top),
        label: Text(dense ? 'Requested' : 'Request sent'),
      );
    }

    return FilledButton.icon(
      onPressed: () async => onAdd(),
      icon: const Icon(Icons.person_add),
      label: Text(dense ? 'Add' : 'Add friend'),
    );
  }
}
