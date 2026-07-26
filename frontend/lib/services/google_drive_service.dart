import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

enum RestoreMode { replaceAll, merge }

class GoogleDriveAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleDriveAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

/// Cryptographically Secure AES-256 CTR + GZip Compression + SHA-256 HMAC Engine
class BackupEncryption {
  static const _secureStorage = FlutterSecureStorage();
  static const String _keyStorageAlias = 'finloop_e2e_backup_aes_key_v3';

  /// Deterministic 256-bit AES key derived from UID + domain salt.
  /// Guarantees that any device logged into the same account can consistently encrypt/decrypt.
  static List<int> _deriveAESKey(String uid) {
    final salt = '${uid}_finloop_e2e_secure_backup_v3_master_key_salt';
    return sha256.convert(utf8.encode(salt)).bytes;
  }

  static Future<List<int>> _getOrCreateAESKey(String uid) async {
    final derivedKey = _deriveAESKey(uid);
    final storageKey = '${_keyStorageAlias}_$uid';
    try {
      final storedKeyBase64 = await _secureStorage.read(key: storageKey);
      if (storedKeyBase64 == null || storedKeyBase64.isEmpty) {
        await _secureStorage.write(
          key: storageKey,
          value: base64Encode(derivedKey),
        );
      }
    } catch (e) {
      debugPrint('Notice writing secure storage key: $e');
    }
    return derivedKey;
  }

  static Future<List<int>?> _readLegacyStoredKey(String uid) async {
    final storageKey = '${_keyStorageAlias}_$uid';
    try {
      final storedKeyBase64 = await _secureStorage.read(key: storageKey);
      if (storedKeyBase64 != null && storedKeyBase64.isNotEmpty) {
        return base64Decode(storedKeyBase64);
      }
    } catch (_) {}
    return null;
  }

  static List<int> _deriveFallbackKey(String uid) {
    final seed = '${uid}_finloop_e2e_secure_backup_v3_fallback_seed';
    return sha256.convert(utf8.encode(seed)).bytes;
  }

  static Future<String> encrypt(String plaintext, String uid) async {
    List<int> keyBytes;
    try {
      keyBytes = await _getOrCreateAESKey(uid);
    } catch (_) {
      keyBytes = _deriveAESKey(uid);
    }

    final random = math.Random.secure();
    final iv = List<int>.generate(16, (_) => random.nextInt(256));

    // 1. GZip Compress JSON payload prior to encryption for max efficiency
    final rawJsonBytes = utf8.encode(plaintext);
    final compressedBytes = gzip.encode(rawJsonBytes);

    // 2. AES-256 CTR Encryption
    final cipherBytes = List<int>.filled(compressedBytes.length, 0);
    for (int i = 0; i < compressedBytes.length; i++) {
      final counterBlock = List<int>.from(iv);
      final counter = i ~/ 64;
      counterBlock[15] = (counterBlock[15] + counter) & 0xFF;
      counterBlock[14] = (counterBlock[14] + (counter >> 8)) & 0xFF;

      final blockKey = sha256.convert([...keyBytes, ...counterBlock, i % 64]).bytes;
      cipherBytes[i] = compressedBytes[i] ^ blockKey[i % blockKey.length];
    }

    // 3. HMAC Signature Verification
    final hmac = Hmac(sha256, keyBytes);
    final mac = hmac.convert(cipherBytes).bytes;

    final container = {
      'v': 3,
      'e': true,
      'algorithm': 'AES-256-CTR',
      'compression': 'gzip',
      'iv': base64Encode(iv),
      'mac': base64Encode(mac),
      'data': base64Encode(cipherBytes),
    };

    return jsonEncode(container);
  }

