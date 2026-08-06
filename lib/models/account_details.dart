import 'package:hive/hive.dart';

part 'account_details.g.dart';

@HiveType(typeId: 1)
class AccountDetails extends HiveObject {
  @HiveField(0)
  String website;

  @HiveField(1)
  String encryptedPassword;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  DateTime lastModified;

  AccountDetails({
    required this.website,
    required this.encryptedPassword,
  }) : createdAt = DateTime.now(),
       lastModified = DateTime.now();
}
