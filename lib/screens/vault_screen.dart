import 'package:circular_menu/circular_menu.dart';
import 'package:flutter/material.dart';
import 'package:revault/main.dart';
import '../models/folder.dart';
import '../models/account_details.dart';
import '../services/vault_service.dart';
import '../services/pin_service.dart';
import '../services/backup_service.dart';

// Importing components
import '../widgets/folder_tile.dart';
import '../widgets/account_tile.dart';
import '../widgets/create_folder_dialog.dart';
import '../widgets/create_account_dialog.dart';
import '../widgets/edit_account_dialog.dart';
import '../widgets/edit_folder_dialog.dart';
import '../widgets/password_dialog.dart';
import '../widgets/confirmation_dialog.dart';

class VaultScreen extends StatefulWidget {
  final int currentFolderKey;
  final String currentPath;

  const VaultScreen({
    super.key,
    required this.currentFolderKey,
    this.currentPath = 'Root',
  });

  @override
  VaultScreenState createState() => VaultScreenState();
}

class VaultScreenState extends State<VaultScreen> {
  late Folder currentFolder;
  late List<Folder> subFolders;
  late List<AccountDetails> accounts;

  @override
  void initState() {
    super.initState();
    _loadFolderData();
  }

  void _loadFolderData() {
    currentFolder = VaultService.folderBox.get(widget.currentFolderKey)!;
    subFolders = currentFolder.subFolderKeys
        .map((key) => VaultService.folderBox.get(key))
        .whereType<Folder>()
        .toList();
    accounts = currentFolder.accountKeys
        .map((key) => VaultService.accountBox.get(key))
        .whereType<AccountDetails>()
        .toList();
  }

  void _refreshData() {
    setState(() {
      _loadFolderData();
    });
  }

