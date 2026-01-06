import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_model.freezed.dart';
part 'location_model.g.dart';

@freezed
abstract class LocationModel with _$LocationModel {
  const factory LocationModel({
    required String id,
    @JsonKey(name: 'group_id') String? groupId,
    @JsonKey(name: 'profile_id') String? profileId,
    @JsonKey(name: 'street_address') required String streetAddress,
    String? city,
    @JsonKey(name: 'state_province') String? stateProvince,
    @JsonKey(name: 'postal_code') String? postalCode,
    required String country,
    String? label,
    @JsonKey(name: 'is_primary') @Default(false) bool isPrimary,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _LocationModel;

  factory LocationModel.fromJson(Map<String, dynamic> json) =>
      _$LocationModelFromJson(json);
}

extension LocationModelExtension on LocationModel {
  /// Get full formatted address
  String get fullAddress {
    final parts = [
      if (streetAddress.isNotEmpty) streetAddress,
      if (city != null && city!.isNotEmpty) city,
      if (stateProvince != null && stateProvince!.isNotEmpty) stateProvince,
      if (postalCode != null && postalCode!.isNotEmpty) postalCode,
      country,
    ];

    return parts.join(', ');
  }
}

