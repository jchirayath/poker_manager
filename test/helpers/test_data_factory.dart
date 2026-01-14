// Test Data Factory - Comprehensive dummy data for all schema fields
// Based on Supabase schema: profiles, groups, group_members, locations,
// games, game_participants, transactions, settlements, player_statistics, group_invitations

import 'package:poker_manager/features/profile/data/models/profile_model.dart';
import 'package:poker_manager/features/groups/data/models/group_model.dart';
import 'package:poker_manager/features/groups/data/models/group_member_model.dart';
import 'package:poker_manager/features/locations/data/models/location_model.dart';
import 'package:poker_manager/features/games/data/models/game_model.dart';
import 'package:poker_manager/features/games/data/models/game_participant_model.dart';
import 'package:poker_manager/features/games/data/models/transaction_model.dart';
import 'package:poker_manager/features/settlements/data/models/settlement_model.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Factory for creating test data with all relevant schema fields
class TestDataFactory {
  // ============================================
  // PROFILES - All fields from profiles table
  // ============================================

  static ProfileModel createProfile({
    String? id,
    String? email,
    String? username,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? phoneNumber,
    String? streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    String? country,
    bool isLocalUser = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final profileId = id ?? _uuid.v4();
    final now = DateTime.now();
    return ProfileModel(
      id: profileId,
      email: email ?? 'test_${profileId.substring(0, 8)}@dummy.test',
      username: username ?? 'user_${profileId.substring(0, 8)}',
      firstName: firstName ?? 'Test',
      lastName: lastName ?? 'User',
      avatarUrl: avatarUrl ?? 'https://api.dicebear.com/7.x/avataaars/svg?seed=$profileId',
      phoneNumber: phoneNumber ?? '+1-555-${(100 + profileId.hashCode % 900).abs()}-${(1000 + profileId.hashCode % 9000).abs()}',
      streetAddress: streetAddress ?? '${(100 + profileId.hashCode % 900).abs()} Test Street',
      city: city ?? 'Test City',
      stateProvince: stateProvince ?? 'TX',
      postalCode: postalCode ?? '${(10000 + profileId.hashCode % 90000).abs()}',
      country: country ?? 'United States',
      isLocalUser: isLocalUser,
      createdAt: createdAt ?? now.subtract(const Duration(days: 30)),
      updatedAt: updatedAt ?? now,
    );
  }

  /// Create a profile with minimal required fields (for local users)
  static ProfileModel createLocalUserProfile({
    String? id,
    required String email,
    required String firstName,
    required String lastName,
    String? country,
  }) {
    return createProfile(
      id: id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      country: country,
      isLocalUser: true,
      username: null,
      phoneNumber: null,
      streetAddress: null,
      city: null,
      stateProvince: null,
      postalCode: null,
    );
  }

  /// Create multiple profiles for testing
  static List<ProfileModel> createProfiles(int count) {
    return List.generate(count, (index) => createProfile(
      firstName: 'User',
      lastName: '${index + 1}',
      email: 'user${index + 1}@dummy.test',
      username: 'user${index + 1}',
    ));
  }

  // ============================================
  // GROUPS - All fields from groups table
  // ============================================

  static GroupModel createGroup({
    String? id,
    String? name,
    String? description,
    String? avatarUrl,
    String? createdBy,
    String? privacy,
    String? defaultCurrency,
    double? defaultBuyin,
    List<double>? additionalBuyinValues,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final groupId = id ?? _uuid.v4();
    final now = DateTime.now();
    return GroupModel(
      id: groupId,
      name: name ?? 'Test Group ${groupId.substring(0, 4)}',
      description: description ?? 'A test poker group for unit testing',
      avatarUrl: avatarUrl ?? 'https://api.dicebear.com/7.x/avataaars/svg?seed=$groupId',
      createdBy: createdBy ?? _uuid.v4(),
      privacy: privacy ?? 'private',
      defaultCurrency: defaultCurrency ?? 'USD',
      defaultBuyin: defaultBuyin ?? 100.0,
      additionalBuyinValues: additionalBuyinValues ?? [50.0, 25.0],
      createdAt: createdAt ?? now.subtract(const Duration(days: 30)),
      updatedAt: updatedAt ?? now,
    );
  }

  /// Create a public group
  static GroupModel createPublicGroup({
    String? id,
    String? name,
    String? createdBy,
  }) {
    return createGroup(
      id: id,
      name: name ?? 'Public Test Group',
      privacy: 'public',
      createdBy: createdBy,
    );
  }

  // ============================================
  // GROUP_MEMBERS - All fields from group_members table
  // ============================================

  static GroupMemberModel createGroupMember({
    String? id,
    required String groupId,
    required String userId,
    String? role,
    bool isCreator = false,
    DateTime? joinedAt,
    ProfileModel? profile,
  }) {
    return GroupMemberModel(
      id: id ?? _uuid.v4(),
      groupId: groupId,
      userId: userId,
      role: role ?? (isCreator ? 'admin' : 'member'),
      isCreator: isCreator,
      joinedAt: joinedAt ?? DateTime.now().subtract(const Duration(days: 7)),
      profile: profile,
    );
  }

  /// Create admin member
  static GroupMemberModel createAdminMember({
    required String groupId,
    required String userId,
    ProfileModel? profile,
  }) {
    return createGroupMember(
      groupId: groupId,
      userId: userId,
      role: 'admin',
      isCreator: true,
      profile: profile,
    );
  }

  /// Create regular member
  static GroupMemberModel createRegularMember({
    required String groupId,
    required String userId,
    ProfileModel? profile,
  }) {
    return createGroupMember(
      groupId: groupId,
      userId: userId,
      role: 'member',
      isCreator: false,
      profile: profile,
    );
  }

  // ============================================
  // LOCATIONS - All fields from locations table
  // ============================================

  static LocationModel createLocation({
    String? id,
    String? groupId,
    String? profileId,
    String? streetAddress,
    String? city,
    String? stateProvince,
    String? postalCode,
    String? country,
    String? label,
    bool isPrimary = false,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final locationId = id ?? _uuid.v4();
    final now = DateTime.now();
    return LocationModel(
      id: locationId,
      groupId: groupId,
      profileId: profileId,
      streetAddress: streetAddress ?? '${(100 + locationId.hashCode % 900).abs()} Main St',
      city: city ?? 'Test City',
      stateProvince: stateProvince ?? 'TX',
      postalCode: postalCode ?? '78701',
      country: country ?? 'United States',
      label: label ?? 'Test Location',
      isPrimary: isPrimary,
      createdBy: createdBy,
      createdAt: createdAt ?? now.subtract(const Duration(days: 14)),
      updatedAt: updatedAt ?? now,
    );
  }

  /// Create a profile-bound location (user's home)
  static LocationModel createProfileLocation({
    required String profileId,
    String? label,
    bool isPrimary = true,
  }) {
    return createLocation(
      profileId: profileId,
      groupId: null,
      label: label ?? 'Home',
      isPrimary: isPrimary,
      createdBy: profileId,
    );
  }

  /// Create a group-bound location (neutral venue)
  static LocationModel createGroupLocation({
    required String groupId,
    String? createdBy,
    String? label,
  }) {
    return createLocation(
      groupId: groupId,
      profileId: null,
      label: label ?? 'Group Venue',
      isPrimary: false,
      createdBy: createdBy,
    );
  }

  // ============================================
  // GAMES - All fields from games table
  // ============================================

  static GameModel createGame({
    String? id,
    required String groupId,
    String? name,
    DateTime? gameDate,
    String? location,
    String? locationHostUserId,
    int? maxPlayers,
    String? currency,
    double? buyinAmount,
    List<double>? additionalBuyinValues,
    String? status,
    Map<String, dynamic>? recurrencePattern,
    String? parentGameId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final gameId = id ?? _uuid.v4();
    final now = DateTime.now();
    return GameModel(
      id: gameId,
      groupId: groupId,
      name: name ?? 'Game ${gameId.substring(0, 4)}',
      gameDate: gameDate ?? now.add(const Duration(days: 1)),
      location: location ?? '123 Poker Lane, Austin, TX 78701',
      locationHostUserId: locationHostUserId,
      maxPlayers: maxPlayers ?? 8,
      currency: currency ?? 'USD',
      buyinAmount: buyinAmount ?? 100.0,
      additionalBuyinValues: additionalBuyinValues ?? [50.0],
      status: status ?? 'scheduled',
      recurrencePattern: recurrencePattern,
      parentGameId: parentGameId,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  /// Create a scheduled game (future)
  static GameModel createScheduledGame({
    required String groupId,
    String? name,
    int daysFromNow = 2,
  }) {
    return createGame(
      groupId: groupId,
      name: name ?? 'Scheduled Game',
      gameDate: DateTime.now().add(Duration(days: daysFromNow)),
      status: 'scheduled',
    );
  }

  /// Create an in-progress game
  static GameModel createInProgressGame({
    required String groupId,
    String? name,
  }) {
    return createGame(
      groupId: groupId,
      name: name ?? 'Active Game',
      gameDate: DateTime.now().subtract(const Duration(hours: 2)),
      status: 'in_progress',
    );
  }

  /// Create a completed game
  static GameModel createCompletedGame({
    required String groupId,
    String? name,
    int daysAgo = 7,
  }) {
    return createGame(
      groupId: groupId,
      name: name ?? 'Completed Game',
      gameDate: DateTime.now().subtract(Duration(days: daysAgo)),
      status: 'completed',
    );
  }

  /// Create a cancelled game
  static GameModel createCancelledGame({
    required String groupId,
    String? name,
  }) {
    return createGame(
      groupId: groupId,
      name: name ?? 'Cancelled Game',
      gameDate: DateTime.now().subtract(const Duration(days: 3)),
      status: 'cancelled',
    );
  }

  // ============================================
  // GAME_PARTICIPANTS - All fields from game_participants table
  // ============================================

  static GameParticipantModel createGameParticipant({
    String? id,
    required String gameId,
    required String userId,
    String? rsvpStatus,
    double? totalBuyin,
    double? totalCashout,
    double? netResult,
    DateTime? createdAt,
    ProfileModel? profile,
  }) {
    final buyin = totalBuyin ?? 0.0;
    final cashout = totalCashout ?? 0.0;
    return GameParticipantModel(
      id: id ?? _uuid.v4(),
      gameId: gameId,
      userId: userId,
      rsvpStatus: rsvpStatus ?? 'going',
      totalBuyin: buyin,
      totalCashout: cashout,
      netResult: netResult ?? (cashout - buyin),
      createdAt: createdAt ?? DateTime.now(),
      profile: profile,
    );
  }

  /// Create a winning participant
  static GameParticipantModel createWinningParticipant({
    required String gameId,
    required String userId,
    double buyin = 100.0,
    double winAmount = 50.0,
    ProfileModel? profile,
  }) {
    return createGameParticipant(
      gameId: gameId,
      userId: userId,
      rsvpStatus: 'going',
      totalBuyin: buyin,
      totalCashout: buyin + winAmount,
      profile: profile,
    );
  }

  /// Create a losing participant
  static GameParticipantModel createLosingParticipant({
    required String gameId,
    required String userId,
    double buyin = 100.0,
    double lossAmount = 50.0,
    ProfileModel? profile,
  }) {
    return createGameParticipant(
      gameId: gameId,
      userId: userId,
      rsvpStatus: 'going',
      totalBuyin: buyin,
      totalCashout: buyin - lossAmount,
      profile: profile,
    );
  }

  /// Create participant who broke even
  static GameParticipantModel createBreakEvenParticipant({
    required String gameId,
    required String userId,
    double buyin = 100.0,
    ProfileModel? profile,
  }) {
    return createGameParticipant(
      gameId: gameId,
      userId: userId,
      rsvpStatus: 'going',
      totalBuyin: buyin,
      totalCashout: buyin,
      profile: profile,
    );
  }

  // ============================================
  // TRANSACTIONS - All fields from transactions table
  // ============================================

  static TransactionModel createTransaction({
    String? id,
    required String gameId,
    required String userId,
    required String type,
    required double amount,
    DateTime? timestamp,
    String? notes,
  }) {
    return TransactionModel(
      id: id ?? _uuid.v4(),
      gameId: gameId,
      userId: userId,
      type: type,
      amount: amount,
      timestamp: timestamp ?? DateTime.now(),
      notes: notes,
    );
  }

  /// Create a buy-in transaction
  static TransactionModel createBuyinTransaction({
    required String gameId,
    required String userId,
    double amount = 100.0,
    String? notes,
  }) {
    return createTransaction(
      gameId: gameId,
      userId: userId,
      type: 'buyin',
      amount: amount,
      notes: notes ?? 'Initial buy-in',
    );
  }

  /// Create a cash-out transaction
  static TransactionModel createCashoutTransaction({
    required String gameId,
    required String userId,
    required double amount,
    String? notes,
  }) {
    return createTransaction(
      gameId: gameId,
      userId: userId,
      type: 'cashout',
      amount: amount,
      notes: notes ?? 'Final cash out',
    );
  }

  /// Create additional buy-in transaction
  static TransactionModel createAdditionalBuyinTransaction({
    required String gameId,
    required String userId,
    double amount = 50.0,
  }) {
    return createTransaction(
      gameId: gameId,
      userId: userId,
      type: 'buyin',
      amount: amount,
      notes: 'Additional buy-in',
    );
  }

  // ============================================
  // SETTLEMENTS - All fields from settlements table
  // ============================================

  static SettlementModel createSettlement({
    String? id,
    required String gameId,
    required String payerId,
    required String payeeId,
    required double amount,
    String? status,
    DateTime? completedAt,
    String? payerName,
    String? payeeName,
  }) {
    return SettlementModel(
      id: id ?? _uuid.v4(),
      gameId: gameId,
      payerId: payerId,
      payeeId: payeeId,
      amount: amount,
      status: status ?? 'pending',
      completedAt: completedAt,
      payerName: payerName ?? 'Payer Name',
      payeeName: payeeName ?? 'Payee Name',
    );
  }

  /// Create a pending settlement
  static SettlementModel createPendingSettlement({
    required String gameId,
    required String payerId,
    required String payeeId,
    required double amount,
  }) {
    return createSettlement(
      gameId: gameId,
      payerId: payerId,
      payeeId: payeeId,
      amount: amount,
      status: 'pending',
    );
  }

  /// Create a completed settlement
  static SettlementModel createCompletedSettlement({
    required String gameId,
    required String payerId,
    required String payeeId,
    required double amount,
  }) {
    return createSettlement(
      gameId: gameId,
      payerId: payerId,
      payeeId: payeeId,
      amount: amount,
      status: 'completed',
      completedAt: DateTime.now(),
    );
  }

  // ============================================
  // COMPLETE TEST SCENARIOS
  // ============================================

  /// Create a complete group with members, games, and transactions
  static GroupTestScenario createCompleteGroupScenario({
    int memberCount = 5,
    int gamesPerStatus = 1,
  }) {
    final admin = createProfile(firstName: 'Admin', lastName: 'User');
    final members = createProfiles(memberCount - 1);
    final allMembers = [admin, ...members];

    final group = createGroup(createdBy: admin.id);

    final groupMembers = [
      createAdminMember(groupId: group.id, userId: admin.id, profile: admin),
      ...members.map((m) => createRegularMember(groupId: group.id, userId: m.id, profile: m)),
    ];

    final locations = [
      createGroupLocation(groupId: group.id, createdBy: admin.id),
      ...allMembers.map((m) => createProfileLocation(profileId: m.id)),
    ];

    final games = <GameModel>[];
    final participants = <GameParticipantModel>[];
    final transactions = <TransactionModel>[];
    final settlements = <SettlementModel>[];

    // Create games of different statuses
    for (var i = 0; i < gamesPerStatus; i++) {
      // Scheduled game
      final scheduledGame = createScheduledGame(groupId: group.id, name: 'Scheduled Game ${i + 1}');
      games.add(scheduledGame);
      for (final member in allMembers.take(3)) {
        participants.add(createGameParticipant(
          gameId: scheduledGame.id,
          userId: member.id,
          rsvpStatus: 'going',
          profile: member,
        ));
      }

      // In-progress game
      final inProgressGame = createInProgressGame(groupId: group.id, name: 'Active Game ${i + 1}');
      games.add(inProgressGame);
      for (final member in allMembers.take(4)) {
        participants.add(createGameParticipant(
          gameId: inProgressGame.id,
          userId: member.id,
          totalBuyin: 100.0,
          totalCashout: 0.0,
          profile: member,
        ));
        transactions.add(createBuyinTransaction(gameId: inProgressGame.id, userId: member.id));
      }

      // Completed game with settlements
      final completedGame = createCompletedGame(groupId: group.id, name: 'Completed Game ${i + 1}');
      games.add(completedGame);

      // Winner
      final winner = allMembers[0];
      participants.add(createWinningParticipant(
        gameId: completedGame.id,
        userId: winner.id,
        winAmount: 100.0,
        profile: winner,
      ));
      transactions.add(createBuyinTransaction(gameId: completedGame.id, userId: winner.id));
      transactions.add(createCashoutTransaction(gameId: completedGame.id, userId: winner.id, amount: 200.0));

      // Losers
      for (var j = 1; j < 3 && j < allMembers.length; j++) {
        final loser = allMembers[j];
        participants.add(createLosingParticipant(
          gameId: completedGame.id,
          userId: loser.id,
          lossAmount: 50.0,
          profile: loser,
        ));
        transactions.add(createBuyinTransaction(gameId: completedGame.id, userId: loser.id));
        transactions.add(createCashoutTransaction(gameId: completedGame.id, userId: loser.id, amount: 50.0));

        // Settlement from loser to winner
        settlements.add(createPendingSettlement(
          gameId: completedGame.id,
          payerId: loser.id,
          payeeId: winner.id,
          amount: 50.0,
        ));
      }

      // Cancelled game
      final cancelledGame = createCancelledGame(groupId: group.id, name: 'Cancelled Game ${i + 1}');
      games.add(cancelledGame);
    }

    return GroupTestScenario(
      group: group,
      admin: admin,
      members: allMembers,
      groupMembers: groupMembers,
      locations: locations,
      games: games,
      participants: participants,
      transactions: transactions,
      settlements: settlements,
    );
  }
}

/// Contains all data for a complete group test scenario
class GroupTestScenario {
  final GroupModel group;
  final ProfileModel admin;
  final List<ProfileModel> members;
  final List<GroupMemberModel> groupMembers;
  final List<LocationModel> locations;
  final List<GameModel> games;
  final List<GameParticipantModel> participants;
  final List<TransactionModel> transactions;
  final List<SettlementModel> settlements;

  const GroupTestScenario({
    required this.group,
    required this.admin,
    required this.members,
    required this.groupMembers,
    required this.locations,
    required this.games,
    required this.participants,
    required this.transactions,
    required this.settlements,
  });

  /// Get games by status
  List<GameModel> gamesByStatus(String status) =>
      games.where((g) => g.status == status).toList();

  /// Get scheduled games
  List<GameModel> get scheduledGames => gamesByStatus('scheduled');

  /// Get in-progress games
  List<GameModel> get inProgressGames => gamesByStatus('in_progress');

  /// Get completed games
  List<GameModel> get completedGames => gamesByStatus('completed');

  /// Get cancelled games
  List<GameModel> get cancelledGames => gamesByStatus('cancelled');

  /// Get participants for a specific game
  List<GameParticipantModel> participantsForGame(String gameId) =>
      participants.where((p) => p.gameId == gameId).toList();

  /// Get transactions for a specific game
  List<TransactionModel> transactionsForGame(String gameId) =>
      transactions.where((t) => t.gameId == gameId).toList();

  /// Get settlements for a specific game
  List<SettlementModel> settlementsForGame(String gameId) =>
      settlements.where((s) => s.gameId == gameId).toList();
}
