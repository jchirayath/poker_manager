import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../profile/data/models/profile_model.dart';

part 'group_member_model.freezed.dart';
part 'group_member_model.g.dart';

@freezed
abstract class GroupMemberModel with _$GroupMemberModel {
  const factory GroupMemberModel({
    required String id,
    @JsonKey(name: 'group_id') required String groupId,
    @JsonKey(name: 'user_id') required String userId,
    required String role,
    @JsonKey(name: 'is_creator') required bool isCreator,
    @JsonKey(name: 'joined_at') required DateTime joinedAt,
    ProfileModel? profile,
  }) = _GroupMemberModel;

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) =>
      _$GroupMemberModelFromJson(json);
}
