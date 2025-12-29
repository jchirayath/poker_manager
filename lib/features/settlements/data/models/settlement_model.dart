import 'package:freezed_annotation/freezed_annotation.dart';

part 'settlement_model.freezed.dart';
part 'settlement_model.g.dart';

@freezed
class SettlementModel with _$SettlementModel {
  const factory SettlementModel({
    required String id,
    required String gameId,
    required String payerId,
    required String payeeId,
    required double amount,
    required String status,
    DateTime? completedAt,
    String? payerName,
    String? payeeName,
  }) = _SettlementModel;

  factory SettlementModel.fromJson(Map<String, dynamic> json) =>
      _$SettlementModelFromJson(json);
}

@freezed
class SettlementValidation with _$SettlementValidation {
  const factory SettlementValidation({
    required bool isValid,
    required double totalBuyins,
    required double totalCashouts,
    required double difference,
    required String message,
  }) = _SettlementValidation;
}
