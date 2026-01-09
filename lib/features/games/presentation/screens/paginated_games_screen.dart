import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../providers/games_pagination_provider.dart';
import '../providers/games_provider.dart';
import 'game_detail_screen.dart';
import '../../../../core/constants/business_constants.dart';

/// Example screen demonstrating paginated games list
/// 
/// This screen shows how to use the new pagination provider to load games
/// in smaller chunks, improving performance and user experience.
class PaginatedGamesScreen extends ConsumerStatefulWidget {
  final String? groupId;
  final String? statusFilter;

  const PaginatedGamesScreen({
    super.key,
    this.groupId,
    this.statusFilter,
  });

  @override
  ConsumerState<PaginatedGamesScreen> createState() => _PaginatedGamesScreenState();
}

class _PaginatedGamesScreenState extends ConsumerState<PaginatedGamesScreen> {
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageKey = GamePageKey(
      page: 1,
      pageSize: _pageSize,
      groupFilter: widget.groupId,
      statusFilter: widget.statusFilter,
    );

    final gamesAsync = ref.watch(paginatedGamesProvider(pageKey));

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final pageKey = GamePageKey(
                page: 1,
                pageSize: _pageSize,
                groupFilter: widget.groupId,
                statusFilter: widget.statusFilter,
              );
              ref.invalidate(paginatedGamesProvider(pageKey));
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: gamesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading games',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    final key = GamePageKey(
                      page: 1,
                      pageSize: _pageSize,
                      groupFilter: widget.groupId,
                      statusFilter: widget.statusFilter,
                    );
                    ref.invalidate(paginatedGamesProvider(key));
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (gamesWithGroups) {
          if (gamesWithGroups.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              final key = GamePageKey(
                page: 1,
                pageSize: _pageSize,
                groupFilter: widget.groupId,
                statusFilter: widget.statusFilter,
              );
              ref.invalidate(paginatedGamesProvider(key));
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: gamesWithGroups.length,
              itemBuilder: (context, index) {
                return _buildGameCard(context, gamesWithGroups[index]);
              },
            ),
          );
        },
      ),
    );
  }

  String _getTitle() {
    if (widget.statusFilter != null) {
      return '${widget.statusFilter![0].toUpperCase()}${widget.statusFilter!.substring(1)} Games';
    }
    return 'All Games';
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_esports_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No games found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.statusFilter != null
                  ? 'No ${widget.statusFilter} games at the moment'
                  : 'Create your first game to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(String? url, String fallback) {
    if ((url ?? '').isEmpty) {
      return Icon(
        Icons.group,
        size: 16,
        color: Theme.of(context).textTheme.bodySmall?.color,
      );
    }

    if (url!.toLowerCase().contains('svg')) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: SizedBox(
          width: 16,
          height: 16,
          child: SvgPicture.network(
            fixDiceBearUrl(url)!,
            placeholderBuilder: (_) => const SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(strokeWidth: 1),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: CircleAvatar(
        radius: 8,
        backgroundImage: NetworkImage(url),
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, GameWithGroup gameWithGroup) {
    final game = gameWithGroup.game;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Determine card color based on status
    Color? cardColor;
    IconData statusIcon;
    String statusText;

    switch (game.status) {
      case 'scheduled':
        statusIcon = Icons.schedule;
        statusText = 'Scheduled';
        cardColor = Theme.of(context).colorScheme.primaryContainer;
        break;
      case 'in_progress':
        statusIcon = Icons.play_circle_outline;
        statusText = 'In Progress';
        cardColor = Theme.of(context).colorScheme.secondaryContainer;
        break;
      case 'completed':
        statusIcon = Icons.check_circle_outline;
        statusText = 'Completed';
        cardColor = Theme.of(context).colorScheme.tertiaryContainer;
        break;
      case 'cancelled':
        statusIcon = Icons.cancel_outlined;
        statusText = 'Cancelled';
        cardColor = Theme.of(context).colorScheme.errorContainer;
        break;
      default:
        statusIcon = Icons.help_outline;
        statusText = game.status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GameDetailScreen(
                gameId: game.id,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with game name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      game.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16),
                        const SizedBox(width: 4),
                        Text(statusText),
                      ],
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Group name
              Row(
                children: [
                  _buildGroupAvatar(
                    gameWithGroup.groupAvatarUrl,
                    gameWithGroup.groupName,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      gameWithGroup.groupName,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Date and time
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(game.gameDate),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeFormat.format(game.gameDate),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),

              // Location (if available)
              if (game.location != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        game.location!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Buy-in amount
              if (game.buyinAmount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Buy-in: ${game.currency} ${game.buyinAmount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
