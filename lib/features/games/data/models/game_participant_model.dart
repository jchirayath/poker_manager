import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../profile/data/models/profile_model.dart';

part 'game_participant_model.freezed.dart';
part 'game_participant_model.g.dart';

@freezed
class GameParticipantModel with _$GameParticipantModel {
  const factory GameParticipantModel({
    required String id,
    required String gameId,
    required String userId,
    required String rsvpStatus,
    required double totalBuyin,
    required double totalCashout,
    required double netResult,
    DateTime? createdAt,
    ProfileModel? profile,
  }) = _GameParticipantModel;

  factory GameParticipantModel.fromJson(Map<String, dynamic> json) =>
      _$GameParticipantModelFromJson(json);
}
