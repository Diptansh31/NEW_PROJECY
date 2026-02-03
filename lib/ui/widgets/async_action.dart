import 'dart:async';

import 'package:flutter/material.dart';

/// Runs an async UI action and shows errors as a SnackBar instead of throwing.
Future<void> runAsyncAction(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  try {
    await action();
    if (successMessage != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    }
  } catch (e, st) {
    // Keep the original error visible in debug console.
    // On web, Firebase errors often get wrapped; stack is still useful.
    // ignore: avoid_print
    print('Async action failed: $e\n$st');

    if (!context.mounted) return;

    final msg = _bestErrorMessage(e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

String _bestErrorMessage(Object e) {
  final s = e.toString();
  // Prefer a short message if the error is wrapped.
  // Common Firebase web wrapper includes "[cloud_firestore/permission-denied]" etc.
  final idx = s.indexOf(']');
  if (s.contains('[cloud_firestore/') && idx != -1) {
    return s.substring(0, idx + 1) + s.substring(idx + 1).trim();
  }
  return s;
}

/// Helper to call a Future without awaiting in a button handler.
void fireAndForget(Future<void> future) {
  unawaited(future);
}
