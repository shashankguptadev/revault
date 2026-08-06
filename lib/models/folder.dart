import 'package:hive/hive.dart';

part 'folder.g.dart';

@HiveType(typeId: 0)
class Folder extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String? email; // Main account email for this folder

  @HiveField(2)
  List<int> subFolderKeys; // Hive keys of subfolders

  @HiveField(3)
  List<int> accountKeys; // Hive keys of accounts in this folder

  @HiveField(4)
  DateTime createdAt;

  Folder({
    required this.name,
    this.email,
    List<int>? subFolderKeys,
    List<int>? accountKeys,
  }) : subFolderKeys = subFolderKeys ?? [],
       accountKeys = accountKeys ?? [],
       createdAt = DateTime.now();
}
