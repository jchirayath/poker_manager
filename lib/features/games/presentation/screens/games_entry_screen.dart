import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/constants/business_constants.dart';
import '../../../../core/utils/avatar_utils.dart';
import 'games_group_selector_screen.dart';
import 'game_detail_screen.dart';
import 'create_game_screen.dart';
import '../providers/games_provider.dart';
import '../../../locations/presentation/providers/locations_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../common/widgets/app_drawer.dart';

class GamesEntryScreen extends ConsumerStatefulWidget {
  const GamesEntryScreen({super.key, this.groupId, this.initialTabIndex = 0});

  /// Optional group ID to filter games for a specific group.
  /// When provided, only games from this group are shown.
  final String? groupId;

  /// Initial tab index to show (0=Active, 1=Scheduled, 2=Completed, 3=Cancelled)
  final int initialTabIndex;

  @override
  ConsumerState<GamesEntryScreen> createState() => _GamesEntryScreenState();
}

class _GamesEntryScreenState extends ConsumerState<GamesEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isGroupSpecific => widget.groupId != null;

  Future<void> _openGameDetail(BuildContext context, String gameId) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameDetailScreen(gameId: gameId),
      ),
    );

    // Refresh games
    _refreshGames();

    // Handle tab navigation if result is provided
    if (result is Map && result['navigateToTab'] != null) {
      final tabIndex = result['navigateToTab'] as int;
      _tabController.animateTo(tabIndex);
    }
  }

  void _refreshGames() {
    if (_isGroupSpecific) {
      ref.invalidate(groupGamesWithGroupInfoProvider(widget.groupId!));
    } else {
      ref.invalidate(activeGamesProvider);
      ref.invalidate(pastGamesProvider);
    }
  }

  void _navigateToCreateGame(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateGameScreen(groupId: widget.groupId!),
      ),
    ).then((result) {
      _refreshGames();
      // Handle tab navigation if result is provided
      if (result is Map && result['navigateToTab'] != null) {
        final tabIndex = result['navigateToTab'] as int;
        _tabController.animateTo(tabIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use group-specific provider if groupId is provided, otherwise use global providers
    final AsyncValue<List<GameWithGroup>> activeGamesAsync;
    final AsyncValue<List<GameWithGroup>> pastGamesAsync;

    if (_isGroupSpecific) {
      // For group-specific view, use the same provider for both active and past
      // The filtering happens in _GamesTabContent
      final groupGamesAsync = ref.watch(groupGamesWithGroupInfoProvider(widget.groupId!));
      activeGamesAsync = groupGamesAsync;
      pastGamesAsync = groupGamesAsync;
    } else {
      activeGamesAsync = ref.watch(activeGamesProvider);
      pastGamesAsync = ref.watch(pastGamesProvider);
    }

    // Get group name for title if group-specific
    final groupAsync = _isGroupSpecific
        ? ref.watch(groupProvider(widget.groupId!))
        : null;
    final groupName = groupAsync?.whenOrNull(data: (group) => group?.name);

    // Calculate game counts for each status
    int activeCount = 0;
    int scheduledCount = 0;
    int completedCount = 0;
    int cancelledCount = 0;

    if (UIConstants.showGameCountsInTabs) {
      activeGamesAsync.whenData((games) {
        activeCount = games.where((g) => g.game.status == 'in_progress').length;
        scheduledCount = games.where((g) => g.game.status == 'scheduled').length;
      });
      pastGamesAsync.whenData((games) {
        completedCount = games.where((g) => g.game.status == 'completed').length;
        cancelledCount = games.where((g) => g.game.status == 'cancelled').length;
      });
    }

    return Scaffold(
      drawer: _isGroupSpecific ? null : const AppDrawer(),
      appBar: AppBar(
        title: Text(groupName != null ? '$groupName Games' : 'Games'),
        centerTitle: true,
        leading: _isGroupSpecific
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              icon: const Icon(Icons.play_circle),
              text: UIConstants.showGameCountsInTabs
                  ? 'Active ($activeCount)'
                  : 'Active',
            ),
            Tab(
              icon: const Icon(Icons.schedule),
              text: UIConstants.showGameCountsInTabs
                  ? 'Scheduled ($scheduledCount)'
                  : 'Scheduled',
            ),
            Tab(
              icon: const Icon(Icons.check_circle),
              text: UIConstants.showGameCountsInTabs
                  ? 'Completed ($completedCount)'
                  : 'Completed',
            ),
            Tab(
              icon: const Icon(Icons.cancel),
              text: UIConstants.showGameCountsInTabs
                  ? 'Cancelled ($cancelledCount)'
                  : 'Cancelled',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _isGroupSpecific
            ? _navigateToCreateGame(context)
            : _showCreateGameOptions(context),
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
            onRefresh: () async => _refreshGames(),
            showGroupInfo: !_isGroupSpecific,
          ),
          // Scheduled Games Tab
          _GamesTabContent(
            gamesAsync: activeGamesAsync,
            filterStatus: 'scheduled',
            emptyMessage: 'No scheduled games',
            onGameTap: (gameId) => _openGameDetail(context, gameId),
            onRefresh: () async => _refreshGames(),
            showGroupInfo: !_isGroupSpecific,
          ),
          // Completed Games Tab
          _GamesTabContent(
            gamesAsync: pastGamesAsync,
            filterStatus: 'completed',
            emptyMessage: 'No completed games',
            onGameTap: (gameId) => _openGameDetail(context, gameId),
            onRefresh: () async => _refreshGames(),
            showGroupInfo: !_isGroupSpecific,
          ),
          // Cancelled Games Tab
          _GamesTabContent(
            gamesAsync: pastGamesAsync,
            filterStatus: 'cancelled',
            emptyMessage: 'No cancelled games',
            onGameTap: (gameId) => _openGameDetail(context, gameId),
            onRefresh: () async => _refreshGames(),
            showGroupInfo: !_isGroupSpecific,
          ),
        ],
      ),
    );
  }

  void _showCreateGameOptions(BuildContext context) {
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
                      Icons.add_circle,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Create a New Game',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Choose how you want to create your game',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              // Select Existing Group option
              _buildCreateGameTile(
                context: context,
                icon: Icons.group,
                iconColor: colorScheme.primary,
                title: 'Select Existing Group',
                subtitle: 'Create a game in one of your groups',
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const GamesGroupSelectorScreen(),
                    ),
                  );

                  // Handle tab navigation if result is provided
                  if (result is Map && result['navigateToTab'] != null) {
                    _refreshGames();
                    final tabIndex = result['navigateToTab'] as int;
                    _tabController.animateTo(tabIndex);
                  }
                },
              ),
              // Create New Group option
              _buildCreateGameTile(
                context: context,
                icon: Icons.group_add,
                iconColor: colorScheme.secondary,
                title: 'Create New Group',
                subtitle: 'Start fresh with a new poker group',
                onTap: () {
                  Navigator.pop(context);
                  context.push(RouteConstants.createGroup);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateGameTile({
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
}

// Tab content widget for each game status
class _GamesTabContent extends StatelessWidget {
  final AsyncValue<List<GameWithGroup>> gamesAsync;
  final String filterStatus;
  final String emptyMessage;
  final void Function(String gameId) onGameTap;
  final Future<void> Function() onRefresh;
  final bool showGroupInfo;

  const _GamesTabContent({
    required this.gamesAsync,
    required this.filterStatus,
    required this.emptyMessage,
    required this.onGameTap,
    required this.onRefresh,
    this.showGroupInfo = true,
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
                showGroupInfo: showGroupInfo,
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
  final bool showGroupInfo;

  const _GameCard({
    super.key,
    required this.gameWithGroup,
    required this.onTap,
    this.showGroupInfo = true,
  });

  // Cache date formatters to avoid recreation
  static final DateFormat _dateFormatter = DateFormat('MMM d, yyyy');
  static final DateFormat _timeFormatter = DateFormat('h:mm a');

  static Widget _buildGroupAvatar(String? url, String fallback, BuildContext context) {
    // ...existing code...
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
        title: showGroupInfo
            ? Row(
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
              )
            : Text(
                game.name.isNotEmpty ? game.name : 'Game',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (showGroupInfo && game.name.isNotEmpty)
              Text(
                game.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            if (showGroupInfo && game.name.isNotEmpty) const SizedBox(height: 4),
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
      error: (error, stackTrace) => const SizedBox.shrink(),
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
