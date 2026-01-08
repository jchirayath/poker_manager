import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/games_provider.dart';
import 'create_game_screen.dart';
import 'game_detail_screen.dart';
import 'start_game_screen.dart';
import '../../data/models/game_model.dart';

class GamesListScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GamesListScreen({required this.groupId, super.key});

  @override
  ConsumerState<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends ConsumerState<GamesListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(groupGamesProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Games'),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_downward, size: 20),
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
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
                                CreateGameScreen(groupId: widget.groupId),
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
                controller: _scrollController,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.casino, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No games yet'),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    StartGameScreen(groupId: widget.groupId),
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
                                    CreateGameScreen(groupId: widget.groupId),
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

            final activeGames =
                games.where((game) => game.status == 'in_progress').toList();
            final scheduledGames =
                games.where((game) => game.status == 'scheduled').toList();
            final pastGames = games
                .where((game) =>
                    game.status == 'completed' || game.status == 'cancelled')
                .toList();

            return ListView(
              controller: _scrollController,
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
                                CreateGameScreen(groupId: widget.groupId),
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
                  child: Text(
                    'Active Games',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                  child: Text(
                    'Scheduled Games',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                  child: Text(
                    'Past Games',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
    final dateFormatter = DateFormat('MMM d, yyyy HH:mm');
    final gameDate = dateFormatter.format(game.gameDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(game.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gameDate),
            if (game.location != null) Text('📍 ${game.location}'),
            Text(
              'Buy-in: ${game.currency} ${game.buyinAmount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Container(
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
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Start Game'),
              subtitle:
                  const Text('Start an existing or create a new game'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        StartGameScreen(groupId: widget.groupId),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Create Game'),
              subtitle: const Text('Create a new scheduled game'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateGameScreen(groupId: widget.groupId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await ref.refresh(groupGamesProvider(widget.groupId).future);
  }
}
