import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_model.freezed.dart';
part 'game_model.g.dart';

@freezed
class GameModel with _$GameModel {
  const factory GameModel({
    required String id,
    required String groupId,
    required String name,
    required DateTime gameDate,
    String? location,
    String? locationHostUserId,
    int? maxPlayers,
    required String currency,
    required double buyinAmount,
    required List<double> additionalBuyinValues,
    required String status,
    Map<String, dynamic>? recurrencePattern,
    String? parentGameId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _GameModel;

  factory GameModel.fromJson(Map<String, dynamic> json) =>
      _$GameModelFromJson(json);
}
