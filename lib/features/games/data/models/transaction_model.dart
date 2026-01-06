import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_model.freezed.dart';
part 'transaction_model.g.dart';

@freezed
abstract class TransactionModel with _$TransactionModel {
  const TransactionModel._(); // Enable custom methods
  
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

  // Validation constants
  static const double maxTransactionAmount = 10000.0;
  static const double minTransactionAmount = 0.01;
  static const int decimalPlaces = 2;
  static const int maxNotesLength = 500;
  
  // Valid transaction types
  static const String typeBuyin = 'buyin';
  static const String typeCashout = 'cashout';
  
  static const List<String> validTypes = [
    typeBuyin,
    typeCashout,
  ];

  /// Validate transaction data - throws ArgumentError if invalid
  void validate() {
    if (id.isEmpty) {
      throw ArgumentError('Transaction ID cannot be empty');
    }
    
    if (gameId.isEmpty) {
      throw ArgumentError('Game ID cannot be empty');
    }
    
    if (userId.isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }
    
    if (!validTypes.contains(type)) {
      throw ArgumentError('Invalid transaction type: $type. Must be one of: ${validTypes.join(", ")}');
    }
    
    if (amount <= 0) {
      throw ArgumentError('Transaction amount must be positive');
    }
    
    if (amount < minTransactionAmount) {
      throw ArgumentError('Transaction amount must be at least \$$minTransactionAmount');
    }
    
    if (amount > maxTransactionAmount) {
      throw ArgumentError('Transaction amount cannot exceed \$$maxTransactionAmount');
    }
    
    // Validate decimal precision
    final amountString = amount.toStringAsFixed(decimalPlaces);
    final parsedAmount = double.parse(amountString);
    if ((amount - parsedAmount).abs() > 0.001) {
      throw ArgumentError('Transaction amount must have at most $decimalPlaces decimal places');
    }
    
    if (notes != null && notes!.length > maxNotesLength) {
      throw ArgumentError('Notes cannot exceed $maxNotesLength characters');
    }
    
    // Validate timestamp is not in the future
    if (timestamp.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw ArgumentError('Transaction timestamp cannot be in the future');
    }
  }

  /// Safe getter for display amount with currency formatting
  String get displayAmount => '\$${amount.toStringAsFixed(decimalPlaces)}';

  /// Safe getter for display notes with fallback
  String get displayNotes => notes?.trim() ?? '';

  /// Check if transaction has notes
  bool get hasNotes => notes != null && notes!.trim().isNotEmpty;

  /// Get human-readable transaction type
  String get displayType {
    switch (type) {
      case typeBuyin:
        return 'Buy-in';
      case typeCashout:
        return 'Cash-out';
      default:
        return 'Unknown';
    }
  }

  /// Check if transaction is a buy-in
  bool get isBuyin => type == typeBuyin;

  /// Check if transaction is a cash-out
  bool get isCashout => type == typeCashout;

  /// Get formatted timestamp for display
  String get formattedTimestamp {
    final date = timestamp;
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Get transaction description with type and amount
  String get description => '$displayType: $displayAmount';

  /// Get full description with notes if available
  String get fullDescription {
    final desc = description;
    return hasNotes ? '$desc - $displayNotes' : desc;
  }
}
