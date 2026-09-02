import 'package:hive/hive.dart';
import '../models/folder.dart';
import '../models/account_details.dart';
import 'encryption_service.dart';

class VaultService {
  static late Box<Folder> folderBox;
  static late Box<AccountDetails> accountBox;

  static const int rootFolderKey = 0;

  static Future<void> init() async {
    folderBox = await Hive.openBox<Folder>('folders');
    accountBox = await Hive.openBox<AccountDetails>('accounts');
    // Create root folder if it doesn't exist
    if (!folderBox.containsKey(rootFolderKey)) {
      final rootFolder = Folder(name: 'VAULT');
      await folderBox.put(rootFolderKey, rootFolder);
    }
  }

  static Folder getRootFolder() {
    return folderBox.get(rootFolderKey)!;
  }

  static Future<Folder> createFolder({
    required String name,
    required int parentFolderKey,
    String? email,
  }) async {
    final newFolder = Folder(name: name, email: email);
    final newFolderKey = await folderBox.add(newFolder);
    // Add to parent folder
    final parentFolder = folderBox.get(parentFolderKey)!;
    parentFolder.subFolderKeys.add(newFolderKey);
    await parentFolder.save();

    return newFolder;
  }

  static Future<AccountDetails> createAccount({
    required String website,
    required String password,
    required int parentFolderKey,
  }) async {
    final encryptedPassword = await EncryptionService.encryptPassword(password);
    final newAccount = AccountDetails(
      website: website,
      encryptedPassword: encryptedPassword,
    );
    final newAccountKey = await accountBox.add(newAccount);
    // Add to parent folder
    final parentFolder = folderBox.get(parentFolderKey)!;
    parentFolder.accountKeys.add(newAccountKey);
    await parentFolder.save();

    return newAccount;
  }

  static Future<String> getDecryptedPassword(AccountDetails account) async {
    return await EncryptionService.decryptPassword(account.encryptedPassword);
  }

  static Future<void> deleteFolder(int folderKey) async {
    final folder = folderBox.get(folderKey);
    if (folder != null) {
      // create copies of the lists to avoid modification during iteration
      final subFolderKeysCopy = List<int>.from(folder.subFolderKeys);
      final accountKeysCopy = List<int>.from(folder.accountKeys);

      // recursively delete subfolders first
      for (final subFolderKey in subFolderKeysCopy) {
        await deleteFolder(subFolderKey);
      }

      // delete all accounts in this folder
      for (final accountKey in accountKeysCopy) {
        await deleteAccount(accountKey);
      }

      // remove this folder from all parent folders
      final allFolders = folderBox.values.toList();
      for (final parentFolder in allFolders) {
        if (parentFolder.subFolderKeys.contains(folderKey)) {
          parentFolder.subFolderKeys.remove(folderKey);
          await parentFolder.save();
        }
      }

      // finally delete the folder itself
      await folderBox.delete(folderKey);
    }
  }

  static Future<void> deleteAccount(int accountKey) async {
    final account = accountBox.get(accountKey);
    if (account != null) {
      // remove from all parent folders
      final allFolders = folderBox.values.toList();
      for (final parentFolder in allFolders) {
        if (parentFolder.accountKeys.contains(accountKey)) {
          parentFolder.accountKeys.remove(accountKey);
          await parentFolder.save();
        }
      }
      await accountBox.delete(accountKey);
    }
  }

  static Future<void> updateAccount({
    required int accountKey,
    required String website,
    String? password,
  }) async {
    final account = accountBox.get(accountKey);
    if (account != null) {
      account.website = website;
      account.lastModified = DateTime.now();
      if (password != null) {
        account.encryptedPassword = await EncryptionService.encryptPassword(
          password,
        );
      }

      await account.save();
    }
  }

  static Future<void> updateFolder({
    required int folderKey,
    required String name,
    String? email,
  }) async {
    final folder = folderBox.get(folderKey);
    if (folder != null) {
      folder.name = name;
      folder.email = email;
      await folder.save();
    }
  }

  // helper method to get folder counts (for instant updates)
  static (int folders, int accounts) getFolderCounts(Folder folder) {
    final subFolders = folder.subFolderKeys
        .map((key) => folderBox.get(key))
        .whereType<Folder>()
        .toList();
    final accounts = folder.accountKeys
        .map((key) => accountBox.get(key))
        .whereType<AccountDetails>()
        .toList();

    return (subFolders.length, accounts.length);
  }

  static Future<void> clearAllData() async {
    await folderBox.clear();
    await accountBox.clear();
    // Re-create root folder
    final rootFolder = Folder(name: 'VAULT');
    await folderBox.put(rootFolderKey, rootFolder);
  }
}
