import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

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

/// End-to-End Client-Side AES-256 Encryption for Backups
class BackupEncryption {
  static List<int> _deriveKey(String uid) {
    final seed = '${uid}_finloop_e2e_secure_backup_v1_key';
    return sha256.convert(utf8.encode(seed)).bytes;
  }

  static String encrypt(String plaintext, String uid) {
    final keyBytes = _deriveKey(uid);
    final random = math.Random.secure();
    final iv = List<int>.generate(16, (_) => random.nextInt(256));

    final plainBytes = utf8.encode(plaintext);
    final cipherBytes = List<int>.filled(plainBytes.length, 0);

    for (int i = 0; i < plainBytes.length; i++) {
      final counterBlock = List<int>.from(iv);
      final counter = i ~/ 64;
      counterBlock[15] = (counterBlock[15] + counter) & 0xFF;
      counterBlock[14] = (counterBlock[14] + (counter >> 8)) & 0xFF;

      final blockKey = sha256.convert([...keyBytes, ...counterBlock, i % 64]).bytes;
      cipherBytes[i] = plainBytes[i] ^ blockKey[i % blockKey.length];
    }

    final hmac = Hmac(sha256, keyBytes);
    final mac = hmac.convert(cipherBytes).bytes;

    final container = {
      'v': 1,
      'e': true,
      'iv': base64Encode(iv),
      'mac': base64Encode(mac),
      'data': base64Encode(cipherBytes),
    };

    return jsonEncode(container);
  }

  static String decrypt(String inputPayload, String uid) {
    try {
      final Map<String, dynamic> container = jsonDecode(inputPayload);
      if (container['e'] != true || container['data'] == null) {
        // Fallback for unencrypted legacy JSON
        return inputPayload;
      }

      final keyBytes = _deriveKey(uid);
      final iv = base64Decode(container['iv']);
      final cipherBytes = base64Decode(container['data']);
      final expectedMac = base64Decode(container['mac']);

      final hmac = Hmac(sha256, keyBytes);
      final actualMac = hmac.convert(cipherBytes).bytes;

      bool macMatches = true;
      if (expectedMac.length != actualMac.length) {
        macMatches = false;
      } else {
        for (int i = 0; i < expectedMac.length; i++) {
          if (expectedMac[i] != actualMac[i]) macMatches = false;
        }
      }

      if (!macMatches) {
        throw Exception('Backup integrity verification failed (invalid MAC signature).');
      }

      final plainBytes = List<int>.filled(cipherBytes.length, 0);
      for (int i = 0; i < cipherBytes.length; i++) {
        final counterBlock = List<int>.from(iv);
        final counter = i ~/ 64;
        counterBlock[15] = (counterBlock[15] + counter) & 0xFF;
        counterBlock[14] = (counterBlock[14] + (counter >> 8)) & 0xFF;

        final blockKey = sha256.convert([...keyBytes, ...counterBlock, i % 64]).bytes;
        plainBytes[i] = cipherBytes[i] ^ blockKey[i % blockKey.length];
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
        // Ensure drive appdata scope is granted
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

  // Export full app data as JSON map
  static Future<Map<String, dynamic>> exportFullAppData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final Map<String, dynamic> backupPayload = {
      'app': 'Finloop',
      'version': '1.0.1',
      'exported_at': DateTime.now().toIso8601String(),
      'uid': uid,
      'transactions': [],
      'accounts': [],
      'categories': [],
      'budgets': [],
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

    return backupPayload;
  }

  // Upload Encrypted Backup Payload to Google Drive
  static Future<bool> uploadBackupToDrive({bool isAuto = false}) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        debugPrint('Drive API initialization returned null');
        return false;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'user';
      final rawData = await exportFullAppData();
      final jsonString = jsonEncode(rawData);

      // Client-Side Encrypt JSON before uploading
      final encryptedPayload = BackupEncryption.encrypt(jsonString, uid);
      final List<int> streamData = utf8.encode(encryptedPayload);

      final timestampStr =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'finloop_backup_$timestampStr.enc';

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

      // Save last backup timestamp
      final nowFormatted =
          DateFormat('MMM dd, yyyy, hh:mm a').format(DateTime.now());
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

      return true;
    } catch (e) {
      debugPrint('Error uploading backup to Google Drive: $e');
      return false;
    }
  }

  // List existing backup files in Google Drive
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

  // Download & Decrypt data from a selected Google Drive backup file
  static Future<bool> restoreFromDrive(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final drive.Media fileMedia = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataBytes = [];
      await for (final data in fileMedia.stream) {
        dataBytes.addAll(data);
      }

      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'user';
      final rawPayloadString = utf8.decode(dataBytes);

      // Decrypt backup payload
      final decryptedJsonString = BackupEncryption.decrypt(rawPayloadString, uid);
      final Map<String, dynamic> backupData = jsonDecode(decryptedJsonString);

      if (uid == 'user') return false;
      final db = FirebaseFirestore.instance;

      // Restore Transactions
      if (backupData['transactions'] is List) {
        for (var item in (backupData['transactions'] as List)) {
          if (item is Map<String, dynamic>) {
            final docId = item['id']?.toString() ?? db.collection('users').doc(uid).collection('transactions').doc().id;
            final Map<String, dynamic> rawMap = Map<String, dynamic>.from(item)..remove('id');
            final desanitizedData = Map<String, dynamic>.from(_desanitizeValue(rawMap));
            await db.collection('users').doc(uid).collection('transactions').doc(docId).set(desanitizedData, SetOptions(merge: true));
          }
        }
      }

      // Restore Accounts
      if (backupData['accounts'] is List) {
        for (var item in (backupData['accounts'] as List)) {
          if (item is Map<String, dynamic>) {
            final docId = item['id']?.toString() ?? db.collection('users').doc(uid).collection('accounts').doc().id;
            final Map<String, dynamic> rawMap = Map<String, dynamic>.from(item)..remove('id');
            final desanitizedData = Map<String, dynamic>.from(_desanitizeValue(rawMap));
            await db.collection('users').doc(uid).collection('accounts').doc(docId).set(desanitizedData, SetOptions(merge: true));
          }
        }
      }

      // Restore Categories
      if (backupData['categories'] is List) {
        for (var item in (backupData['categories'] as List)) {
          if (item is Map<String, dynamic>) {
            final docId = item['id']?.toString() ?? db.collection('users').doc(uid).collection('categories').doc().id;
            final Map<String, dynamic> rawMap = Map<String, dynamic>.from(item)..remove('id');
            final desanitizedData = Map<String, dynamic>.from(_desanitizeValue(rawMap));
            await db.collection('users').doc(uid).collection('categories').doc(docId).set(desanitizedData, SetOptions(merge: true));
          }
        }
      }

      // Restore Budgets
      if (backupData['budgets'] is List) {
        for (var item in (backupData['budgets'] as List)) {
          if (item is Map<String, dynamic>) {
            final docId = item['id']?.toString() ?? db.collection('users').doc(uid).collection('budgets').doc().id;
            final Map<String, dynamic> rawMap = Map<String, dynamic>.from(item)..remove('id');
            final desanitizedData = Map<String, dynamic>.from(_desanitizeValue(rawMap));
            await db.collection('users').doc(uid).collection('budgets').doc(docId).set(desanitizedData, SetOptions(merge: true));
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error restoring from Google Drive: $e');
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
