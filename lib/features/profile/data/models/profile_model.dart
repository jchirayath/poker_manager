import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_model.freezed.dart';
part 'profile_model.g.dart';

@freezed
abstract class ProfileModel with _$ProfileModel {
  const ProfileModel._();

  const factory ProfileModel({
    required String id,
    required String email,
    String? username,
    @JsonKey(name: 'first_name') String? firstName,
    @JsonKey(name: 'last_name') String? lastName,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'phone_number') String? phoneNumber,
    @JsonKey(name: 'primary_location_id') String? primaryLocationId,
    // Legacy address fields - will be removed after migration
    @JsonKey(name: 'street_address') String? streetAddress,
    String? city,
    @JsonKey(name: 'state_province') String? stateProvince,
    @JsonKey(name: 'postal_code') String? postalCode,
    String? country,
    @JsonKey(name: 'is_local_user') @Default(false) bool isLocalUser,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _ProfileModel;

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);

  String get fullName => '${firstName ?? ""} ${lastName ?? ""}'.trim();

  // Legacy - will be removed after migration
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

  // Legacy - will be removed after migration
  bool get hasAddress =>
      streetAddress != null && streetAddress!.isNotEmpty;
}
