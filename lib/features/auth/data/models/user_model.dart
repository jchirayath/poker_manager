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
    @JsonKey(name: 'first_name') required String firstName,
    @JsonKey(name: 'last_name') required String lastName,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'phone_number') String? phoneNumber,
    @JsonKey(name: 'street_address') String? streetAddress,
    String? city,
    @JsonKey(name: 'state_province') String? stateProvince,
    @JsonKey(name: 'postal_code') String? postalCode,
    required String country,
    @JsonKey(name: 'created_at') DateTime? createdAt,
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
