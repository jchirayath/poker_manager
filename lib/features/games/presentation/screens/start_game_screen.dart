import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/games_provider.dart';
import '../../data/models/game_model.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../locations/presentation/providers/locations_provider.dart';
import '../../../locations/data/models/location_model.dart';
import 'create_game_screen.dart';

class StartGameScreen extends ConsumerStatefulWidget {
  final String groupId;

  const StartGameScreen({required this.groupId, super.key});

  @override
  ConsumerState<StartGameScreen> createState() => _StartGameScreenState();
}

class _StartGameScreenState extends ConsumerState<StartGameScreen> {
  bool _showCreateForm = false;

  // Cache date formatter to avoid recreation
  static final DateFormat _dateFormatter = DateFormat('MMM d, yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final defaultGamesAsync =
        ref.watch(defaultGroupGamesProvider(widget.groupId));
    final startGameState = ref.watch(startGameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Game'),
        centerTitle: true,
      ),
      body: startGameState.when(
        loading: () => _buildLoadingState(),
        data: (_) => _buildDefaultGamesView(defaultGamesAsync),
        error: (error, stackTrace) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('Starting game...'),
        ],
      ),
    );
  }

  Widget _buildDefaultGamesView(
    AsyncValue<List<GameModel>> defaultGamesAsync,
  ) {
    return defaultGamesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
      data: (games) {
        if (_showCreateForm) {
          return CreateGameScreen(groupId: widget.groupId);
        }

        if (games.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.casino, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No scheduled games available',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _showCreateForm = true);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Game'),
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a game to start:',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];
                  return _buildGameCard(game);
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _showCreateForm = true);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Game Instead'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameCard(GameModel game) {
    final gameDate = _dateFormatter.format(game.gameDate);

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
        trailing: ElevatedButton(
          onPressed: () => _startGame(game.id),
          child: const Text('Start'),
        ),
        onTap: () => _startGame(game.id),
      ),
    );
  }

  Future<void> _startGame(String gameId) async {
    final startGameNotifier = ref.read(startGameProvider.notifier);
    final result = await startGameNotifier.startExistingGame(gameId);

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Game "${result.name}" started!')),
      );
      // Navigate back or to game detail
      Navigator.of(context).pop(result);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start game')),
      );
    }
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error: $error',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.refresh(defaultGroupGamesProvider(widget.groupId));
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
