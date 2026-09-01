import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/folder.dart';
import 'models/account_details.dart';
import 'services/vault_service.dart';
import 'services/encryption_service.dart';
import 'services/pin_service.dart';
import 'screens/vault_screen.dart';
import 'screens/pin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(FolderAdapter());
  Hive.registerAdapter(AccountDetailsAdapter());

  // first initialize encryption service then vault service
  await EncryptionService.initialize();

  await VaultService.init();

  runApp(const PasswordVaultApp());
}

class PasswordVaultApp extends StatelessWidget {
  const PasswordVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    const montserratTextTheme = TextTheme(
      bodyLarge: TextStyle(fontFamily: 'Montserrat', color: Colors.white),
      bodyMedium: TextStyle(fontFamily: 'Montserrat', color: Colors.white),
      titleLarge: TextStyle(
        fontFamily: 'Montserrat',
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(fontFamily: 'Montserrat', color: Colors.white),
      labelLarge: TextStyle(fontFamily: 'Montserrat', color: Colors.white),
      labelMedium: TextStyle(fontFamily: 'Montserrat', color: Colors.white),
      displayLarge: TextStyle(fontFamily: 'Montserrat'),
      displayMedium: TextStyle(fontFamily: 'Montserrat'),
      displaySmall: TextStyle(fontFamily: 'Montserrat'),
      headlineMedium: TextStyle(fontFamily: 'Montserrat'),
      headlineSmall: TextStyle(fontFamily: 'Montserrat'),
      titleSmall: TextStyle(fontFamily: 'Montserrat'),
    );
    return MaterialApp(
      title: 'ReVault',
      theme: ThemeData.dark().copyWith(
        textTheme: montserratTextTheme,
        primaryTextTheme: montserratTextTheme,
        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade300,
          secondary: Colors.green.shade300,
          surface: const Color(0xFF121212),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2D2D2D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue),
          ),
          labelStyle: const TextStyle(color: Colors.grey),
          hintStyle: const TextStyle(color: Colors.grey),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[800],
          contentTextStyle: const TextStyle(color: Colors.white),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.blue.shade300,
          foregroundColor: Colors.white,
        ),
      ),
      home: const AppLockWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppLockWrapper extends StatefulWidget {
  const AppLockWrapper({super.key});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> {
  bool _isPinVerified = false;
  bool _isPinSet = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  void _checkPinStatus() async {
    try {
      final isPinSet = await PinService.isPinSet();
      setState(() {
        _isPinSet = isPinSet;
        _isLoading = false;
      });

      // if PIN set & biometrics enabled, try biometric authentication
      if (isPinSet) {
        final biometricEnabled = await PinService.isBiometricEnabled();
        if (biometricEnabled) {
          final hasBiometrics = await PinService.hasEnrolledBiometrics();
          if (hasBiometrics) {
            final success = await PinService.authenticateWithBiometrics();
            if (success && mounted) {
              setState(() {
                _isPinVerified = true;
              });
            }
          }
        }
      }
    } catch (e) {
      // if error reading PIN, treat as not set
      setState(() {
        _isPinSet = false;
        _isLoading = false;
      });
    }
  }

  void _onPinSet(String pin) async {
    await PinService.setPin(pin);
    setState(() {
      _isPinSet = true;
      _isPinVerified = true;
    });
  }

  void _onPinVerified(String pin) async {
    if (pin == 'biometric') {
      setState(() {
        _isPinVerified = true;
      });
      return;
    }

    final isCorrect = await PinService.verifyPin(pin);
    if (isCorrect) {
      setState(() {
        _isPinVerified = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isPinSet) {
      return PinScreen(isSetup: true, onPinSet: _onPinSet);
    }

    if (!_isPinVerified) {
      return PinScreen(isSetup: false, onPinVerified: _onPinVerified);
    }

    return const VaultScreen(
      currentFolderKey: VaultService.rootFolderKey,
      currentPath: 'Root',
    );
  }
}
