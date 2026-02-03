import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../posts/firestore_posts_controller.dart';
import '../../posts/post_models.dart';
import '../widgets/async_action.dart';
import 'post_image_widget.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentUid,
    required this.posts,
  });

  final Post post;
  final String currentUid;
  final FirestorePostsController posts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(post.createdByUid).snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data();
                final username = (data?['username'] as String?) ?? 'Unknown';

                MemoryImage? avatar;
                final b64 = data?['profileImageB64'] as String?;
                if (b64 != null && b64.isNotEmpty) {
                  try {
                    avatar = MemoryImage(base64Decode(b64));
                  } catch (_) {
                    avatar = null;
                  }
                }

                final initial = (username.isNotEmpty ? username.substring(0, 1) : '?').toUpperCase();

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: avatar,
                      child: avatar == null ? Text(initial) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (post.createdByUid == currentUid)
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => runAsyncAction(
                          context,
                          () => posts.deletePost(postId: post.id, requesterUid: currentUid),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: PostImage(post: post),
              ),
            ),
            const SizedBox(height: 10),
            if (post.caption.isNotEmpty) Text(post.caption),
            const SizedBox(height: 8),
            Row(
              children: [
                StreamBuilder<bool>(
                  stream: posts.isLikedStream(postId: post.id, uid: currentUid),
                  builder: (context, snap) {
                    final liked = snap.data ?? false;
                    return IconButton(
                      tooltip: liked ? 'Unlike' : 'Like',
                      onPressed: () => runAsyncAction(
                        context,
                        () => posts.toggleLike(postId: post.id, uid: currentUid),
                      ),
                      icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                      color: liked ? Colors.red : null,
                    );
                  },
                ),
                Text('${post.likeCount}'),
                const SizedBox(width: 12),
                Text(
                  'Reports: ${post.reportCount}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Report',
                  onPressed: () => _showReportDialog(context),
                  icon: const Icon(Icons.flag_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final reasons = <String>['HARASSMENT', 'NUDITY', 'OTHER'];
    String selected = reasons.first;
    final details = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selected,
                items: [for (final r in reasons) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => selected = v ?? reasons.first,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: details,
                decoration: const InputDecoration(labelText: 'Details (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                fireAndForget(
                  runAsyncAction(
                    context,
                    () => posts.reportPost(
                      postId: post.id,
                      reportedByUid: currentUid,
                      reason: selected,
                      details: details.text.trim().isEmpty ? null : details.text.trim(),
                    ),
                    successMessage: 'Reported',
                  ),
                );
              },
              child: const Text('Report'),
            ),
          ],
        );
      },
    ).whenComplete(details.dispose);
  }
}
