import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:revault/services/vault_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/folder.dart';
import '../models/account_details.dart';
import 'encryption_service.dart';

class BackupService {
  static const String _backupFileName = 'revault_backup.enc';
  static const String _backupMimeType = 'application/octet-stream';

  static const String _serverClientId = '1044953270653-mj3hrb1laa14iqmisokaqp2itr9t205h.apps.googleusercontent.com';

  final List<String> _scopes = [drive.DriveApi.driveFileScope];

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // backup: export all data, encrypt with user password, to drive
  Future<bool> performBackup(String backupPassword) async {
    try {
      await _googleSignIn.initialize(serverClientId: _serverClientId);

      final account = await _googleSignIn.authenticate();

      final authorization = await account.authorizationClient.authorizeScopes(
        _scopes,
      );

      final authenticateClient = authorization.authClient(scopes: _scopes);

      final driveApi = drive.DriveApi(authenticateClient);

      // gather all data
      final foldersMap = <String, Map<String, dynamic>>{};
      for (var folder in VaultService.folderBox.values) {
        foldersMap[folder.key.toString()] = {
          'name': folder.name,
          'email': folder.email,
          'subFolderKeys': folder.subFolderKeys,
          'accountKeys': folder.accountKeys,
          'createdAt': folder.createdAt.toIso8601String(),
        };
      }

      final accountsMap = <String, Map<String, dynamic>>{};
      for (var account in VaultService.accountBox.values) {
        accountsMap[account.key.toString()] = {
          'website': account.website,
          'encryptedPassword': account.encryptedPassword,
          'createdAt': account.createdAt.toIso8601String(),
          'lastModified': account.lastModified.toIso8601String(),
        };
      }

      final prefs = await SharedPreferences.getInstance();
      final encryptionKey = prefs.getString('encryption_key') ?? '';
      final encryptionIV = prefs.getString('encryption_iv') ?? '';

      final backupData = {
        'version': 1,
        'folders': foldersMap,
        'accounts': accountsMap,
        'encryptionKey': encryptionKey,
        'encryptionIV': encryptionIV,
        'pinData': {
          'encryptedPin': prefs.getString('encrypted_app_pin'),
          'pinSalt': prefs.getString('pin_salt'),
          'isPinSet': prefs.getBool('is_pin_set'),
          'biometricEnabled': prefs.getBool('biometric_enabled'),
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      final jsonString = jsonEncode(backupData);
      final jsonBytes = utf8.encode(jsonString);

      final encryptedBytes = await EncryptionService.encryptWithPassword(
        jsonBytes,
        backupPassword,
      );

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_backupFileName');
      await tempFile.writeAsBytes(encryptedBytes);

      // look for existing backup, if present then overwrite
      final existing = await driveApi.files.list(
        q: "name = '$_backupFileName' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, modifiedTime)',
        orderBy: 'modifiedTime desc',
      );

      final media = drive.Media(tempFile.openRead(), tempFile.lengthSync());

      if (existing.files != null && existing.files!.isNotEmpty) {
        final fileId =
            existing.files!.first.id!; // first means the most recently modified
        await driveApi.files.update(drive.File(), fileId, uploadMedia: media);

        // clean older duplicates
        for (final extra in existing.files!.skip(1)) {
          if (extra.id != null) {
            await driveApi.files.delete(extra.id!);
          }
        }
      } else {
        final driveFile = drive.File();
        driveFile.name = _backupFileName;
        driveFile.mimeType = _backupMimeType;
        await driveApi.files.create(driveFile, uploadMedia: media);
      }

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Backup error: $e');
      return false;
    }
  }

  // restore: download from drive, decrypt with password, overwrite local data
  Future<bool> performRestore(String backupPassword) async {
    try {
      await _googleSignIn.initialize(serverClientId: _serverClientId);

      final account = await _googleSignIn.authenticate();

      final authorization = await account.authorizationClient.authorizeScopes(
        _scopes,
      );
      final authenticateClient = authorization.authClient(scopes: _scopes);

      final driveApi = drive.DriveApi(authenticateClient);

      final fileList = await driveApi.files.list(
        q: "name = '$_backupFileName' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, modifiedTime)',
        orderBy: 'modifiedTime desc',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return false;
      }

      final backupFile = fileList.files!.first;
      final drive.Media downloadStream =
          await driveApi.files.get(
                backupFile.id!,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final List<int> downloadedBytes = [];
      await for (var chunk in downloadStream.stream) {
        downloadedBytes.addAll(chunk);
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_backupFileName');
      await tempFile.writeAsBytes(downloadedBytes);

      final encryptedBytes = await tempFile.readAsBytes();
      final jsonBytes = await EncryptionService.decryptWithPassword(
        encryptedBytes,
        backupPassword,
      );
      final jsonString = utf8.decode(jsonBytes);
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (backupData['version'] != 1) {
        throw Exception('Unsupported backup version');
      }

      await VaultService.clearAllData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final encryptionKey = backupData['encryptionKey'] as String;
      final encryptionIV = backupData['encryptionIV'] as String;
      await prefs.setString('encryption_key', encryptionKey);
      await prefs.setString('encryption_iv', encryptionIV);

      await EncryptionService.reinitializeFromStoredKey();

      final foldersMap = backupData['folders'] as Map<String, dynamic>;
      for (var entry in foldersMap.entries) {
        final key = int.parse(entry.key);
        final data = entry.value as Map<String, dynamic>;
        final folder = Folder(
          name: data['name'],
          email: data['email'],
          subFolderKeys: List<int>.from(data['subFolderKeys'] ?? []),
          accountKeys: List<int>.from(data['accountKeys'] ?? []),
        );
        folder.createdAt = DateTime.parse(data['createdAt']);
        await VaultService.folderBox.put(key, folder);
      }

      final accountsMap = backupData['accounts'] as Map<String, dynamic>;
      for (var entry in accountsMap.entries) {
        final key = int.parse(entry.key);
        final data = entry.value as Map<String, dynamic>;
        final account = AccountDetails(
          website: data['website'],
          encryptedPassword: data['encryptedPassword'],
        );
        account.createdAt = DateTime.parse(data['createdAt']);
        account.lastModified = DateTime.parse(data['lastModified']);
        await VaultService.accountBox.put(key, account);
      }

      if (backupData['pinData'] != null) {
        final pinData = backupData['pinData'] as Map<String, dynamic>;
        if (pinData['encryptedPin'] != null) {
          await prefs.setString('encrypted_app_pin', pinData['encryptedPin']);
          await prefs.setString('pin_salt', pinData['pinSalt']);
          await prefs.setBool('is_pin_set', pinData['isPinSet'] ?? false);
          await prefs.setBool(
            'biometric_enabled',
            pinData['biometricEnabled'] ?? false,
          );
        }
      }

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
