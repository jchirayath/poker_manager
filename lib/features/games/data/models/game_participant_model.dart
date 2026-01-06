import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../profile/data/models/profile_model.dart';

part 'game_participant_model.freezed.dart';
part 'game_participant_model.g.dart';

@freezed
abstract class GameParticipantModel with _$GameParticipantModel {
  const GameParticipantModel._(); // Enable custom methods
  
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

  // Validation constants
  static const double maxTotalAmount = 50000.0;
  static const int decimalPlaces = 2;
  
  // Valid RSVP statuses
  static const String rsvpGoing = 'going';
  static const String rsvpNotGoing = 'not_going';
  static const String rsvpMaybe = 'maybe';
  
  static const List<String> validRsvpStatuses = [
    rsvpGoing,
    rsvpNotGoing,
    rsvpMaybe,
  ];

  /// Validate participant data - throws ArgumentError if invalid
  void validate() {
    if (id.isEmpty) {
      throw ArgumentError('Participant ID cannot be empty');
    }
    
    if (gameId.isEmpty) {
      throw ArgumentError('Game ID cannot be empty');
    }
    
    if (userId.isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }
    
    if (!validRsvpStatuses.contains(rsvpStatus)) {
      throw ArgumentError('Invalid RSVP status: $rsvpStatus. Must be one of: ${validRsvpStatuses.join(", ")}');
    }
    
    if (totalBuyin < 0) {
      throw ArgumentError('Total buy-in cannot be negative');
    }
    
    if (totalCashout < 0) {
      throw ArgumentError('Total cash-out cannot be negative');
    }
    
    if (totalBuyin > maxTotalAmount) {
      throw ArgumentError('Total buy-in cannot exceed \$$maxTotalAmount');
    }
    
    if (totalCashout > maxTotalAmount) {
      throw ArgumentError('Total cash-out cannot exceed \$$maxTotalAmount');
    }
    
    // Validate net result matches calculation
    final expectedNetResult = totalCashout - totalBuyin;
    if ((netResult - expectedNetResult).abs() > 0.01) {
      throw ArgumentError('Net result ($netResult) does not match expected value ($expectedNetResult)');
    }
  }

  /// Safe getter for display total buy-in with currency formatting
  String get displayTotalBuyin => '\$${totalBuyin.toStringAsFixed(decimalPlaces)}';

  /// Safe getter for display total cash-out with currency formatting
  String get displayTotalCashout => '\$${totalCashout.toStringAsFixed(decimalPlaces)}';

  /// Safe getter for display net result with currency formatting
  String get displayNetResult {
    final formatted = '\$${netResult.abs().toStringAsFixed(decimalPlaces)}';
    if (netResult >= 0) {
      return '+$formatted';
    }
    return '-$formatted';
  }

  /// Get display name from profile or fallback
  String get displayName {
    if (profile != null) {
      final firstName = profile!.firstName?.trim() ?? '';
      final lastName = profile!.lastName?.trim() ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        return '$firstName $lastName'.trim();
      }
    }
    return 'Unknown User';
  }

  /// Get user initials for avatar
  String get initials {
    if (profile != null) {
      final firstName = profile!.firstName?.trim() ?? '';
      final lastName = profile!.lastName?.trim() ?? '';
      final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
      final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
      return '$firstInitial$lastInitial';
    }
    return 'U';
  }

  /// Get human-readable RSVP status
  String get displayRsvpStatus {
    switch (rsvpStatus) {
      case rsvpGoing:
        return 'Going';
      case rsvpNotGoing:
        return 'Not Going';
      case rsvpMaybe:
        return 'Maybe';
      default:
        return 'Unknown';
    }
  }

  /// Check if participant is going
  bool get isGoing => rsvpStatus == rsvpGoing;

  /// Check if participant is not going
  bool get isNotGoing => rsvpStatus == rsvpNotGoing;

  /// Check if participant status is maybe
  bool get isMaybe => rsvpStatus == rsvpMaybe;

  /// Check if participant is a winner (positive net result)
  bool get isWinner => netResult > 0;

  /// Check if participant is a loser (negative net result)
  bool get isLoser => netResult < 0;

  /// Check if participant broke even
  bool get isBreakEven => netResult.abs() < 0.01; // Within 1 cent

  /// Check if participant has cashed out
  bool get hasCashedOut => totalCashout > 0;

  /// Check if participant has bought in
  bool get hasBoughtIn => totalBuyin > 0;

  /// Check if participant has played (has both buy-in and cash-out)
  bool get hasPlayed => hasBoughtIn && hasCashedOut;

  /// Get participation summary
  String get participationSummary {
    if (!hasBoughtIn && !hasCashedOut) {
      return 'No transactions';
    }
    if (hasBoughtIn && !hasCashedOut) {
      return 'In game - $displayTotalBuyin';
    }
    if (hasPlayed) {
      if (isWinner) {
        return 'Won $displayNetResult';
      } else if (isLoser) {
        return 'Lost $displayNetResult';
      } else {
        return 'Broke even';
      }
    }
    return 'Unknown status';
  }

  /// Get percentage of return on investment (ROI)
  double get roi {
    if (totalBuyin == 0) return 0.0;
    return ((totalCashout - totalBuyin) / totalBuyin) * 100;
  }

  /// Get formatted ROI percentage
  String get displayRoi {
    final roiValue = roi;
    final sign = roiValue >= 0 ? '+' : '';
    return '$sign${roiValue.toStringAsFixed(1)}%';
  }
}
