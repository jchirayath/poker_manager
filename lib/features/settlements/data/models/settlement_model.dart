import 'package:freezed_annotation/freezed_annotation.dart';

part 'settlement_model.freezed.dart';
part 'settlement_model.g.dart';

@freezed
abstract class SettlementModel with _$SettlementModel {
  const SettlementModel._(); // Enable custom methods
  
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

  // Validation constants
  static const double maxSettlementAmount = 5000.0;
  static const double minSettlementAmount = 0.01;
  static const int decimalPlaces = 2;
  
  // Valid settlement statuses
  static const String statusPending = 'pending';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  
  static const List<String> validStatuses = [
    statusPending,
    statusCompleted,
    statusCancelled,
  ];

  /// Validate settlement data - throws ArgumentError if invalid
  void validate() {
    if (id.isEmpty) {
      throw ArgumentError('Settlement ID cannot be empty');
    }
    
    if (gameId.isEmpty) {
      throw ArgumentError('Game ID cannot be empty');
    }
    
    if (payerId.isEmpty) {
      throw ArgumentError('Payer ID cannot be empty');
    }
    
    if (payeeId.isEmpty) {
      throw ArgumentError('Payee ID cannot be empty');
    }
    
    if (payerId == payeeId) {
      throw ArgumentError('Payer and payee cannot be the same person');
    }
    
    if (amount <= 0) {
      throw ArgumentError('Settlement amount must be positive');
    }
    
    if (amount < minSettlementAmount) {
      throw ArgumentError('Settlement amount must be at least \$$minSettlementAmount');
    }
    
    if (amount > maxSettlementAmount) {
      throw ArgumentError('Settlement amount cannot exceed \$$maxSettlementAmount');
    }
    
    // Validate decimal precision
    final amountString = amount.toStringAsFixed(decimalPlaces);
    final parsedAmount = double.parse(amountString);
    if ((amount - parsedAmount).abs() > 0.001) {
      throw ArgumentError('Settlement amount must have at most $decimalPlaces decimal places');
    }
    
    if (!validStatuses.contains(status)) {
      throw ArgumentError('Invalid settlement status: $status');
    }
    
    if (status == statusCompleted && completedAt == null) {
      throw ArgumentError('Completed settlements must have a completion date');
    }
  }

  /// Safe getter for display amount with currency formatting
  String get displayAmount => '\$${amount.toStringAsFixed(decimalPlaces)}';

  /// Safe getter for payer display name with fallback
  String get displayPayerName => payerName?.trim() ?? 'Unknown User';

  /// Safe getter for payee display name with fallback
  String get displayPayeeName => payeeName?.trim() ?? 'Unknown User';

  /// Get human-readable status
  String get displayStatus {
    switch (status) {
      case statusPending:
        return 'Pending';
      case statusCompleted:
        return 'Completed';
      case statusCancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  /// Check if settlement is pending
  bool get isPending => status == statusPending;

  /// Check if settlement is completed
  bool get isCompleted => status == statusCompleted;

  /// Check if settlement is cancelled
  bool get isCancelled => status == statusCancelled;

  /// Check if settlement can be marked as complete
  bool get canComplete => status == statusPending;

  /// Check if settlement can be cancelled
  bool get canCancel => status == statusPending;

  /// Get formatted completion date for display
  String? get formattedCompletedAt {
    if (completedAt == null) return null;
    final date = completedAt!;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Get human-readable settlement description
  String get description => 
      '$displayPayerName owes $displayPayeeName $displayAmount';
}

@freezed
abstract class SettlementValidation with _$SettlementValidation {
  const SettlementValidation._(); // Enable custom methods
  
  const factory SettlementValidation({
    required bool isValid,
    required double totalBuyins,
    required double totalCashouts,
    required double difference,
    required String message,
  }) = _SettlementValidation;

  // Validation constants
  static const double tolerance = 0.01; // 1 cent tolerance

  /// Check if the financial totals are balanced within tolerance
  bool get isBalanced => difference.abs() <= tolerance;

  /// Get formatted difference with currency
  String get displayDifference => '\$${difference.abs().toStringAsFixed(2)}';

  /// Get formatted total buy-ins
  String get displayTotalBuyins => '\$${totalBuyins.toStringAsFixed(2)}';

  /// Get formatted total cash-outs
  String get displayTotalCashouts => '\$${totalCashouts.toStringAsFixed(2)}';

  /// Get validation status as human-readable text
  String get validationStatus {
    if (isValid && isBalanced) {
      return 'Valid - Totals balanced';
    } else if (difference > 0) {
      return 'Invalid - More buy-ins than cash-outs ($displayDifference)';
    } else {
      return 'Invalid - More cash-outs than buy-ins ($displayDifference)';
    }
  }
}
