import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Device-local encrypted storage for Sathi's OCR text, drafts, journey notes,
/// and encrypted copies of documents selected into the app.
///
/// The AES-256-GCM key is held in platform secure storage (Keychain/Keystore).
/// Source files remain where the user stored them; Sathi creates a separately
/// encrypted app-private copy from the selected file bytes. This class makes no
/// network requests.
class LocalPrivateVault {
  LocalPrivateVault({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _keyName = 'sathi_private_vault_aes256_key_v1';
  static const _vaultFileName = 'sathi_private_vault_v1.enc';
  static const _attachmentsDirectoryName = 'sathi_encrypted_attachments';
  static const _maxAttachmentBytes = 25 * 1024 * 1024;

  final FlutterSecureStorage _secureStorage;
  final AesGcm _cipher = AesGcm.with256bits();
  // All vault instances in this process point at the same encrypted snapshot.
  // A shared queue prevents a claim-state write and a RAG-cache write from
  // racing and overwriting each other's JSON fields.
  static Future<void> _writeTail = Future<void>.value();

  Future<Directory> _rootDirectory() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/sathi_private_vault');
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  Future<File> _snapshotFile() async =>
      File('${(await _rootDirectory()).path}/$_vaultFileName');

  Future<Directory> _attachmentsDirectory() async {
    final directory = Directory(
      '${(await _rootDirectory()).path}/$_attachmentsDirectoryName',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  String _safeId(String id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  Future<File> _attachmentFile(String id) async =>
      File('${(await _attachmentsDirectory()).path}/${_safeId(id)}.enc');

  Future<SecretKey> _getOrCreateKey() async {
    final encoded = await _secureStorage.read(key: _keyName);
    if (encoded != null && encoded.isNotEmpty) {
      final keyBytes = base64Decode(encoded);
      if (keyBytes.length != 32) {
        throw StateError(
          'Sathi local-vault key is invalid. Do not delete vault files manually; use the local-data reset flow.',
        );
      }
      return SecretKey(keyBytes);
    }

    // Never silently create a new key over existing encrypted data; doing so
    // would make the previous data permanently unreadable without warning.
    final snapshot = await _snapshotFile();
    final attachmentDirectory = await _attachmentsDirectory();
    final hasAttachments = !(await attachmentDirectory.list().isEmpty);
    if (await snapshot.exists() || hasAttachments) {
      throw StateError(
        'Sathi could not find the key for your encrypted local data. Your files were not uploaded. Restore the device secure backup or reset the local vault after exporting anything you can still open.',
      );
    }

    final generated = await _cipher.newSecretKey();
    final bytes = await generated.extractBytes();
    await _secureStorage.write(key: _keyName, value: base64Encode(bytes));
    return SecretKey(bytes);
  }

  Future<Map<String, dynamic>> readSnapshot() async {
    await _writeTail.catchError((Object _) {});
    return _readSnapshotFromDisk();
  }

  Future<Map<String, dynamic>> _readSnapshotFromDisk() async {
    final file = await _snapshotFile();
    if (!await file.exists()) {
      return <String, dynamic>{
        'version': 1,
        'documents': <Map<String, dynamic>>[],
        'timeline': <Map<String, dynamic>>[],
        'appealDraft': '',
        'reconsiderationMarkedSubmitted': false,
      };
    }
    final clearBytes = await _decryptBytes(await file.readAsBytes());
    final decoded = jsonDecode(utf8.decode(clearBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Sathi local-vault snapshot is not valid JSON.',
      );
    }
    return decoded;
  }

  /// Serializes a shallow merge into the encrypted snapshot. Used by features
  /// such as the local RAG vector cache so normal claim-state writes do not
  /// erase unrelated encrypted metadata.
  Future<void> mergeSnapshot(Map<String, dynamic> updates) {
    final next = _writeTail.catchError((Object _) {}).then((_) async {
      final current = await _readSnapshotFromDisk();
      final merged = <String, dynamic>{...current, ...updates};
      final encoded = jsonEncode(merged);
      final file = await _snapshotFile();
      await file.writeAsBytes(
        await _encryptBytes(utf8.encode(encoded)),
        flush: true,
      );
    });
    _writeTail = next;
    return next;
  }

  Future<void> saveSnapshot(Map<String, dynamic> snapshot) {
    // Capture a JSON copy now so a later state mutation cannot change this write.
    final encoded = jsonEncode(snapshot);
    final next = _writeTail.catchError((Object _) {}).then((_) async {
      final file = await _snapshotFile();
      await file.writeAsBytes(
        await _encryptBytes(utf8.encode(encoded)),
        flush: true,
      );
    });
    _writeTail = next;
    return next;
  }

  /// Encrypts picker-provided bytes into app-private storage.
  /// Android/iOS document pickers may return content URIs or cloud-backed
  /// files, so reading the bytes is more reliable than persisting a path.
  Future<void> saveAttachmentBytes({
    required String id,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty) throw StateError('The selected file is empty.');
    if (bytes.length > _maxAttachmentBytes) {
      throw StateError('This prototype supports files up to 25 MB.');
    }
    final encrypted = await _encryptBytes(bytes);
    final destination = await _attachmentFile(id);
    await destination.writeAsBytes(encrypted, flush: true);
  }

  /// Encrypt a selected source file into app-private storage.
  Future<void> saveAttachment({
    required String id,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError(
        'The selected file is no longer available. Please attach it again.',
      );
    }
    final size = await source.length();
    if (size <= 0) throw StateError('The selected file is empty.');
    if (size > _maxAttachmentBytes) {
      throw StateError(
        'This prototype supports files up to 25 MB. Select a smaller file.',
      );
    }
    final bytes = await source.readAsBytes();
    final encrypted = await _encryptBytes(bytes);
    final destination = await _attachmentFile(id);
    await destination.writeAsBytes(encrypted, flush: true);
  }

  Future<bool> hasAttachment(String id) async =>
      (await _attachmentFile(id)).exists();

  /// Decrypts a short-lived copy for on-device OCR. The caller MUST delete the
  /// returned temporary file in a finally block as soon as OCR has completed.
  Future<String?> materializeAttachmentForOcr({
    required String id,
    required String fileName,
  }) async {
    final encryptedFile = await _attachmentFile(id);
    if (!await encryptedFile.exists()) return null;
    final bytes = await _decryptBytes(await encryptedFile.readAsBytes());
    final temp = await getTemporaryDirectory();
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'bin';
    final tempPath =
        '${temp.path}/sathi_ocr_${_safeId(id)}_${DateTime.now().microsecondsSinceEpoch}.$extension';
    await File(tempPath).writeAsBytes(bytes, flush: true);
    return tempPath;
  }

  Future<void> deleteAttachment(String id) async {
    final file = await _attachmentFile(id);
    if (await file.exists()) await file.delete();
  }

  Future<void> clearAll() {
    final next = _writeTail.catchError((Object _) {}).then((_) async {
      final root = await _rootDirectory();
      if (await root.exists()) await root.delete(recursive: true);
      await _secureStorage.delete(key: _keyName);
    });
    _writeTail = next;
    return next;
  }

  Future<List<int>> _encryptBytes(List<int> clearBytes) async {
    final secretKey = await _getOrCreateKey();
    final box = await _cipher.encrypt(clearBytes, secretKey: secretKey);
    return utf8.encode(
      jsonEncode({
        'version': 1,
        'nonce': base64Encode(box.nonce),
        'cipherText': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      }),
    );
  }

  Future<List<int>> _decryptBytes(List<int> encodedBytes) async {
    final envelope = jsonDecode(utf8.decode(encodedBytes));
    if (envelope is! Map<String, dynamic> || envelope['version'] != 1) {
      throw const FormatException(
        'Sathi encrypted local file has an unsupported format.',
      );
    }
    final secretKey = await _getOrCreateKey();
    final box = SecretBox(
      base64Decode(envelope['cipherText'] as String),
      nonce: base64Decode(envelope['nonce'] as String),
      mac: Mac(base64Decode(envelope['mac'] as String)),
    );
    return _cipher.decrypt(box, secretKey: secretKey);
  }
}