  Future<bool?> _verifyPin() async {
    final biometricEnabled = await PinService.isBiometricEnabled();
    if (biometricEnabled) {
      final hasBiometrics = await PinService.hasEnrolledBiometrics();
      if (hasBiometrics) {
        final biometricSuccess = await PinService.authenticateWithBiometrics();
        if (biometricSuccess) {
          return true;
        }
      }
    }

    try {
      if (!mounted) return null;

      final pin = await showDialog<String>(
        context: context,
        builder: (context) {
          final pinController = TextEditingController();
          return AlertDialog(
            title: const Text('Enter PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinController,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'PIN'),
                ),
                if (biometricEnabled) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () async {
                      final success =
                          await PinService.authenticateWithBiometrics();
                      if (success && context.mounted) {
                        Navigator.pop(context, 'biometric');
                      }
                    },
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use Biometric'),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (pinController.text.length == 4) {
                    Navigator.pop(context, pinController.text);
                  }
                },
                child: const Text('Verify'),
              ),
            ],
          );
        },
      );

      if (pin == null) return null;
      if (pin == 'biometric') return true;

      return await PinService.verifyPin(pin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error verifying PIN')));
      }
      return null;
    }
  }

  void _showCreateFolderDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateFolderDialog(
        onCreate: (name, email) async {
          await VaultService.createFolder(
            name: name,
            parentFolderKey: widget.currentFolderKey,
            email: email,
          );
          _refreshData();
        },
      ),
    );
  }

  void _showCreateAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateAccountDialog(
        onCreate: (website, password) async {
          await VaultService.createAccount(
            website: website,
            password: password,
            parentFolderKey: widget.currentFolderKey,
          );
          _refreshData();
        },
      ),
    );
  }

  void _showPasswordDialog(AccountDetails account) async {
    final verified = await _verifyPin();
    if (verified == null) return;
    if (!verified) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      }
      return;
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => PasswordDialog(account: account),
    );
  }

  void _editAccount(AccountDetails account) async {
    final verified = await _verifyPin();
    if (verified == null) return;
    if (!verified) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      }
      return;
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => EditAccountDialog(
        account: account,
        onSave: (website, password) async {
          await VaultService.updateAccount(
            accountKey: account.key as int,
            website: website,
            password: password,
          );
          _refreshData();
        },
      ),
    );
  }

  void _editFolder(Folder folder) {
    showDialog(
      context: context,
      builder: (context) => EditFolderDialog(
        folder: folder,
        onSave: (name, email) async {
          await VaultService.updateFolder(
            folderKey: folder.key as int,
            name: name,
            email: email,
          );
          _refreshData();
        },
      ),
    );
  }

  Future<void> _deleteAccount(AccountDetails account) async {
    final verified = await _verifyPin();
    if (verified == null) return;
    if (!verified) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      }
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Delete Account?',
        content: 'Are you sure you want to delete ${account.website} account?',
      ),
    );

    if (confirmed == true) {
      await VaultService.deleteAccount(account.key as int);
      _refreshData();
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    final counts = VaultService.getFolderCounts(folder);
    final isEmpty = counts.$1 == 0 && counts.$2 == 0;

    if (!isEmpty) {
      final verified = await _verifyPin();
      if (verified == null) return;
      if (!verified) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
        }
        return;
      }
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Delete Folder?',
        content:
            'Are you sure you want to delete ${folder.name} folder?'
            '${isEmpty ? '' : ' This folder contains ${counts.$1} folders and ${counts.$2} accounts that will also be deleted.'}',
      ),
    );

    if (confirmed == true) {
      await VaultService.deleteFolder(folder.key as int);
      _refreshData();
    }
  }

  void _showSettingsMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.backup, color: Colors.blue),
              title: const Text('Backup to Google Drive'),
              onTap: () async {
                Navigator.pop(context);
                _performBackupRestore(isBackup: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.green),
              title: const Text('Restore from Google Drive'),
              onTap: () async {
                Navigator.pop(context);
                _performBackupRestore(isBackup: false);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBackupRestore({required bool isBackup}) async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBackup ? 'Backup Password' : 'Restore Password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Enter a strong password',
            hintText: 'Password for backup file',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isBackup ? 'Backup' : 'Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final backupPassword = passwordController.text.trim();
    if (backupPassword.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password cannot be empty')));
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = isBackup
        ? await BackupService().performBackup(backupPassword)
        : await BackupService().performRestore(backupPassword);

    if (!mounted) return;
    Navigator.pop(context); // remove loader

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBackup
                ? 'Backup successful!'
                : 'Restore successful! Restarting app...',
          ),
        ),
      );
      if (!isBackup) {
        // restart the app to reload all data
        await Future.delayed(const Duration(seconds: 1));
        // pop until home and rebuild
        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AppLockWrapper()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBackup
                ? 'Backup failed'
                : 'Restore failed. Check password or Drive file.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentFolder.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              widget.currentPath,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showSettingsMenu,
            icon: const Icon(Icons.settings),
          ),
          //   if (widget.currentFolderKey != VaultService.rootFolderKey)
          //     IconButton(
          //       icon: const Icon(Icons.arrow_upward),
          //       onPressed: () => Navigator.of(context).pop(),
          //     ),
        ],
      ),
      floatingActionButton: CircularMenu(
        alignment: Alignment.bottomRight,
        toggleButtonColor: Colors.blue.shade300,
        toggleButtonAnimatedIconData: AnimatedIcons.menu_close,
        curve: Curves.easeInOut,
        toggleButtonBoxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.5 * 255).toInt()),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
        items: [
          CircularMenuItem(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.5 * 255).toInt()),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
            color: Colors.blue.shade300,
            icon: Icons.create_new_folder,
            onTap: _showCreateFolderDialog,
          ),
          CircularMenuItem(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.5 * 255).toInt()),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
            color: Colors.blue.shade300,
            icon: Icons.password,
            onTap: _showCreateAccountDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  if (subFolders.isNotEmpty) ...[
                    Text(
                      'Folders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade300,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...subFolders.map(
                      (folder) => FolderTile(
                        folder: folder,
                        currentPath: widget.currentPath,
                        onEdit: () => _editFolder(folder),
                        onDelete: () => _deleteFolder(folder),
                        onNavigate: (newPath) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VaultScreen(
                                currentFolderKey: folder.key as int,
                                currentPath: newPath,
                              ),
                            ),
                          ).then((_) => _refreshData());
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (accounts.isNotEmpty) ...[
                    Text(
                      'Accounts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade300,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...accounts.map(
                      (account) => AccountTile(
                        account: account,
                        onTap: () => _showPasswordDialog(account),
                        onEdit: () => _editAccount(account),
                        onDelete: () => _deleteAccount(account),
                      ),
                    ),
                  ],
                  if (subFolders.isEmpty && accounts.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'This folder is empty',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          Text(
                            'Create a folder or add an account to get started',
                            style: TextStyle(color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
