import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../posts/post_models.dart';

class PostImage extends StatelessWidget {
  const PostImage({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final directUrl = post.imageUrl;
    if (directUrl != null && directUrl.isNotEmpty) {
      return Image.network(directUrl, fit: BoxFit.cover);
    }

    final path = post.imagePath;
    if (path == null || path.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Text('Image missing')),
      );
    }

    return FutureBuilder<String>(
      future: FirebaseStorage.instance.ref(path).getDownloadURL(),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null) {
          return Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return Image.network(url, fit: BoxFit.cover);
      },
    );
  }
}
