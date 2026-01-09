import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/avatar_utils.dart';
import 'games_group_selector_screen.dart';
import 'game_detail_screen.dart';
import '../providers/games_provider.dart';
import '../../../locations/presentation/providers/locations_provider.dart';
import '../../../common/widgets/app_drawer.dart';

class GamesEntryScreen extends ConsumerStatefulWidget {
  const GamesEntryScreen({super.key});

  @override
  ConsumerState<GamesEntryScreen> createState() => _GamesEntryScreenState();
}

class _GamesEntryScreenState extends ConsumerState<GamesEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openGameDetail(BuildContext context, String gameId) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameDetailScreen(gameId: gameId),
      ),
    );
    if (result == true) {
      // Game was cancelled, refresh providers
      ref.invalidate(activeGamesProvider);
      ref.invalidate(pastGamesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeGamesAsync = ref.watch(activeGamesProvider);
    final pastGamesAsync = ref.watch(pastGamesProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Games'),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.play_circle), text: 'Active'),
            Tab(icon: Icon(Icons.schedule), text: 'Scheduled'),
            Tab(icon: Icon(Icons.check_circle), text: 'Completed'),
            Tab(icon: Icon(Icons.cancel), text: 'Cancelled'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGameOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('Create Game'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Active Games Tab
          _GamesTabContent(
            gamesAsync: activeGamesAsync,
            filterStatus: 'in_progress',
            emptyMessage: 'No active games',
            onGameTap: (gameId) => _openGameDetail(context, gameId),
            onRefresh: () async {
              ref.invalidate(activeGamesProvider);
              ref.invalidate(pastGamesProvider);
            },
          ),
          // Scheduled Games Tab
          _GamesTabContent(
            gamesAsync: activeGamesAsync,
            filterStatus: 'scheduled',
            emptyMessage: 'No scheduled games',
            onGameTap: (gameId) => _openGameDetail(context, gameId),
            onRefresh: () async {
              ref.invalidate(activeGamesProvider);
              ref.invalidate(pastGamesProvider);
            },
          ),
          // Completed Games Tab
          _GamesTabContent(
            gamesAsync: pastGamesAsync,
            filterStatus: 'completed',
            emptyMessage: 'No completed games',
            onGameTap: (gameId) => _openGameDetail(context, gameId),
            onRefresh: () async {
              ref.invalidate(activeGamesProvider);
              ref.invalidate(pastGamesProvider);
            },
          ),
          // Cancelled Games Tab
          _GamesTabContent(
            gamesAsync: pastGamesAsync,
            filterStatus: 'cancelled',
            emptyMessage: 'No cancelled games',
            onGameTap: (gameId) => _openGameDetail(context, gameId),
            onRefresh: () async {
              ref.invalidate(activeGamesProvider);
              ref.invalidate(pastGamesProvider);
            },
          ),
        ],
      ),
    );
  }

  void _showCreateGameOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              'Create a New Game',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const GamesGroupSelectorScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.group),
                label: const Text('Select Existing Group'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/groups/create');
                },
                icon: const Icon(Icons.add),
                label: const Text('Create New Group'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Tab content widget for each game status
class _GamesTabContent extends StatelessWidget {
  final AsyncValue<List<GameWithGroup>> gamesAsync;
  final String filterStatus;
  final String emptyMessage;
  final void Function(String gameId) onGameTap;
  final Future<void> Function() onRefresh;

  const _GamesTabContent({
    required this.gamesAsync,
    required this.filterStatus,
    required this.emptyMessage,
    required this.onGameTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: gamesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error loading games: $error'),
          ),
        ),
        data: (allGames) {
          final filteredGames = allGames
              .where((gwg) => gwg.game.status == filterStatus)
              .toList();

          if (filteredGames.isEmpty) {
            return ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getIconForStatus(filterStatus),
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          emptyMessage,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredGames.length,
            itemBuilder: (context, index) {
              final gwg = filteredGames[index];
              return _GameCard(
                key: ValueKey(gwg.game.id),
                gameWithGroup: gwg,
                onTap: () => onGameTap(gwg.game.id),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'in_progress':
        return Icons.play_circle;
      case 'scheduled':
        return Icons.schedule;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}

class _GameCard extends StatelessWidget {
  final GameWithGroup gameWithGroup;
  final VoidCallback onTap;

  const _GameCard({
    super.key,
    required this.gameWithGroup,
    required this.onTap,
  });

  // Cache date formatters to avoid recreation
  static final DateFormat _dateFormatter = DateFormat('MMM d, yyyy');
  static final DateFormat _timeFormatter = DateFormat('h:mm a');

  static Widget _buildGroupAvatar(String? url, String fallback, BuildContext context) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : 'G';
    if ((url ?? '').isEmpty) {
      return Icon(
        Icons.group,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
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

  @override
  Widget build(BuildContext context) {
    final game = gameWithGroup.game;

    Color iconColor;
    IconData iconData;
    Color backgroundColor;
    
    switch (game.status) {
      case 'in_progress':
        iconColor = Colors.white;
        iconData = Icons.play_arrow;
        backgroundColor = Colors.green;
        break;
      case 'completed':
        iconColor = Colors.white;
        iconData = Icons.check_circle;
        backgroundColor = Colors.blue;
        break;
      case 'cancelled':
        iconColor = Colors.white;
        iconData = Icons.cancel;
        backgroundColor = Colors.grey;
        break;
      default: // scheduled
        iconColor = Colors.white;
        iconData = Icons.schedule;
        backgroundColor = Colors.orange;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: backgroundColor,
          child: Icon(iconData, color: iconColor),
        ),
        title: Row(
          children: [
            _buildGroupAvatar(
              gameWithGroup.groupAvatarUrl,
              gameWithGroup.groupName,
              context,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                gameWithGroup.groupName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (game.name.isNotEmpty)
              Text(
                game.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${_dateFormatter.format(game.gameDate)} at ${_timeFormatter.format(game.gameDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (game.location?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              _LocationDisplay(
                location: game.location!,
                groupId: gameWithGroup.groupId,
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _LocationDisplay extends ConsumerWidget {
  final String location;
  final String groupId;

  const _LocationDisplay({
    required this.location,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if location looks like a UUID
    final isUuid = location.length == 36 && location.contains('-');
    
    if (!isUuid) {
      // Already a readable address
      return Row(
        children: [
          const Icon(Icons.location_on, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              location,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    // Need to look up the location
    final locationsAsync = ref.watch(groupLocationsProvider(groupId));
    
    return locationsAsync.when(
      loading: () => Row(
        children: [
          const Icon(Icons.location_on, size: 12),
          const SizedBox(width: 4),
          Text(
            'Loading...',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (locations) {
        try {
          final foundLocation = locations.firstWhere(
            (loc) => loc.id == location,
          );
          
          // Build address string manually
          final parts = [
            if (foundLocation.streetAddress.isNotEmpty) foundLocation.streetAddress,
            if (foundLocation.city?.isNotEmpty == true) foundLocation.city,
            if (foundLocation.stateProvince?.isNotEmpty == true) foundLocation.stateProvince,
            if (foundLocation.postalCode?.isNotEmpty == true) foundLocation.postalCode,
            foundLocation.country,
          ];
          final addressString = parts.join(', ');
          final displayText = foundLocation.label ?? addressString;
          
          return Row(
            children: [
              const Icon(Icons.location_on, size: 12),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        } catch (e) {
          // Location not found
          return const SizedBox.shrink();
        }
      },
    );
  }
}
