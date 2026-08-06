import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'encryption_service.dart';
import 'package:crypto/crypto.dart';

class PinService {
  static const String _encryptedPinKey = 'encrypted_app_pin';
  static const String _isPinSetKey = 'is_pin_set';
  static const String _pinSaltKey = 'pin_salt';
  static const String _biometricEnabledKey = 'biometric_enabled';

  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();

    // Generate a random salt for this PIN
    final salt = _generateSalt();
    await prefs.setString(_pinSaltKey, salt);

    // Hash the PIN with salt and encrypt it
    final pinHash = _hashPinWithSalt(pin, salt);
    final encryptedPin = await EncryptionService.encryptPassword(pinHash);

    await prefs.setString(_encryptedPinKey, encryptedPin);
    await prefs.setBool(_isPinSetKey, true);
  }

  static Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isPinSetKey) ?? false;
  }

  static Future<bool> verifyPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedPin = prefs.getString(_encryptedPinKey);
      final salt = prefs.getString(_pinSaltKey);

      if (encryptedPin == null || salt == null) {
        return false;
      }

      // Hash the input PIN with the stored salt
      final inputPinHash = _hashPinWithSalt(pin, salt);

      // Decrypt the stored PIN and compare
      final storedPinHash = await EncryptionService.decryptPassword(
        encryptedPin,
      );

      return storedPinHash == inputPinHash;
    } catch (e) {
      return false;
    }
  }

  static Future<void> changePin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();

    // Generate new salt
    final newSalt = _generateSalt();
    await prefs.setString(_pinSaltKey, newSalt);

    // Hash and encrypt new PIN
    final newPinHash = _hashPinWithSalt(newPin, newSalt);
    final encryptedNewPin = await EncryptionService.encryptPassword(newPinHash);

    await prefs.setString(_encryptedPinKey, encryptedNewPin);
  }

  // Biometric methods
  static Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> hasEnrolledBiometrics() async {
    try {
      final canCheck = await isBiometricAvailable();
      if (!canCheck) return false;

      final enrolledBiometrics = await _localAuth.getAvailableBiometrics();
      return enrolledBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      final isAvailable = await hasEnrolledBiometrics();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your vault',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  // Clear the PIN (for testing or logout)
  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_encryptedPinKey);
    await prefs.remove(_isPinSetKey);
    await prefs.remove(_pinSaltKey);
    await prefs.remove(_biometricEnabledKey);
  }

  // Generate a random salt
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(saltBytes);
  }

  // Hash PIN with salt using SHA-256
  static String _hashPinWithSalt(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}