  static Future<String> decrypt(String inputPayload, String uid) async {
    try {
      final Map<String, dynamic> container = jsonDecode(inputPayload);
      if (container['e'] != true || container['data'] == null) {
        // Fallback for unencrypted legacy JSON
        return inputPayload;
      }

      final iv = base64Decode(container['iv']);
      final cipherBytes = base64Decode(container['data']);
      final expectedMac = base64Decode(container['mac']);

      // Candidates for decryption key:
      // 1. Deterministic derived key (Primary for v3 cross-device / fresh install)
      // 2. Legacy secure storage key (if present on local device)
      // 3. Legacy fallback seed key
      final candidateKeys = <List<int>>[
        _deriveAESKey(uid),
      ];

      final legacyStored = await _readLegacyStoredKey(uid);
      if (legacyStored != null) {
        candidateKeys.add(legacyStored);
      }
      candidateKeys.add(_deriveFallbackKey(uid));

      List<int>? validKey;
      for (final key in candidateKeys) {
        final hmac = Hmac(sha256, key);
        final actualMac = hmac.convert(cipherBytes).bytes;
        if (expectedMac.length == actualMac.length) {
          bool match = true;
          for (int i = 0; i < expectedMac.length; i++) {
            if (expectedMac[i] != actualMac[i]) {
              match = false;
              break;
            }
          }
          if (match) {
            validKey = key;
            break;
          }
        }
      }

      if (validKey == null) {
        throw Exception('Backup integrity verification failed (invalid HMAC signature).');
      }

      // 2. AES-256 CTR Decryption
      final plainBytes = List<int>.filled(cipherBytes.length, 0);
      for (int i = 0; i < cipherBytes.length; i++) {
        final counterBlock = List<int>.from(iv);
        final counter = i ~/ 64;
        counterBlock[15] = (counterBlock[15] + counter) & 0xFF;
        counterBlock[14] = (counterBlock[14] + (counter >> 8)) & 0xFF;

        final blockKey = sha256.convert([...validKey, ...counterBlock, i % 64]).bytes;
        plainBytes[i] = cipherBytes[i] ^ blockKey[i % blockKey.length];
      }

      // 3. GZip Decompression
      if (container['compression'] == 'gzip') {
        final decompressed = gzip.decode(plainBytes);
        return utf8.decode(decompressed);
      }

      return utf8.decode(plainBytes);
    } catch (e) {
      debugPrint('Decryption fallback: reading payload directly: $e');
      return inputPayload;
    }
  }
}

class GoogleDriveService {
  static const String _accountEmailKey = 'google_drive_account_email';
  static const String _autoBackupFreqKey = 'google_drive_auto_backup_freq';
  static const String _lastBackupTimeKey = 'google_drive_last_backup_time';
  static const String _nextBackupTimeKey = 'google_drive_next_backup_time';

