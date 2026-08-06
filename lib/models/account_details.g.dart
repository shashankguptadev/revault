// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_details.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccountDetailsAdapter extends TypeAdapter<AccountDetails> {
  @override
  final int typeId = 1;

  @override
  AccountDetails read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccountDetails(
      website: fields[0] as String,
      encryptedPassword: fields[1] as String,
    )
      ..createdAt = fields[2] as DateTime
      ..lastModified = fields[3] as DateTime;
  }

  @override
  void write(BinaryWriter writer, AccountDetails obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.website)
      ..writeByte(1)
      ..write(obj.encryptedPassword)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.lastModified);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountDetailsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
