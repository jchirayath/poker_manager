import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/games_provider.dart';
import 'create_game_screen.dart';
import 'game_detail_screen.dart';
import 'start_game_screen.dart';
import '../../data/models/game_model.dart';

class GamesListScreen extends ConsumerWidget {
  final String groupId;

  const GamesListScreen({required this.groupId, super.key});

  // Cache date formatter to avoid recreation
  static final DateFormat _dateFormatter = DateFormat('MMM d, yyyy HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(groupGamesProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Go back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/groups');
            }
          },
        ),
        title: const Text('Games'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Go to top',
            onPressed: () {
              final controller = PrimaryScrollController.of(context);
              if (controller.hasClients) {
                controller.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            tooltip: 'Go to bottom',
            onPressed: () {
              final controller = PrimaryScrollController.of(context);
              if (controller.hasClients) {
                controller.animateTo(
                  controller.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showGameActionMenu(context);
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: gamesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load games',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('$error', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _refresh(ref),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                CreateGameScreen(groupId: groupId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Game'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          data: (games) {
            if (games.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.casino, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        const Text('No games yet'),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    StartGameScreen(groupId: groupId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Game'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    CreateGameScreen(groupId: groupId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Game'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Single pass filtering for better performance
            final activeGames = <GameModel>[];
            final scheduledGames = <GameModel>[];
            final pastGames = <GameModel>[];

            for (final game in games) {
              if (game.status == 'in_progress') {
                activeGames.add(game);
              } else if (game.status == 'scheduled') {
                scheduledGames.add(game);
              } else if (game.status == 'completed' || game.status == 'cancelled') {
                pastGames.add(game);
              }
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                CreateGameScreen(groupId: groupId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Game'),
                    ),
                  ),
                ),
                // Active Games Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Active Games',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${activeGames.length}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (activeGames.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('No active games in progress.'),
                  )
                else
                  ...activeGames
                      .map((game) => _buildGameCard(context, game))
                      .toList(),
                const Divider(height: 32),
                // Scheduled Games Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Scheduled Games',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${scheduledGames.length}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (scheduledGames.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('No scheduled games.'),
                  )
                else
                  ...scheduledGames
                      .map((game) => _buildGameCard(context, game))
                      .toList(),
                const Divider(height: 32),
                // Past Games Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Past Games',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pastGames.length}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (pastGames.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('No past games yet.'),
                  )
                else
                  ...pastGames
                      .map((game) => _buildGameCard(context, game))
                      .toList(),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue.withValues(alpha: 0.3);
      case 'in_progress':
        return Colors.green.withValues(alpha: 0.3);
      case 'completed':
        return Colors.grey.withValues(alpha: 0.3);
      case 'cancelled':
        return Colors.red.withValues(alpha: 0.3);
      default:
        return Colors.grey.withValues(alpha: 0.3);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'Active';
      case 'scheduled':
        return 'Scheduled';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Widget _buildGameCard(BuildContext context, GameModel game) {
    final gameDate = _dateFormatter.format(game.gameDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          game.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gameDate),
            if (game.location != null)
              Text(
                '📍 ${game.location}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              'Buy-in: ${game.currency} ${game.buyinAmount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Container(
          constraints: const BoxConstraints(maxWidth: 100),
          decoration: BoxDecoration(
            color: _getStatusColor(game.status),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: Text(
            _getStatusLabel(game.status),
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GameDetailScreen(gameId: game.id),
            ),
          );
        },
      ),
    );
  }

  void _showGameActionMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.casino,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Game Options',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Start Game option
              _buildActionTile(
                context: context,
                icon: Icons.play_circle_filled,
                iconColor: colorScheme.primary,
                title: 'Start Game',
                subtitle: 'Start an existing or create a new game',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => StartGameScreen(groupId: groupId),
                    ),
                  );
                },
              ),
              // Create Game option
              _buildActionTile(
                context: context,
                icon: Icons.add_circle_outline,
                iconColor: colorScheme.secondary,
                title: 'Create Game',
                subtitle: 'Schedule a new game for later',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CreateGameScreen(groupId: groupId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await ref.refresh(groupGamesProvider(groupId).future);
  }
}
