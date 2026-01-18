import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_model.freezed.dart';
part 'group_model.g.dart';

@freezed
abstract class GroupModel with _$GroupModel {
  const factory GroupModel({
    required String id,
    required String name,
    String? description,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'created_by') required String createdBy,
    required String privacy,
    @JsonKey(name: 'default_currency') required String defaultCurrency,
    @JsonKey(name: 'default_buyin') required double defaultBuyin,
    @JsonKey(name: 'additional_buyin_values') required List<double> additionalBuyinValues,
    @JsonKey(name: 'auto_send_rsvp_emails') @Default(true) bool autoSendRsvpEmails,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _GroupModel;

  factory GroupModel.fromJson(Map<String, dynamic> json) =>
      _$GroupModelFromJson(json);
}