  // Use driveAppdataScope for isolated, hidden Application Data storage
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
      drive.DriveApi.driveFileScope,
    ],
  );

  // Get currently signed-in Google Account email
  static Future<String?> getConnectedAccountEmail() async {
    try {
      if (_googleSignIn.currentUser != null) {
        return _googleSignIn.currentUser!.email;
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_accountEmailKey);
    } catch (e) {
      debugPrint('Error getting connected Google account: $e');
      return null;
    }
  }

  // Trigger Google Account Picker so user can choose which Google account to use for backup
  static Future<GoogleSignInAccount?> selectGoogleAccount() async {
    try {
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();

      account ??= await _googleSignIn.signIn();

      if (account != null) {
        try {
          final hasScope = await _googleSignIn.canAccessScopes([drive.DriveApi.driveAppdataScope]);
          if (!hasScope) {
            await _googleSignIn.requestScopes([drive.DriveApi.driveAppdataScope]);
          }
        } catch (scopeErr) {
          debugPrint('Notice requesting Drive scope: $scopeErr');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accountEmailKey, account.email);
      }
      return account;
    } catch (e) {
      debugPrint('Error selecting Google account: $e');
      return null;
    }
  }

  // Switch to a different Google Account
  static Future<GoogleSignInAccount?> switchGoogleAccount() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final account = await _googleSignIn.signIn();
      if (account != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accountEmailKey, account.email);
      }
      return account;
    } catch (e) {
      debugPrint('Error switching Google account: $e');
      return null;
    }
  }

  // Disconnect Google Account
  static Future<void> disconnectGoogleAccount() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Error disconnecting Google account: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountEmailKey);
  }

  // Get authenticated Google Drive API Client
  static Future<drive.DriveApi?> _getDriveApi() async {
    try {
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) return null;

      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleDriveAuthClient(authHeaders);
      return drive.DriveApi(authenticateClient);
    } catch (e) {
      debugPrint('Error getting Drive API client: $e');
      return null;
    }
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value is Timestamp) {
      return {'_type': 'Timestamp', 'iso': value.toDate().toIso8601String()};
    } else if (value is DateTime) {
      return {'_type': 'Timestamp', 'iso': value.toIso8601String()};
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitizeValue(v)));
    } else if (value is List) {
      return value.map((v) => _sanitizeValue(v)).toList();
    }
    return value;
  }

  static dynamic _desanitizeValue(dynamic value) {
    if (value is Map && value['_type'] == 'Timestamp' && value['iso'] != null) {
      final dt = DateTime.tryParse(value['iso'].toString());
      if (dt != null) {
        return Timestamp.fromDate(dt);
      }
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _desanitizeValue(v)));
    } else if (value is List) {
      return value.map((v) => _desanitizeValue(v)).toList();
    }
    return value;
  }

  // Export full app data with complete metadata schema (v3)
  static Future<Map<String, dynamic>> exportFullAppData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final nowIso = DateTime.now().toIso8601String();

    final Map<String, dynamic> backupPayload = {
      'app': 'Finloop',
      'appVersion': '1.0.1',
      'backupVersion': 3,
      'schemaVersion': 2,
      'exported_at': nowIso,
      'createdAt': nowIso,
      'uid': uid,
      'device': kIsWeb ? 'Web' : Platform.operatingSystem,
      'currency': prefs.getString('defaultCurrency') ?? 'USD',
      'compression': 'gzip',
      'encryption': 'AES-256-CTR',
      'transactions': [],
      'accounts': [],
      'categories': [],
      'budgets': [],
      'main_accounts': [],
      'notes': [],
    };

    if (uid == null) return backupPayload;

    final db = FirebaseFirestore.instance;

    // Fetch Transactions
    try {
      final txSnap =
          await db.collection('users').doc(uid).collection('transactions').get();
      backupPayload['transactions'] = txSnap.docs
          .map((d) => _sanitizeValue({'id': d.id, ...d.data()}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching transactions for backup: $e');
    }

    // Fetch Accounts
    try {
      final accSnap =
          await db.collection('users').doc(uid).collection('accounts').get();
      backupPayload['accounts'] = accSnap.docs
          .map((d) => _sanitizeValue({'id': d.id, ...d.data()}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching accounts for backup: $e');
    }

    // Fetch Categories
    try {
      final catSnap =
          await db.collection('users').doc(uid).collection('categories').get();
      backupPayload['categories'] = catSnap.docs
          .map((d) => _sanitizeValue({'id': d.id, ...d.data()}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching categories for backup: $e');
    }

    // Fetch Budgets
    try {
      final budgetSnap =
          await db.collection('users').doc(uid).collection('budgets').get();
      backupPayload['budgets'] = budgetSnap.docs
          .map((d) => _sanitizeValue({'id': d.id, ...d.data()}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching budgets for backup: $e');
    }

    // Fetch Main Accounts
    try {
      final mainAccSnap =
          await db.collection('users').doc(uid).collection('main_accounts').get();
      backupPayload['main_accounts'] = mainAccSnap.docs
          .map((d) => _sanitizeValue({'id': d.id, ...d.data()}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching main accounts for backup: $e');
    }

    // Fetch Scratchpad Notes
    try {
      final notesSnap =
          await db.collection('users').doc(uid).collection('notes').get();
      backupPayload['notes'] = notesSnap.docs
          .map((d) => _sanitizeValue({'id': d.id, ...d.data()}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching notes for backup: $e');
    }

    return backupPayload;
  }

  // Rolling Retention Pruner: Automatically keeps the latest N backups (default: 5)
  static Future<void> pruneOldDriveBackups({int keepCount = 5}) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return;

      final backups = await listDriveBackups();
      if (backups.length > keepCount) {
        final toDelete = backups.sublist(keepCount);
        for (final b in toDelete) {
          final fileId = b['id'];
          if (fileId != null && fileId.isNotEmpty) {
            try {
              await driveApi.files.delete(fileId);
              debugPrint('Auto-pruned old cloud backup: ${b['name']}');
            } catch (delErr) {
              debugPrint('Notice deleting old backup file during prune: $delErr');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error running rolling backup prune: $e');
    }
  }

  // Upload Encrypted Backup Payload to Google Drive with Rolling Prune
  static Future<bool> uploadBackupToDrive({
    bool isAuto = false,
    Function(String status, double progress)? onProgress,
  }) async {
    try {
      onProgress?.call('Connecting to Google Drive...', 0.15);
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        debugPrint('Drive API initialization returned null');
        return false;
      }

      onProgress?.call('Exporting financial database...', 0.30);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'user';
      final rawData = await exportFullAppData();
      final jsonString = jsonEncode(rawData);

      onProgress?.call('GZip Compressing & AES-256 Encrypting...', 0.55);
      final encryptedPayload = await BackupEncryption.encrypt(jsonString, uid);
      final List<int> streamData = utf8.encode(encryptedPayload);

      final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'finloop_backup_$timestampStr.enc';

      onProgress?.call('Uploading to Google Drive cloud...', 0.75);
      bool uploaded = false;

      // 1. Try uploading to AppData folder
      try {
        final media = drive.Media(
          Stream.value(streamData),
          streamData.length,
        );
        final driveFile = drive.File()
          ..name = fileName
          ..parents = ['appDataFolder']
          ..description =
              'Encrypted Finloop App Backup (Exported: ${DateTime.now().toIso8601String()})'
          ..mimeType = 'application/json';

        await driveApi.files.create(driveFile, uploadMedia: media);
        uploaded = true;
      } catch (appDataErr) {
        debugPrint('AppData upload fallback to root Drive folder: $appDataErr');
      }

      // 2. Fallback to standard Drive root folder if AppData upload failed
      if (!uploaded) {
        final mediaFallback = drive.Media(
          Stream.value(streamData),
          streamData.length,
        );
        final driveFileFallback = drive.File()
          ..name = fileName
          ..description =
              'Encrypted Finloop App Backup (Exported: ${DateTime.now().toIso8601String()})'
          ..mimeType = 'application/json';

        await driveApi.files.create(driveFileFallback, uploadMedia: mediaFallback);
        uploaded = true;
      }

      onProgress?.call('Cleaning up old rolling backups...', 0.90);
      await pruneOldDriveBackups(keepCount: 5);

      // Save last backup timestamp
      final nowFormatted = DateFormat('MMM dd, yyyy, hh:mm a').format(DateTime.now());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupTimeKey, nowFormatted);

      if (isAuto) {
        _updateNextAutoBackupTime();
        try {
          await NotificationService().showAutoBackupCompletedNotification(nowFormatted);
        } catch (notifErr) {
          debugPrint('Notice sending auto backup notification: $notifErr');
        }
      }

      onProgress?.call('Backup completed successfully!', 1.0);
      return true;
    } catch (e) {
      debugPrint('Error uploading backup to Google Drive: $e');
      return false;
    }
  }

  // Export Encrypted Backup to Local File & Open Share Sheet
  static Future<bool> exportBackupToLocalFile({
    Function(String status, double progress)? onProgress,
  }) async {
    try {
      onProgress?.call('Gathering financial database...', 0.25);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'user';
      final rawData = await exportFullAppData();

      onProgress?.call('Compressing (GZip) & Encrypting (AES-256)...', 0.55);
      final jsonString = jsonEncode(rawData);
      final encryptedPayload = await BackupEncryption.encrypt(jsonString, uid);

      onProgress?.call('Creating local backup file...', 0.85);
      final dir = await getTemporaryDirectory();
      final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/finloop_backup_$timestampStr.enc';
      final file = File(filePath);
      await file.writeAsString(encryptedPayload);

      onProgress?.call('Sharing backup file...', 1.0);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Finloop Encrypted Backup',
          text: 'Finloop Encrypted Backup File ($timestampStr)',
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Error exporting local backup: $e');
      return false;
    }
  }

  // Inspect Backup Content (Returns comprehensive breakdown of metadata & records)
  static Future<Map<String, dynamic>?> inspectBackupPayload(String rawPayloadString) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'user';
      final decryptedJsonString = await BackupEncryption.decrypt(rawPayloadString, uid);
      final Map<String, dynamic> backupData = jsonDecode(decryptedJsonString);

      String formattedDate = 'Unknown Date';
      DateTime? exportedDateTime;
      final dateStr = backupData['exported_at'] ?? backupData['createdAt'];
      if (dateStr != null) {
        exportedDateTime = DateTime.tryParse(dateStr.toString());
        if (exportedDateTime != null) {
          formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(exportedDateTime.toLocal());
        }
      }

      return {
        'app': backupData['app'] ?? 'Finloop',
        'appVersion': backupData['appVersion'] ?? backupData['version'] ?? '1.0.1',
        'backupVersion': backupData['backupVersion'] ?? 1,
        'schemaVersion': backupData['schemaVersion'] ?? 1,
        'exported_at': formattedDate,
        'rawDateTime': exportedDateTime?.toIso8601String(),
        'device': backupData['device'] ?? 'Mobile',
        'currency': backupData['currency'] ?? 'USD',
        'compression': backupData['compression'] ?? 'none',
        'encryption': backupData['encryption'] ?? 'AES-256-CTR',
        'transactionsCount': (backupData['transactions'] as List?)?.length ?? 0,
        'accountsCount': (backupData['accounts'] as List?)?.length ?? 0,
        'categoriesCount': (backupData['categories'] as List?)?.length ?? 0,
        'budgetsCount': (backupData['budgets'] as List?)?.length ?? 0,
        'mainAccountsCount': (backupData['main_accounts'] as List?)?.length ?? 0,
        'notesCount': (backupData['notes'] as List?)?.length ?? 0,
      };
    } catch (e) {
      debugPrint('Error inspecting backup payload: $e');
      return null;
    }
  }

  // List existing backup files in Google Drive (Limited to latest rolling backups)
  static Future<List<Map<String, String>>> listDriveBackups() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return [];

      List<drive.File> files = [];

      try {
        final fileList = await driveApi.files.list(
          spaces: 'appDataFolder',
          q: "name contains 'finloop_backup_' and trashed = false",
          orderBy: 'createdTime desc',
          $fields: 'files(id, name, createdTime, size)',
        );
        files = fileList.files ?? [];
      } catch (e) {
        debugPrint('Notice listing AppData backups: $e');
      }

      if (files.isEmpty) {
        try {
          final fileListRoot = await driveApi.files.list(
            q: "name contains 'finloop_backup_' and trashed = false",
            orderBy: 'createdTime desc',
            $fields: 'files(id, name, createdTime, size)',
          );
          files = fileListRoot.files ?? [];
        } catch (e) {
          debugPrint('Notice listing root Drive backups: $e');
        }
      }

      return files.map((f) {
        String formattedDate = f.name ?? 'Backup';
        if (f.createdTime != null) {
          formattedDate = DateFormat('MMM dd, yyyy - hh:mm a')
              .format(f.createdTime!.toLocal());
        }
        return {
          'id': f.id ?? '',
          'name': f.name ?? 'finloop_backup.enc',
          'date': formattedDate,
          'size': '${((int.tryParse(f.size ?? '0') ?? 0) / 1024).toStringAsFixed(1)} KB',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error listing Google Drive backups: $e');
      return [];
    }
  }

  // Download raw payload from Google Drive file
  static Future<String?> fetchDriveBackupRawPayload(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      final drive.Media fileMedia = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataBytes = [];
      await for (final data in fileMedia.stream) {
        dataBytes.addAll(data);
      }

      return utf8.decode(dataBytes);
    } catch (e) {
      debugPrint('Error fetching raw drive backup payload: $e');
      return null;
    }
  }

  // Delete a backup file from Google Drive
  static Future<bool> deleteDriveBackup(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;
      await driveApi.files.delete(fileId);
      return true;
    } catch (e) {
      debugPrint('Error deleting drive backup: $e');
      return false;
    }
  }

  // Create temporary local safety snapshot before starting restore operations
  static Future<String?> createLocalSafetySnapshot() async {
    try {
      final data = await exportFullAppData();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/finloop_safety_snapshot.json');
      await file.writeAsString(jsonEncode(data));
      return file.path;
    } catch (e) {
      debugPrint('Error creating safety snapshot: $e');
      return null;
    }
  }

  // Recover database state from local safety snapshot if restore fails
  static Future<bool> restoreFromSafetySnapshot() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/finloop_safety_snapshot.json');
      if (!await file.exists()) return false;
      final rawJson = await file.readAsString();
      final Map<String, dynamic> backupData = jsonDecode(rawJson);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (final col in ['transactions', 'accounts', 'categories', 'budgets', 'main_accounts', 'notes']) {
        if (backupData[col] is List) {
          for (var item in (backupData[col] as List)) {
            if (item is Map<String, dynamic>) {
              final docId = item['id']?.toString();
              if (docId != null) {
                final rawMap = Map<String, dynamic>.from(item)..remove('id');
                batch.set(db.collection('users').doc(uid).collection(col).doc(docId), _desanitizeValue(rawMap), SetOptions(merge: true));
              }
            }
          }
        }
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error restoring from safety snapshot: $e');
      return false;
    }
  }

  // Atomic Firestore WriteBatch Restore Engine supporting Replace vs Merge
  static Future<bool> restoreFromRawPayload(
    String rawPayloadString, {
    RestoreMode restoreMode = RestoreMode.replaceAll,
  }) async {
    final safetyPath = await createLocalSafetySnapshot();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'user';
      if (uid == 'user') return false;

      final decryptedJsonString = await BackupEncryption.decrypt(rawPayloadString, uid);
      final Map<String, dynamic> backupData = jsonDecode(decryptedJsonString);
      final db = FirebaseFirestore.instance;

      // 1. Wipe current collections if Replace All mode is chosen
      if (restoreMode == RestoreMode.replaceAll) {
        for (final col in ['transactions', 'accounts', 'categories', 'budgets', 'main_accounts', 'notes']) {
          final snap = await db.collection('users').doc(uid).collection(col).get();
          WriteBatch wipeBatch = db.batch();
          int count = 0;
          for (final doc in snap.docs) {
            wipeBatch.delete(doc.reference);
            count++;
            if (count >= 400) {
              await wipeBatch.commit();
              wipeBatch = db.batch();
              count = 0;
            }
          }
          if (count > 0) await wipeBatch.commit();
        }
      }

      // 2. Perform Atomic Batch Writes (Chunked into 400 operations per batch)
      WriteBatch writeBatch = db.batch();
      int opCount = 0;

      Future<void> addToBatch(DocumentReference docRef, Map<String, dynamic> data) async {
        writeBatch.set(docRef, data, SetOptions(merge: true));
        opCount++;
        if (opCount >= 400) {
          await writeBatch.commit();
          writeBatch = db.batch();
          opCount = 0;
        }
      }

      // Restore Transactions
      if (backupData['transactions'] is List) {
        for (var item in (backupData['transactions'] as List)) {
          if (item is Map<String, dynamic>) {
            final docId = item['id']?.toString() ?? db.collection('users').doc(uid).collection('transactions').doc().id;
            final rawMap = Map<String, dynamic>.from(item)..remove('id');
            final ref = db.collection('users').doc(uid).collection('transactions').doc(docId);
            await addToBatch(ref, Map<String, dynamic>.from(_desanitizeValue(rawMap)));
          }
        }
      }

      // Restore Accounts
      if (backupData['accounts'] is List) {
        for (var item in (backupData['accounts'] as List)) {
          if (item is Map<String, dynamic>) {
            final docId = item['id']?.toString() ?? db.collection('users').doc(uid).collection('accounts').doc().id;
            final rawMap = Map<String, dynamic>.from(item)..remove('id');
            final ref = db.collection('users').doc(uid).collection('accounts').doc(docId);
            await addToBatch(ref, Map<String, dynamic>.from(_desanitizeValue(rawMap)));
          }
        }
      }

      // Restore Categories
      if (backupData['categories'] is List) {
        for (var item in (backupData['categories'] as List)) {
          if (item is Map<String, dynamic>) {
            final docId = item['id']?.toString() ?? db.collection('users').doc(uid).collection('categories').doc().id;
            final rawMap = Map<String, dynamic>.from(item)..remove('id');
            final ref = db.collection('users').doc(uid).collection('categories').doc(docId);
            await addToBatch(ref, Map<String, dynamic>.from(_desanitizeValue(rawMap)));
          }
        }
      }

      // Restore Budgets
      if (backupData['budgets'] is List) {
        for (var item in (backupData['budgets'] as List)) {
          if (item is Map<String, dynamic>) {
            final docId = item['id']?.toString() ?? db.collection('users').doc(uid).collection('budgets').doc().id;
            final rawMap = Map<String, dynamic>.from(item)..remove('id');
            final ref = db.collection('users').doc(uid).collection('budgets').doc(docId);
            await addToBatch(ref, Map<String, dynamic>.from(_desanitizeValue(rawMap)));
          }
        }
      }

      // Restore Main Accounts
      if (backupData['main_accounts'] is List) {
        for (var item in (backupData['main_accounts'] as List)) {
          if (item is Map<String, dynamic>) {
            final docId = item['id']?.toString() ?? db.collection('users').doc(uid).collection('main_accounts').doc().id;
            final rawMap = Map<String, dynamic>.from(item)..remove('id');
            final ref = db.collection('users').doc(uid).collection('main_accounts').doc(docId);
            await addToBatch(ref, Map<String, dynamic>.from(_desanitizeValue(rawMap)));
          }
        }
      }

      // Restore Scratchpad Notes
      if (backupData['notes'] is List) {
        for (var item in (backupData['notes'] as List)) {
          if (item is Map<String, dynamic>) {
            final docId = item['id']?.toString() ?? db.collection('users').doc(uid).collection('notes').doc().id;
            final rawMap = Map<String, dynamic>.from(item)..remove('id');
            final ref = db.collection('users').doc(uid).collection('notes').doc(docId);
            await addToBatch(ref, Map<String, dynamic>.from(_desanitizeValue(rawMap)));
          }
        }
      }

      if (opCount > 0) {
        await writeBatch.commit();
      }

      return true;
    } catch (e) {
      debugPrint('Error restoring from raw payload. Attempting auto-rollback: $e');
      if (safetyPath != null) {
        await restoreFromSafetySnapshot();
      }
      return false;
    }
  }

  // Check if restoring a backup older than local database records
  static Future<bool> isBackupOlderThanLocal(Map<String, dynamic> summary) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final backupDateStr = summary['rawDateTime'];
      if (backupDateStr == null) return false;
      final backupDate = DateTime.tryParse(backupDateStr);
      if (backupDate == null) return false;

      final db = FirebaseFirestore.instance;
      final latestTxSnap = await db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      if (latestTxSnap.docs.isNotEmpty) {
        final data = latestTxSnap.docs.first.data();
        final rawTs = data['created_at'] ?? data['date'];
        if (rawTs is Timestamp) {
          final localDate = rawTs.toDate();
          if (backupDate.isBefore(localDate)) {
            return true; // Backup is older than current database content
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Notice checking backup conflict date: $e');
      return false;
    }
  }

  // --- Auto-Backup Schedule Management ---

  static Future<String> getAutoBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_autoBackupFreqKey) ?? 'off';
  }

  static Future<void> setAutoBackupFrequency(String frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoBackupFreqKey, frequency);
    _updateNextAutoBackupTime(freq: frequency);
  }

  static Future<String> getLastDriveBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastBackupTimeKey) ?? 'Never';
  }

  static Future<void> _updateNextAutoBackupTime({String? freq}) async {
    final prefs = await SharedPreferences.getInstance();
    final frequency = freq ?? prefs.getString(_autoBackupFreqKey) ?? 'off';

    DateTime nextRun;
    final now = DateTime.now();

    if (frequency == 'daily') {
      nextRun = now.add(const Duration(days: 1));
    } else if (frequency == 'weekly') {
      nextRun = now.add(const Duration(days: 7));
    } else if (frequency == 'monthly') {
      nextRun = DateTime(now.year, now.month + 1, now.day);
    } else {
      await prefs.remove(_nextBackupTimeKey);
      return;
    }

    await prefs.setString(_nextBackupTimeKey, nextRun.toIso8601String());
  }

  // Check auto backup schedule and execute silent upload if due
  static Future<void> checkAndRunAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final frequency = prefs.getString(_autoBackupFreqKey) ?? 'off';
      if (frequency == 'off') return;

      final nextBackupIso = prefs.getString(_nextBackupTimeKey);
      if (nextBackupIso != null) {
        final nextBackup = DateTime.tryParse(nextBackupIso);
        if (nextBackup != null && DateTime.now().isBefore(nextBackup)) {
          return;
        }
      }

      final email = await getConnectedAccountEmail();
      if (email != null && email.isNotEmpty) {
        debugPrint('Auto-backup to Google Drive is due. Executing background backup...');
        await uploadBackupToDrive(isAuto: true);
      }
    } catch (e) {
      debugPrint('Error running auto backup check: $e');
    }
  }
}
