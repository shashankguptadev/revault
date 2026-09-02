import 'package:flutter/material.dart';
import '../services/pin_service.dart';

class PinScreen extends StatefulWidget {
  final bool isSetup;
  final Function(String)? onPinSet;
  final Function(String)? onPinVerified;

  const PinScreen({
    super.key,
    this.isSetup = false,
    this.onPinSet,
    this.onPinVerified,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _oldPinController = TextEditingController();

  bool _isChangingPin = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  void _checkBiometricStatus() async {
    final available = await PinService.hasEnrolledBiometrics();
    final enabled = await PinService.isBiometricEnabled();

    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
      _isLoading = false;
    });
  }

  void _submit() {
    if (widget.isSetup) {
      if (_pinController.text.length != 4) {
        _showError('PIN must be 4 digits');
        return;
      }
      if (_pinController.text != _confirmPinController.text) {
        _showError('PINs do not match');
        return;
      }
      widget.onPinSet!(_pinController.text);
    } else if (_isChangingPin) {
      if (_oldPinController.text.length != 4 ||
          _pinController.text.length != 4) {
        _showError('PIN must be 4 digits');
        return;
      }
      if (_pinController.text != _confirmPinController.text) {
        _showError('PINs do not match');
        return;
      }
      _verifyAndChangePin();
    } else {
      if (_pinController.text.length != 4) {
        _showError('PIN must be 4 digits');
        return;
      }
      widget.onPinVerified!(_pinController.text);
    }
  }

  void _verifyAndChangePin() async {
    try {
      final isOldPinCorrect = await PinService.verifyPin(
        _oldPinController.text,
      );
      if (!isOldPinCorrect) {
        _showError('Incorrect old PIN');
        return;
      }

      await PinService.changePin(_pinController.text);
      if (mounted) {
        _showSuccess('PIN changed successfully');
        setState(() {
          _isChangingPin = false;
          _oldPinController.clear();
          _pinController.clear();
          _confirmPinController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to change PIN. Please try again. Error: $e');
      }
    }
  }

  void _toggleBiometric() async {
    final newValue = !_biometricEnabled;
    await PinService.setBiometricEnabled(newValue);
    setState(() {
      _biometricEnabled = newValue;
    });

    if (newValue) {
      _showSuccess('Biometric authentication enabled');
    } else {
      _showSuccess('Biometric authentication disabled');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Widget _buildBiometricToggleCard() {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.fingerprint, size: 40, color: Colors.blue.shade300),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable Biometric Authentication',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Use fingerprint or face ID to unlock the app',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: _biometricEnabled,
              onChanged: (value) => _toggleBiometric(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isChangingPin
              ? 'Change PIN'
              : (widget.isSetup ? 'Set up PIN' : 'Enter PIN'),
        ),
        actions: _isChangingPin || widget.isSetup
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    setState(() {
                      _isChangingPin = true;
                    });
                  },
                ),
              ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isChangingPin) ...[
              TextField(
                controller: _oldPinController,
                autofocus: true,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Old PIN',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _pinController,
              autofocus: !_isChangingPin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: _isChangingPin ? 'New PIN' : 'PIN',
                counterText: '',
              ),
            ),
            if (widget.isSetup || _isChangingPin) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Confirm PIN',
                  counterText: '',
                ),
              ),
            ],

            // Show biometric toggle in these cases:
            // 1. During initial setup AND biometric is available
            // 2. During PIN verification AND biometric is available AND biometric is NOT enabled
            if ((widget.isSetup && _biometricAvailable) ||
                (!widget.isSetup &&
                    !_isChangingPin &&
                    _biometricAvailable &&
                    !_biometricEnabled)) ...[
              const SizedBox(height: 20),
              _buildBiometricToggleCard(),
            ],

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              child: Text(
                _isChangingPin
                    ? 'Change PIN'
                    : (widget.isSetup ? 'Set PIN' : 'Verify'),
              ),
            ),

            if (!widget.isSetup &&
                !_isChangingPin &&
                _biometricAvailable &&
                _biometricEnabled) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () async {
                  final success = await PinService.authenticateWithBiometrics();
                  if (success && mounted) {
                    widget.onPinVerified!('biometric');
                  } else {
                    _showError('Biometric authentication failed');
                  }
                },
                icon: const Icon(Icons.fingerprint),
                label: const Text('Use Biometric Authentication'),
              ),
            ],

            if (_isChangingPin) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isChangingPin = false;
                    _oldPinController.clear();
                    _pinController.clear();
                    _confirmPinController.clear();
                  });
                },
                child: const Text('Back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}