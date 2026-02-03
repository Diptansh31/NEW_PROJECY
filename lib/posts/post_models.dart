import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Post {
  const Post({
    required this.id,
    required this.createdByUid,
    required this.caption,
    required this.createdAt,
    required this.status,
    required this.reportCount,
    required this.likeCount,
    this.imagePath,
    this.imageUrl,
    this.imageProvider,
  });

  final String id;
  final String createdByUid;
  final String caption;

  /// Legacy: Firebase Storage path.
  final String? imagePath;

  /// Preferred: fully-qualified URL (Cloudinary secure_url).
  final String? imageUrl;

  /// 'CLOUDINARY' or 'FIREBASE_STORAGE' (legacy default).
  final String? imageProvider;

  final DateTime createdAt;
  final String status;
  final int reportCount;
  final int likeCount;

  static Post fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Post(
      id: doc.id,
      createdByUid: d['createdByUid'] as String,
      caption: (d['caption'] as String?) ?? '',
      imagePath: d['imagePath'] as String?,
      imageUrl: d['imageUrl'] as String?,
      imageProvider: d['imageProvider'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: (d['status'] as String?) ?? 'PUBLISHED',
      reportCount: (d['reportCount'] as int?) ?? 0,
      likeCount: (d['likeCount'] as int?) ?? 0,
    );
  }
}
