import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../settlements/presentation/screens/settlement_screen.dart';
import '../../data/models/game_model.dart';
import '../../data/models/transaction_model.dart';
import '../providers/games_provider.dart';
import '../widgets/game_detail/game_header_card.dart';
import '../widgets/game_detail/game_totals_card.dart';
import '../widgets/game_detail/player_quick_access.dart';
import '../widgets/game_detail/settlement_summary.dart';
import '../widgets/game_detail/player_rankings.dart';
import '../widgets/game_detail/participant_list.dart';
import '../widgets/game_detail/game_action_buttons.dart';
import '../widgets/seating_chart_dialog.dart';
import 'edit_game_screen.dart';
import '../../../stats/presentation/providers/stats_provider.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final String gameId;

  const GameDetailScreen({required this.gameId, super.key});

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  bool _shouldRefreshTransactions = true;
  bool _isStartingGame = false;
  final Map<String, Map<String, dynamic>> _settlementStatus = {};
  bool _settlementsLoaded = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _playerKeys = {};

  // Section keys for quick navigation
  final GlobalKey _settlementKey = GlobalKey(debugLabel: 'settlement_section');
  final GlobalKey _rankingsKey = GlobalKey(debugLabel: 'rankings_section');
  final GlobalKey _participantsKey = GlobalKey(debugLabel: 'participants_section');
  final GlobalKey _actionsKey = GlobalKey(debugLabel: 'actions_section');

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToPlayer(String userId) {
    final key = _playerKeys[userId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToSection(GlobalKey key) async {
    // Wait for the widget tree to build and async data to load
    await Future.delayed(const Duration(milliseconds: 200));

    if (key.currentContext != null) {
      // Use Scrollable.ensureVisible which handles nested scroll views better
      await Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.0, // Align to top of viewport
      );
    }
  }

  Future<void> _loadSettlementsFromDatabase(String gameId) async {
    try {
      final repository = ref.read(gamesRepositoryProvider);
      final result = await repository.getSettlementsForGame(gameId);
      result.when(
        success: (settlements) {
          if (mounted) {
            setState(() {
              for (final s in settlements) {
                final key = '${s['from_user_id']}|${s['to_user_id']}';
                _settlementStatus[key] = {
                  'settled': true,
                  'method': s['payment_method'],
                };
              }
            });
          }
        },
        failure: (message, errorData) {},
      );
    } catch (e) {}
  }

  Future<void> _recordSettlement(
    String fromUserId,
    String toUserId,
    double amount,
    String method,
  ) async {
    final key = '$fromUserId|$toUserId';
    setState(() {
      _settlementStatus[key] = {'settled': true, 'method': method};
    });

    try {
      final repository = ref.read(gamesRepositoryProvider);
      await repository.recordSettlement(
        gameId: widget.gameId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        paymentMethod: method,
      );
    } catch (_) {}
  }

  Future<void> _deleteSettlement(String fromUserId, String toUserId) async {
    final key = '$fromUserId|$toUserId';
    setState(() {
      _settlementStatus.remove(key);
    });

    try {
      final repository = ref.read(gamesRepositoryProvider);
      await repository.deleteSettlement(
        gameId: widget.gameId,
        fromUserId: fromUserId,
        toUserId: toUserId,
      );
    } catch (_) {}
  }

  void _invalidateProviders(String gameId, String groupId) {
    debugPrint('🔄 Invalidating providers for game $gameId');
    ref.invalidate(gameWithParticipantsProvider(gameId));
    ref.invalidate(gameTransactionsProvider(gameId));
    ref.invalidate(activeGamesProvider);
    ref.invalidate(pastGamesProvider);
    ref.invalidate(groupGamesProvider(groupId));
    // Invalidate settlement providers to clear cached settlement data
    ref.invalidate(gameSettlementsProvider(gameId));
    ref.invalidate(gameSettlementsRealtimeProvider(gameId));
    ref.invalidate(settlementValidationProvider(gameId));
    // Invalidate stats providers to refresh stats screen
    ref.invalidate(recentGamesStatsProvider);
    ref.invalidate(recentGameStatsProvider);
    ref.invalidate(groupStatsProvider(groupId));

    // Force refresh transactions
    setState(() {
      _shouldRefreshTransactions = true;
    });
    debugPrint('✅ Providers invalidated, will refresh transactions');
  }

  Future<void> _startGame(GameModel game) async {
    if (_isStartingGame) return;

    // Get participant count from the provider
    final gameWithParticipants = await ref.read(gameWithParticipantsProvider(game.id).future);
    final participantCount = gameWithParticipants.participants.length;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Game?'),
        content: Text(
          'Start the game now?\n\n'
          'This will create buy-in transactions for all $participantCount player${participantCount != 1 ? 's' : ''} '
          '(\$${game.buyinAmount.toStringAsFixed(2)} each).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start Game'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isStartingGame = true);

    try {
      debugPrint('🎮 Starting game ${game.id} with $participantCount participants');

      final result = await ref
          .read(startGameProvider.notifier)
          .startExistingGame(game.id);

      if (result != null && mounted) {
        debugPrint('✅ Game started, invalidating providers...');
        _invalidateProviders(game.id, game.groupId);

        // Wait a bit for the database to fully commit
        await Future.delayed(const Duration(milliseconds: 500));

        // Force refresh the transactions
        debugPrint('🔄 Force refreshing transactions...');
        ref.refresh(gameTransactionsProvider(game.id));
        ref.refresh(gameWithParticipantsProvider(game.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Game started! $participantCount buy-in${participantCount != 1 ? 's' : ''} recorded.'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to games list, showing Active tab
          Navigator.pop(context, {'navigateToTab': 0});
        }
      }
    } finally {
      if (mounted) setState(() => _isStartingGame = false);
    }
  }

  Future<void> _stopGame(GameModel game, List<TransactionModel> transactions) async {
    // Validate balance
    double totalBuyins = 0;
    double totalCashouts = 0;
    for (final txn in transactions) {
      if (txn.type == 'buyin') {
        totalBuyins += txn.amount;
      } else {
        totalCashouts += txn.amount;
      }
    }

    if ((totalBuyins - totalCashouts).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot stop game: Buy-ins (\$${totalBuyins.toStringAsFixed(2)}) '
            'must equal Cash-outs (\$${totalCashouts.toStringAsFixed(2)})',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop Game?'),
        content: const Text('This will mark the game as completed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop Game'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repository = ref.read(gamesRepositoryProvider);
      final result = await repository.updateGameStatus(game.id, 'completed');
      result.when(
        success: (_) {
          _invalidateProviders(game.id, game.groupId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Game completed!')),
          );
        },
        failure: (msg, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red),
          );
        },
      );
    }
  }

  Future<void> _cancelGame(GameModel game) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Game?'),
        content: const Text('This will mark the game as cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Cancel Game'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repository = ref.read(gamesRepositoryProvider);
      final result = await repository.updateGameStatus(game.id, 'cancelled');
      result.when(
        success: (_) {
          _invalidateProviders(game.id, game.groupId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Game cancelled')),
          );
        },
        failure: (msg, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red),
          );
        },
      );
    }
  }

  Future<void> _deleteGame(GameModel game) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Game?'),
        content: const Text(
          'This will permanently delete the game and all associated data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final repository = ref.read(gamesRepositoryProvider);
      final result = await repository.deleteGame(game.id);
      result.when(
        success: (_) {
          _invalidateProviders(game.id, game.groupId);
          Navigator.of(context).pop(true);
        },
        failure: (msg, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameWithParticipantsAsync = ref.watch(
      gameWithParticipantsProvider(widget.gameId),
    );

    if (_shouldRefreshTransactions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.refresh(gameTransactionsProvider(widget.gameId));
        setState(() => _shouldRefreshTransactions = false);
      });
    }

    return gameWithParticipantsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Game Details'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        // If game not found (deleted), navigate back
        final errorStr = error.toString();
        if (errorStr.contains('Game not found')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
          return Scaffold(
            appBar: AppBar(title: const Text('Game Details'), centerTitle: true),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Game Details'), centerTitle: true),
          body: Center(child: Text('Error: $error')),
        );
      },
      data: (gameWithParticipants) {
        final game = gameWithParticipants.game;
        final participants = gameWithParticipants.participants;
        final groupAsync = ref.watch(groupProvider(game.groupId));
        final transactionsAsync = ref.watch(gameTransactionsProvider(widget.gameId));

        if (!_settlementsLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadSettlementsFromDatabase(widget.gameId);
            _settlementsLoaded = true;
          });
        }

        // Initialize player keys
        for (final p in participants) {
          _playerKeys.putIfAbsent(p.userId, () => GlobalKey());
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Game Details'),
            centerTitle: true,
            actions: [
              // Seating Chart Button
              IconButton(
                icon: Icon(
                  game.hasSeatingChart ? Icons.event_seat : Icons.event_seat_outlined,
                ),
                tooltip: 'Seating Chart',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => SeatingChartDialog(
                      game: game,
                      participants: participants,
                    ),
                  );
                },
              ),
              // Start Game Button (for scheduled games)
              if (game.status == 'scheduled')
                IconButton(
                  icon: _isStartingGame
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.play_circle),
                  tooltip: 'Start Game',
                  color: Colors.green[700],
                  onPressed: _isStartingGame ? null : () => _startGame(game),
                ),
              // Stop Game Button (for in-progress games)
              if (game.status == 'in_progress')
                transactionsAsync.when(
                  data: (transactions) => IconButton(
                    icon: const Icon(Icons.stop_circle),
                    tooltip: 'Stop Game',
                    color: Colors.red[700],
                    onPressed: () => _stopGame(game, transactions),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              // Edit Button
              if (game.status == 'scheduled' || game.status == 'in_progress')
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Game',
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditGameScreen(
                          gameId: game.id,
                        ),
                      ),
                    );
                    if (result == true) {
                      ref.invalidate(gameWithParticipantsProvider(widget.gameId));
                    }
                  },
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.refresh(gameWithParticipantsProvider(widget.gameId));
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group info
                    groupAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (error, stackTrace) => const SizedBox.shrink(),
                      data: (group) {
                        if (group == null) return const SizedBox.shrink();
                        return GameHeaderCard(
                          game: game,
                          groupName: group.name,
                          groupAvatarUrl: group.avatarUrl,
                          groupPrivacy: group.privacy,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Totals card
                    transactionsAsync.when(
                      loading: () => const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      error: (error, stackTrace) => const SizedBox.shrink(),
                      data: (transactions) => GameTotalsCard(
                        game: game,
                        transactions: transactions,
                        participantCount: participants.length,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Player quick access
                    if (participants.isNotEmpty)
                      PlayerQuickAccess(
                        participants: participants,
                        onPlayerTap: _scrollToPlayer,
                      ),
                    const SizedBox(height: 16),

                    // Completed game sections
                    if (game.status == 'completed') ...[
                      transactionsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => const SizedBox.shrink(),
                        data: (transactions) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              key: _rankingsKey,
                              child: PlayerRankings(
                                game: game,
                                participants: participants,
                                transactions: transactions,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              key: _settlementKey,
                              child: SettlementSummary(
                                game: game,
                                participants: participants,
                                transactions: transactions,
                                settlementStatus: _settlementStatus,
                                onMarkSettled: _recordSettlement,
                                onResetSettlement: _deleteSettlement,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],

                    // Participants list
                    Container(
                      key: _participantsKey,
                      child: ParticipantList(
                        game: game,
                        participants: participants,
                        playerKeys: _playerKeys,
                        onRefresh: () => _invalidateProviders(game.id, game.groupId),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    transactionsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (error, stackTrace) => const SizedBox.shrink(),
                      data: (transactions) => Container(
                        key: _actionsKey,
                        child: GameActionButtons(
                          game: game,
                          transactions: transactions,
                          isStartingGame: _isStartingGame,
                          onStartGame: () => _startGame(game),
                          onStopGame: () => _stopGame(game, transactions),
                          onCancelGame: () => _cancelGame(game),
                          onDeleteGame: () => _deleteGame(game),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          // Quick navigation FAB (only for completed games)
          floatingActionButton: game.status == 'completed'
              ? FloatingActionButton(
                  onPressed: () => _showNavigationMenu(context),
                  tooltip: 'Quick Navigation',
                  child: const Icon(Icons.explore),
                )
              : null,
        );
      },
    );
  }

  void _showNavigationMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Jump to Section',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Player Rankings'),
              onTap: () {
                Navigator.pop(context);
                _scrollToSection(_rankingsKey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Settlements'),
              onTap: () {
                Navigator.pop(context);
                _scrollToSection(_settlementKey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Participants'),
              onTap: () {
                Navigator.pop(context);
                _scrollToSection(_participantsKey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Game Actions'),
              onTap: () {
                Navigator.pop(context);
                _scrollToSection(_actionsKey);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
