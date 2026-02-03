import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'cloudinary_uploader.dart';
import 'post_models.dart';

class FirestorePostsController {
  FirestorePostsController({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    CloudinaryUploader? cloudinary,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _cloudinary = cloudinary ??
            CloudinaryUploader(
              cloudName: 'dlouee0os',
              unsignedUploadPreset: 'vibeu_posts',
            );

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final CloudinaryUploader _cloudinary;

  Stream<List<Post>> postsStream({int limit = 50}) {
    return _db
        .collection('posts')
        .where('status', isEqualTo: 'PUBLISHED')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Post.fromDoc).toList(growable: false));
  }

  Stream<List<Post>> userPostsStream({required String uid, int limit = 200}) {
    return _db
        .collection('posts')
        .where('createdByUid', isEqualTo: uid)
        .where('status', isEqualTo: 'PUBLISHED')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Post.fromDoc).toList(growable: false));
  }

  Future<String> createPost({
    required String createdByUid,
    required String caption,
    required Uint8List imageBytes,
    required String imageExtension,
  }) async {
    final postRef = _db.collection('posts').doc();
    final postId = postRef.id;

    // Upload to Cloudinary (unsigned preset).
    final upload = await _cloudinary.uploadImageBytes(
      bytes: imageBytes,
      filename: 'post_$postId.${imageExtension.toLowerCase()}',
      folder: 'posts',
    );

    await postRef.set({
      'createdByUid': createdByUid,
      'caption': caption.trim(),
      'imageUrl': upload.secureUrl,
      'imagePublicId': upload.publicId,
      'imageProvider': 'CLOUDINARY',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'PUBLISHED',
      'reportCount': 0,
      'likeCount': 0,
    });

    return postId;
  }

  Future<void> deletePost({required String postId, required String requesterUid}) async {
    final postRef = _db.collection('posts').doc(postId);
    final snap = await postRef.get();
    final data = snap.data();
    if (data == null) return;

    if (data['createdByUid'] != requesterUid) {
      throw StateError('Not allowed');
    }

    final provider = (data['imageProvider'] as String?) ?? 'FIREBASE_STORAGE';
    final imagePath = data['imagePath'] as String?;

    await postRef.delete();

    // Best-effort cleanup. Cloudinary deletion requires a signed destroy call; we
    // intentionally skip it for unsigned uploads.
    if (provider == 'FIREBASE_STORAGE' && imagePath != null) {
      await _storage.ref(imagePath).delete();
    }
  }

  Stream<bool> isLikedStream({required String postId, required String uid}) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleLike({
    required String postId,
    required String uid,
  }) async {
    final postRef = _db.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);

    await _db.runTransaction((tx) async {
      final postSnap = await tx.get(postRef);
      final currentCount = (postSnap.data()?['likeCount'] as num?)?.toInt() ?? 0;

      final likeSnap = await tx.get(likeRef);
      if (likeSnap.exists) {
        tx.delete(likeRef);

        // Clamp to 0 in case of any inconsistency.
        final next = currentCount - 1;
        tx.set(postRef, {
          'likeCount': next < 0 ? 0 : next,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        tx.set(likeRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(postRef, {
          'likeCount': currentCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> reportPost({
    required String postId,
    required String reportedByUid,
    required String reason,
    String? details,
  }) async {
    final postRef = _db.collection('posts').doc(postId);
    final reportRef = postRef.collection('reports').doc();

    await _db.runTransaction((tx) async {
      tx.set(reportRef, {
        'reportedByUid': reportedByUid,
        'reason': reason,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(postRef, {
        'reportCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    // Auto-flag after 5 reports (can tune later).
    final updated = await postRef.get();
    final rc = (updated.data()?['reportCount'] as int?) ?? 0;
    if (rc >= 5) {
      await postRef.set({
        'status': 'AUTO_FLAGGED',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

}
