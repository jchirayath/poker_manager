/// Business Constants - Single source of truth for all app constants
/// 
/// This file centralizes all business rules, magic strings, and validation
/// constants used throughout the application. This ensures consistency and
/// makes maintenance easier.
/// 
/// Date: January 5, 2026
/// Purpose: Address Security Risk 2.4 - Hardcoded Magic Strings

// =============================================================================
// FINANCIAL CONSTANTS
// =============================================================================

/// Constants for financial validation and calculations
class FinancialConstants {
  // Transaction limits
  static const double minTransactionAmount = 0.01;
  static const double maxTransactionAmount = 10000.00;
  
  // Settlement limits
  static const double minSettlementAmount = 0.01;
  static const double maxSettlementAmount = 5000.00;
  
  // Buyin limits (per game)
  static const double minBuyinAmount = 0.01;
  static const double maxBuyinAmount = 10000.0;
  
  // Financial reconciliation
  static const double buyinCashoutTolerance = 0.01; // 1 cent tolerance
  static const int currencyDecimalPlaces = 2;
  
  // Participant limits
  static const double maxTotalAmount = 50000.0; // Max total buyin/cashout per participant
}

// =============================================================================
// GAME CONSTANTS
// =============================================================================

/// Constants related to game management
class GameConstants {
  // Game statuses
  static const String statusScheduled = 'scheduled';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  
  static const List<String> validStatuses = [
    statusScheduled,
    statusInProgress,
    statusCompleted,
    statusCancelled,
  ];
  
  // Validation limits
  static const int maxNameLength = 100;
  static const int maxLocationLength = 200;
  static const int minPlayers = 2;
  static const int maxPlayers = 50;
  
  // Default values
  static const String defaultCurrency = 'USD';
  static const String defaultStatus = statusScheduled;
}

// =============================================================================
// SETTLEMENT CONSTANTS
// =============================================================================

/// Constants related to settlement management
class SettlementConstants {
  // Settlement statuses
  static const String statusPending = 'pending';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  
  static const List<String> validStatuses = [
    statusPending,
    statusCompleted,
    statusCancelled,
  ];
  
  // Default values
  static const String defaultStatus = statusPending;
}

// =============================================================================
// PARTICIPANT CONSTANTS
// =============================================================================

/// Constants related to game participants and RSVP
class ParticipantConstants {
  // RSVP statuses
  static const String rsvpGoing = 'going';
  static const String rsvpNotGoing = 'not_going';
  static const String rsvpMaybe = 'maybe';
  
  static const List<String> validRsvpStatuses = [
    rsvpGoing,
    rsvpNotGoing,
    rsvpMaybe,
  ];
  
  // Default values
  static const String defaultRsvpStatus = rsvpMaybe;
  
  // Validation
  static const int decimalPlaces = 2;
}

// =============================================================================
// TRANSACTION CONSTANTS
// =============================================================================

/// Constants related to transactions (buyins and cashouts)
class TransactionConstants {
  // Transaction types
  static const String typeBuyin = 'buyin';
  static const String typeCashout = 'cashout';
  
  static const List<String> validTypes = [
    typeBuyin,
    typeCashout,
  ];
  
  // Validation limits
  static const int maxNotesLength = 500;
  static const int decimalPlaces = 2;
  
  // Time validation (tolerance for future timestamps to account for clock skew)
  static const Duration futureTolerance = Duration(minutes: 5);
}

// =============================================================================
// GROUP & ROLE CONSTANTS
// =============================================================================

/// Constants related to groups and user roles
class RoleConstants {
  // Group member roles
  static const String creator = 'creator';
  static const String admin = 'admin';
  static const String member = 'member';
  
  static const List<String> validRoles = [
    creator,
    admin,
    member,
  ];
  
  // Role hierarchy (for permission checks)
  static const Map<String, int> roleHierarchy = {
    creator: 3,
    admin: 2,
    member: 1,
  };
  
  /// Check if a role has permission (equal or higher than required role)
  static bool hasPermission(String userRole, String requiredRole) {
    final userLevel = roleHierarchy[userRole] ?? 0;
    final requiredLevel = roleHierarchy[requiredRole] ?? 999;
    return userLevel >= requiredLevel;
  }
}

/// Constants related to groups
class GroupConstants {
  // Validation limits
  static const int maxGroupNameLength = 100;
  static const int maxDescriptionLength = 500;
  static const int minGroupNameLength = 3;
  static const int maxMembersPerGroup = 100;
}

// =============================================================================
// VALIDATION HELPERS
// =============================================================================

/// Shared validation helper functions
class ValidationHelpers {
  /// Validate amount is within bounds and properly formatted
  static String? validateAmount(
    double amount, {
    double minAmount = FinancialConstants.minTransactionAmount,
    double maxAmount = FinancialConstants.maxTransactionAmount,
    String context = 'Amount',
  }) {
    if (amount.isNaN || amount.isInfinite) {
      return '$context must be a valid number';
    }
    if (amount < 0) {
      return '$context cannot be negative';
    }
    if (amount < minAmount && amount > 0) {
      return '$context must be at least \$${minAmount.toStringAsFixed(2)}';
    }
    if (amount > maxAmount) {
      return '$context exceeds maximum of \$${maxAmount.toStringAsFixed(2)}';
    }
    
    // Check decimal precision
    final amountAsString = amount.toStringAsFixed(FinancialConstants.currencyDecimalPlaces);
    final parsedAmount = double.tryParse(amountAsString) ?? amount;
    if ((amount - parsedAmount).abs() > 0.001) {
      return '$context must have at most ${FinancialConstants.currencyDecimalPlaces} decimal places';
    }
    
    return null;
  }

  /// Round amount to currency decimal places
  static double roundToCurrency(double amount) {
    return double.parse(
      amount.toStringAsFixed(FinancialConstants.currencyDecimalPlaces),
    );
  }
  
  /// Check if two amounts are equal within tolerance
  static bool areAmountsEqual(double amount1, double amount2, {double? tolerance}) {
    return (amount1 - amount2).abs() <= (tolerance ?? FinancialConstants.buyinCashoutTolerance);
  }
  
  /// Validate string length
  static String? validateStringLength(
    String? value, {
    required int maxLength,
    int minLength = 1,
    required String fieldName,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (value.trim().length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (value.length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }
    return null;
  }
  
  /// Validate enum value is in allowed list
  static String? validateEnum(
    String value,
    List<String> validValues,
    String fieldName,
  ) {
    if (!validValues.contains(value)) {
      return 'Invalid $fieldName: "$value". Must be one of: ${validValues.join(", ")}';
    }
    return null;
  }
}

// =============================================================================
// UI CONSTANTS
// =============================================================================

/// Constants for UI display and formatting
class UIConstants {
  // Currency formatting
  static const String currencySymbol = '\$';
  static const String defaultCurrencyCode = 'USD';
  
  // Date/Time formats
  static const String displayDateFormat = 'MMM d, y';
  static const String displayTimeFormat = 'h:mm a';
  static const String displayDateTimeFormat = 'MMM d, y h:mm a';
  
  // Empty state messages
  static const String noGamesMessage = 'No games found';
  static const String noSettlementsMessage = 'No settlements yet';
  static const String noTransactionsMessage = 'No transactions recorded';
  static const String noParticipantsMessage = 'No participants yet';
  
  // Loading messages
  static const String loadingMessage = 'Loading...';
  static const String savingMessage = 'Saving...';
  static const String calculatingMessage = 'Calculating...';
}
