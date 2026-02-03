import 'package:flutter/material.dart';

import '../../posts/post_models.dart';
import 'post_image_widget.dart';

class MyPostDetailPage extends StatelessWidget {
  const MyPostDetailPage({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: PostImage(post: post),
        ),
      ),
    );
  }
}
