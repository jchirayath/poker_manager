import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_model.freezed.dart';
part 'game_model.g.dart';

@freezed
abstract class GameModel with _$GameModel {
  const GameModel._(); // Enable custom methods
  
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
    @Default(false) bool allowMemberTransactions,
    Map<String, dynamic>? seatingChart,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _GameModel;

  factory GameModel.fromJson(Map<String, dynamic> json) =>
      _$GameModelFromJson(json);

  // Validation constants
  static const double maxBuyinAmount = 10000.0;
  static const double minBuyinAmount = 0.01;
  static const int maxNameLength = 100;
  static const int maxLocationLength = 200;
  
  // Valid game statuses
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

  /// Validate game data - throws ArgumentError if invalid
  void validate() {
    if (id.isEmpty) {
      throw ArgumentError('Game ID cannot be empty');
    }
    
    if (groupId.isEmpty) {
      throw ArgumentError('Group ID cannot be empty');
    }
    
    if (name.isEmpty) {
      throw ArgumentError('Game name cannot be empty');
    }
    
    if (name.length > maxNameLength) {
      throw ArgumentError('Game name cannot exceed $maxNameLength characters');
    }
    
    if (location != null && location!.length > maxLocationLength) {
      throw ArgumentError('Location cannot exceed $maxLocationLength characters');
    }
    
    if (buyinAmount < minBuyinAmount) {
      throw ArgumentError('Buy-in amount must be at least \$$minBuyinAmount');
    }
    
    if (buyinAmount > maxBuyinAmount) {
      throw ArgumentError('Buy-in amount cannot exceed \$$maxBuyinAmount');
    }
    
    if (maxPlayers != null && maxPlayers! <= 0) {
      throw ArgumentError('Max players must be positive');
    }
    
    if (!validStatuses.contains(status)) {
      throw ArgumentError('Invalid game status: $status');
    }
    
    if (currency.isEmpty) {
      throw ArgumentError('Currency cannot be empty');
    }
  }

  /// Safe getter for display name
  String get displayName => name.trim();

  /// Safe getter for display location with fallback
  String get displayLocation => location?.trim() ?? 'Location TBD';

  /// Safe getter for display buy-in with currency
  String get displayBuyin => '\$${buyinAmount.toStringAsFixed(2)}';

  /// Check if game is in a state where transactions can be added
  bool get canAddTransactions => 
      status == statusInProgress || status == statusScheduled;

  /// Check if game can have settlements calculated
  bool get canCalculateSettlements => status == statusCompleted;

  /// Check if game is editable
  bool get isEditable => 
      status == statusScheduled || status == statusInProgress;

  /// Check if game is finalized (completed or cancelled)
  bool get isFinalized => 
      status == statusCompleted || status == statusCancelled;

  /// Check if the game date is in the past
  bool get isInPast => gameDate.isBefore(DateTime.now());

  /// Check if the game date is today
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDay = DateTime(gameDate.year, gameDate.month, gameDate.day);
    return gameDay == today;
  }

  /// Safe getter for max players with fallback
  int get displayMaxPlayers => maxPlayers ?? 0; // 0 means unlimited

  /// Check if additional buy-ins are configured
  bool get hasAdditionalBuyins => additionalBuyinValues.isNotEmpty;

  /// Get formatted game date for display
  String get formattedGameDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[gameDate.month - 1]} ${gameDate.day}, ${gameDate.year}';
  }

  /// Check if game has a seating chart
  bool get hasSeatingChart => seatingChart != null && seatingChart!.isNotEmpty;
}
