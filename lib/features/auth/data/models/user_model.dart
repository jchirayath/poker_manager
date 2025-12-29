import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const UserModel._();
  
  const factory UserModel({
    required String id,
    required String email,
    String? username,
    required String firstName,
    required String lastName,
    String? avatarUrl,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    required String country,
    DateTime? createdAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
      
  String get fullName => '$firstName $lastName';

  String get fullAddress {
    final parts = [
      streetAddress,
      city,
      stateProvince,
      postalCode,
      country,
    ].where((part) => part != null && part.isNotEmpty);

    return parts.join(', ');
  }

  bool get hasAddress =>
      streetAddress != null && streetAddress!.isNotEmpty;
}
