import 'game_model.dart';
import 'game_participant_model.dart';

/// Represents a game along with all of its participants
/// This model is used when we need to fetch both games and participants together
/// to avoid N+1 query problems
class GameWithParticipants {
  final GameModel game;
  final List<GameParticipantModel> participants;

  GameWithParticipants({
    required this.game,
    required this.participants,
  });

  /// Total number of participants in the game
  int get participantCount => participants.length;

  /// Get participants who have confirmed attendance (RSVP: going)
  List<GameParticipantModel> get confirmedParticipants {
    return participants.where((p) => p.rsvpStatus == 'going').toList();
  }

  /// Get total buy-in across all participants
  double get totalBuyin {
    return participants.fold<double>(
      0,
      (sum, p) => sum + p.totalBuyin,
    );
  }

  /// Get total cash-out across all participants
  double get totalCashout {
    return participants.fold<double>(
      0,
      (sum, p) => sum + p.totalCashout,
    );
  }

  /// Check if the game is in a valid state for adding transactions
  bool get canAddTransactions =>
      game.status == 'in_progress' || game.status == 'scheduled';

  /// Check if the game is ready for settlement calculation
  bool get canCalculateSettlements => game.status == 'completed';

  @override
  String toString() => 'GameWithParticipants(game: ${game.id}, participants: $participantCount)';
}
