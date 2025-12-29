import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_model.freezed.dart';
part 'transaction_model.g.dart';

@freezed
class TransactionModel with _$TransactionModel {
  const factory TransactionModel({
    required String id,
    required String gameId,
    required String userId,
    required String type,
    required double amount,
    required DateTime timestamp,
    String? notes,
  }) = _TransactionModel;

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      _$TransactionModelFromJson(json);
}
