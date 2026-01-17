import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/game_model.dart';
import '../../data/models/game_participant_model.dart';
import '../../domain/services/seating_chart_service.dart';
import '../providers/games_provider.dart';

class SeatingChartDialog extends ConsumerStatefulWidget {
  final GameModel game;
  final List<GameParticipantModel> participants;

  const SeatingChartDialog({
    required this.game,
    required this.participants,
    super.key,
  });

  @override
  ConsumerState<SeatingChartDialog> createState() => _SeatingChartDialogState();
}

class _SeatingChartDialogState extends ConsumerState<SeatingChartDialog> {
  bool _isLoading = false;

  Future<void> _generateSeatingChart() async {
    setState(() => _isLoading = true);

    try {
      // Generate new seating chart
      final newSeatingChart = SeatingChartService.generateSeatingChart(
        widget.participants,
      );

      if (newSeatingChart.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No participants marked as "going" to generate seating chart'),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Save to database
      final result = await ref.read(gamesRepositoryProvider).updateSeatingChart(
        gameId: widget.game.id,
        seatingChart: newSeatingChart,
      );

      if (!mounted) return;

      result.when(
        success: (updatedGame) {
          setState(() => _isLoading = false);

          // Invalidate the game cache to refresh the UI for all users
          ref.invalidate(gameDetailProvider(widget.game.id));
          ref.invalidate(gameWithParticipantsProvider(widget.game.id));

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seating chart generated successfully')),
          );
        },
        failure: (error, exception) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save seating chart: $error')),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating seating chart: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the game provider to get real-time updates
    final gameAsync = ref.watch(gameDetailProvider(widget.game.id));

    return gameAsync.when(
      loading: () => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const SizedBox(
          width: 500,
          height: 600,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('Error loading game: $error'),
          ),
        ),
      ),
      data: (game) {
        final currentSeatingChart = game.seatingChart;
        final sortedSeating = SeatingChartService.getSortedSeatingChart(currentSeatingChart);
        final hasSeatingChart = currentSeatingChart != null && currentSeatingChart.isNotEmpty;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.event_seat, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Seating Chart',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : hasSeatingChart
                          ? _buildSeatingList(sortedSeating)
                          : _buildEmptyState(),
                ),

                // Footer
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasSeatingChart)
                        TextButton.icon(
                          onPressed: _isLoading ? null : _generateSeatingChart,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Regenerate'),
                        ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _isLoading
                            ? null
                            : hasSeatingChart
                                ? () => Navigator.of(context).pop()
                                : _generateSeatingChart,
                        icon: Icon(hasSeatingChart ? Icons.check : Icons.auto_awesome),
                        label: Text(hasSeatingChart ? 'Done' : 'Generate Chart'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeatingList(List<MapEntry<String, int>> sortedSeating) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedSeating.length,
      itemBuilder: (context, index) {
        final entry = sortedSeating[index];
        final participant = widget.participants.firstWhere(
          (p) => p.userId == entry.key,
          orElse: () => widget.participants.first,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                '${entry.value}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            title: Text(
              participant.displayName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('Seat ${entry.value}'),
            trailing: Icon(
              Icons.event_seat,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_seat_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Seating Chart Yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a random seating arrangement for players',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
