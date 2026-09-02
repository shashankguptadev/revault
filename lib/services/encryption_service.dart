import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncryptionService {
  static const String _keyStorageKey = 'encryption_key';
  static const String _ivStorageKey = 'encryption_iv';

  // Store IV as instance variable to ensure consistency
  static IV? _cachedIV;
  static Key? _cachedKey;

  static Future<IV> _getIV() async {
    // Return cached IV if available
    if (_cachedIV != null) return _cachedIV!;

    final prefs = await SharedPreferences.getInstance();
    String? ivBase64 = prefs.getString(_ivStorageKey);

    try {
      // Decode the stored IV
      final ivBytes = base64.decode(ivBase64!);
      final iv = IV(ivBytes);
      _cachedIV = iv;
      return iv;
    } catch (e) {
      // If stored IV is invalid, generate a new one
      final iv = _generateIV();
      final newIvBase64 = base64.encode(iv.bytes);
      await prefs.setString(_ivStorageKey, newIvBase64);
      _cachedIV = iv;
      return iv;
    }
  }

  static IV _generateIV() {
    final random = Random.secure();
    final ivBytes = List<int>.generate(16, (i) => random.nextInt(256));
    return IV(Uint8List.fromList(ivBytes));
  }

  static Future<Key> _getEncryptionKey() async {
    // Return cached key if available
    if (_cachedKey != null) return _cachedKey!;

    final prefs = await SharedPreferences.getInstance();
    String? keyBase64 = prefs.getString(_keyStorageKey);

    try {
      final key = Key.fromBase64(keyBase64!);
      _cachedKey = key;
      return key;
    } catch (e) {
      // If stored key is invalid, generate a new one
      final key = Key.fromSecureRandom(32);
      final newKeyBase64 = base64.encode(key.bytes);
      await prefs.setString(_keyStorageKey, newKeyBase64);
      _cachedKey = key;
      return key;
    }
  }

  static Future<String> encryptPassword(String password) async {
    try {
      final key = await _getEncryptionKey();
      final iv = await _getIV();
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final encrypted = encrypter.encrypt(password, iv: iv);
      return encrypted.base64;
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  static Future<String> decryptPassword(String encryptedPassword) async {
    try {
      final key = await _getEncryptionKey();
      final iv = await _getIV();
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt64(encryptedPassword, iv: iv);
      return decrypted;
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  // Clear all encryption data (for testing/reset)
  static Future<void> clearEncryptionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStorageKey);
    await prefs.remove(_ivStorageKey);
    _cachedKey = null;
    _cachedIV = null;
  }

  // Master password hash (optional additional security layer)
  static Future<void> setMasterPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = sha256.convert(utf8.encode(password)).toString();
    await prefs.setString('master_password_hash', hash);
  }

  static Future<bool> verifyMasterPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString('master_password_hash');
    if (storedHash == null) return true; // No master password set

    final inputHash = sha256.convert(utf8.encode(password)).toString();
    return inputHash == storedHash;
  }

  static Future<void> initialize() async {
    await _getEncryptionKey();
    await _getIV();
  }

  static Future<List<int>> encryptWithPassword(
    List<int> data,
    String password,
  ) async {
    final key = _deriveKeyFromPassword(password);
    final iv = _generateIV();
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(Uint8List.fromList(data), iv: iv);
    final result = Uint8List(iv.bytes.length + encrypted.bytes.length)
      ..setAll(0, iv.bytes)
      ..setAll(iv.bytes.length, encrypted.bytes);
    return result;
  }

  static Future<List<int>> decryptWithPassword(
    List<int> encryptedData,
    String password,
  ) async {
    if (encryptedData.length < 16) throw Exception('Invalid encrypted data');
    final ivBytes = encryptedData.sublist(0, 16);
    final cipherBytes = encryptedData.sublist(16);
    final key = _deriveKeyFromPassword(password);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(
      Encrypted(Uint8List.fromList(cipherBytes)),
      iv: IV(Uint8List.fromList(ivBytes)),
    );
    return decrypted;
  }

  static Key _deriveKeyFromPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return Key.fromBase64(base64.encode(digest.bytes));
  }

  static Future<void> reinitializeFromStoredKey() async {
    _cachedKey = null;
    _cachedIV = null;
    await _getEncryptionKey();
    await _getIV();
  }
}
