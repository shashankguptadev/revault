import 'package:flutter/material.dart';
import '../models/account_details.dart';
import '../services/vault_service.dart';

class PasswordDialog extends StatelessWidget {
  final AccountDetails account;

  const PasswordDialog({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: VaultService.getDecryptedPassword(account),
      builder: (context, snapshot) {
        return AlertDialog(
          backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
          title: Text(
            account.website,
            style: const TextStyle(color: Colors.white),
          ),
          content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Password: \n${snapshot.data ?? 'Decrypting...'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }
}
