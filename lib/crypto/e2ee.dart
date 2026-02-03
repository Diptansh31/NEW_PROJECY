import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// E2EE helper:
/// - Each user has a long-term X25519 key pair.
/// - Private key is stored locally in secure storage.
/// - Public key is stored in Firestore (handled by caller).
/// - For each chat thread, derive a shared secret via X25519, then derive an AES-GCM key using HKDF.
class E2ee {
  E2ee({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKeyPrefix = 'vibeu.e2ee.x25519.privateKeyB64.';

  final FlutterSecureStorage _storage;

  /// Returns the user’s X25519 keypair, generating/storing it if missing.
  ///
  /// We store a 32-byte seed (not the raw private key) so we can deterministically
  /// recreate both private + public keys later.
  Future<KeyPair> getOrCreateIdentityKeyPair({required String uid}) async {
    final keyName = '$_storageKeyPrefix$uid';
    final existing = await _storage.read(key: keyName);

    final algorithm = X25519();

    if (existing != null) {
      final seed = base64Decode(existing);
      return algorithm.newKeyPairFromSeed(seed);
    }

    final rnd = Random.secure();
    final seed = List<int>.generate(32, (_) => rnd.nextInt(256), growable: false);
    final keyPair = await algorithm.newKeyPairFromSeed(seed);

    await _storage.write(key: keyName, value: base64Encode(seed));
    return keyPair;
  }

  Future<String> publicKeyB64(KeyPair keyPair) async {
    final pub = await keyPair.extractPublicKey() as SimplePublicKey;
    return base64Encode(pub.bytes);
  }

  /// Derive a stable conversation key for (myPrivate, theirPublic).
  ///
  /// threadId is included as HKDF "info" to avoid key reuse.
  Future<SecretKey> deriveThreadKey({
    required KeyPair myIdentityKeyPair,
    required SimplePublicKey theirPublicKey,
    required String threadId,
  }) async {
    final algorithm = X25519();
    final shared = await algorithm.sharedSecretKey(
      keyPair: myIdentityKeyPair,
      remotePublicKey: theirPublicKey,
    );

    // HKDF-SHA256 -> 32 bytes key for AES-256-GCM.
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );

    return hkdf.deriveKey(
      secretKey: shared,
      info: utf8.encode('vibeu:$threadId'),
      nonce: const <int>[],
    );
  }

  /// Encrypt plaintext with AES-GCM.
  Future<Map<String, dynamic>> encrypt({
    required SecretKey key,
    required String plaintext,
    required List<int> aad,
  }) async {
    final algo = AesGcm.with256bits();
    final nonce = algo.newNonce();

    final secretBox = await algo.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
      aad: aad,
    );

    return {
      'ciphertextB64': base64Encode(secretBox.cipherText),
      'nonceB64': base64Encode(secretBox.nonce),
      'macB64': base64Encode(secretBox.mac.bytes),
    };
  }

  Future<String> decrypt({
    required SecretKey key,
    required String ciphertextB64,
    required String nonceB64,
    required String macB64,
    required List<int> aad,
  }) async {
    final algo = AesGcm.with256bits();
    final secretBox = SecretBox(
      base64Decode(ciphertextB64),
      nonce: base64Decode(nonceB64),
      mac: Mac(base64Decode(macB64)),
    );

    final clear = await algo.decrypt(
      secretBox,
      secretKey: key,
      aad: aad,
    );

    return utf8.decode(clear);
  }

  SimplePublicKey parsePublicKeyB64(String b64) =>
      SimplePublicKey(base64Decode(b64), type: KeyPairType.x25519);
}
