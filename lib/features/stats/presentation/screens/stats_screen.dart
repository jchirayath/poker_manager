import '../../../common/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../groups/data/models/group_model.dart';
import '../providers/stats_provider.dart';

enum TimeFilter { week, month, year, all }

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedGroupId;
  String? _selectedPublicGroupId;
  TimeFilter _timeFilter = TimeFilter.week;
  TimeFilter _publicTimeFilter = TimeFilter.all;
  String _gameQuery = '';
  String _publicGameQuery = '';

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

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authStateProvider).value?.id;
    final groupsAsync = ref.watch(groupsListProvider);
    final publicGroupsAsync = ref.watch(publicGroupsProvider);
    final groups = groupsAsync.asData?.value ?? <GroupModel>[];
    final publicGroups = publicGroupsAsync.asData?.value ?? <GroupModel>[];
    final resolvedGroupId = _selectedGroupId ?? (groups.isNotEmpty ? groups.first.id : null);
    final resolvedPublicGroupId = _selectedPublicGroupId ?? (publicGroups.isNotEmpty ? publicGroups.first.id : null);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Stats'),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(
              icon: Icon(Icons.casino),
              child: Text('My\nGames', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
            ),
            Tab(
              icon: Icon(Icons.groups),
              child: Text('Groups', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
            ),
            Tab(
              icon: Icon(Icons.public),
              child: Text('Public\nGames', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
            ),
            Tab(
              icon: Icon(Icons.language),
              child: Text('Public\nGroups', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Games Tab
          _MyGamesTab(
            timeFilter: _timeFilter,
            onTimeFilterChanged: (f) => setState(() => _timeFilter = f),
            gameQuery: _gameQuery,
            onQueryChanged: (value) => setState(() => _gameQuery = value),
            currentUserId: currentUserId,
            onRefresh: () async {
              ref.invalidate(recentGameStatsProvider);
            },
          ),
          // Groups Tab
          _GroupsTab(
            currentUserId: currentUserId,
            selectedGroupId: resolvedGroupId,
            onGroupChanged: (id) => setState(() => _selectedGroupId = id),
            groupsAsync: groupsAsync,
            onRefresh: () async {
              ref.invalidate(groupsListProvider);
              if (resolvedGroupId != null) {
                ref.invalidate(groupStatsProvider(resolvedGroupId));
              }
            },
          ),
          // Public Games Tab
          _PublicGamesTab(
            currentUserId: currentUserId,
            timeFilter: _publicTimeFilter,
            onTimeFilterChanged: (f) => setState(() => _publicTimeFilter = f),
            gameQuery: _publicGameQuery,
            onQueryChanged: (value) => setState(() => _publicGameQuery = value),
            onRefresh: () async {
              ref.invalidate(publicGamesStatsProvider);
            },
          ),
          // Public Groups Tab
          _PublicGroupsTab(
            currentUserId: currentUserId,
            selectedGroupId: resolvedPublicGroupId,
            onGroupChanged: (id) => setState(() => _selectedPublicGroupId = id),
            groupsAsync: publicGroupsAsync,
            onRefresh: () async {
              ref.invalidate(publicGroupsProvider);
              if (resolvedPublicGroupId != null) {
                ref.invalidate(publicGroupStatsProvider(resolvedPublicGroupId));
              }
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// My Games Tab
// =============================================================================

class _MyGamesTab extends ConsumerWidget {
  final TimeFilter timeFilter;
  final void Function(TimeFilter filter) onTimeFilterChanged;
  final String gameQuery;
  final void Function(String value) onQueryChanged;
  final String? currentUserId;
  final Future<void> Function() onRefresh;

  const _MyGamesTab({
    required this.timeFilter,
    required this.onTimeFilterChanged,
    required this.gameQuery,
    required this.onQueryChanged,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentGamesStatsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Filters Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_list, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Filters',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TimeFilterChips(
                    timeFilter: timeFilter,
                    onChanged: onTimeFilterChanged,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: onQueryChanged,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search games...',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Games List
          recentAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => _ErrorState(message: 'Could not load games: $err'),
            data: (games) {
              final filtered = games
                  .where((g) => _isWithinRange(g.game.gameDate, timeFilter))
                  .where((g) => g.game.name.toLowerCase().contains(gameQuery.toLowerCase()))
                  .take(20)
                  .toList();

              if (filtered.isEmpty) {
                return _buildEmptyState(
                  context,
                  icon: Icons.casino_outlined,
                  message: 'No games match your filters',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${filtered.length} game${filtered.length == 1 ? '' : 's'} found',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...filtered.map((data) => _buildGameCard(context, data, currentUserId)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, dynamic data, String? currentUserId) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.game.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(context, data.game.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildGroupAvatar(data.groupAvatarUrl, data.groupName, context),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${data.groupName} • ${_formatDate(data.game.gameDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _RecentGameRankingTable(
              ranking: data.ranking,
              currentUserId: currentUserId,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'in_progress':
        bgColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green[700]!;
        label = 'Active';
        break;
      case 'scheduled':
        bgColor = Colors.orange.withValues(alpha: 0.2);
        textColor = Colors.orange[700]!;
        label = 'Scheduled';
        break;
      case 'completed':
        bgColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue[700]!;
        label = 'Completed';
        break;
      case 'cancelled':
        bgColor = Colors.grey.withValues(alpha: 0.2);
        textColor = Colors.grey[700]!;
        label = 'Cancelled';
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.2);
        textColor = Colors.grey[700]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required IconData icon, required String message}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  static Widget _buildGroupAvatar(String? url, String fallback, BuildContext context) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : 'G';
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          letter,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
    if (url.toLowerCase().contains('svg')) {
      return SizedBox(
        width: 24,
        height: 24,
        child: ClipOval(
          child: SvgPicture.network(
            fixDiceBearUrl(url)!,
            placeholderBuilder: (_) => const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1),
            ),
            errorBuilder: (context, error, stackTrace) {
              debugPrint('SVG load error for URL: ${fixDiceBearUrl(url)}');
              debugPrint('Error: $error');
              return Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                child: Text('?', style: TextStyle(fontSize: 16)),
              );
            },
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 12,
      backgroundImage: NetworkImage(url),
      backgroundColor: Colors.transparent,
    );
  }
}

// =============================================================================
// Groups Tab
// =============================================================================

class _GroupsTab extends ConsumerWidget {
  final String? currentUserId;
  final String? selectedGroupId;
  final void Function(String id) onGroupChanged;
  final AsyncValue<List<GroupModel>> groupsAsync;
  final Future<void> Function() onRefresh;

  const _GroupsTab({
    required this.currentUserId,
    required this.selectedGroupId,
    required this.onGroupChanged,
    required this.groupsAsync,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Group Selector Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.groups, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select Group',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  groupsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Error: $err'),
                    data: (groups) {
                      if (groups.isEmpty) {
                        return const Text('No groups found.');
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: selectedGroupId ?? groups.first.id,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (value) {
                          if (value != null) onGroupChanged(value);
                        },
                        items: [
                          for (final group in groups)
                            DropdownMenuItem(
                              value: group.id,
                              child: Row(
                                children: [
                                  _buildGroupAvatar(group.avatarUrl, group.name, context),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(group.name)),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Group Stats
          if (selectedGroupId != null)
            Consumer(
              builder: (context, ref, _) {
                final groupStatsAsync = ref.watch(groupStatsProvider(selectedGroupId!));
                return groupStatsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => _ErrorState(message: 'Could not load group stats: $err'),
                  data: (data) => _buildGroupStatsCard(context, data, currentUserId),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGroupStatsCard(BuildContext context, GroupStatsSummary data, String? currentUserId) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Build game breakdown map
    final gameMap = <String, List<(RankingRow player, GameBreakdown game)>>{};
    for (final player in data.ranking) {
      for (final game in player.breakdown) {
        gameMap.putIfAbsent(game.gameId, () => []);
        gameMap[game.gameId]!.add((player, game));
      }
    }

    // Sort games by date (most recent first)
    final sortedGameIds = gameMap.keys.toList()
      ..sort((a, b) {
        final aDate = gameMap[a]!.first.$2.gameDate;
        final bDate = gameMap[b]!.first.$2.gameDate;
        return bDate.compareTo(aDate);
      });

    return Column(
      children: [
        // Summary Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    _buildGroupAvatar(data.groupAvatarUrl, data.groupName, context),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.groupName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${data.gameCount} game${data.gameCount == 1 ? '' : 's'} • ${data.ranking.length} player${data.ranking.length == 1 ? '' : 's'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Overall Leaderboard
                Row(
                  children: [
                    Icon(Icons.leaderboard, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Overall Leaderboard',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (data.ranking.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(Icons.leaderboard_outlined, size: 48, color: colorScheme.outline),
                          const SizedBox(height: 8),
                          Text(
                            'No completed games yet',
                            style: TextStyle(color: colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _RankingTable(
                    currency: data.currency,
                    ranking: data.ranking,
                    currentUserId: currentUserId,
                  ),
              ],
            ),
          ),
        ),

        // Game-by-Game Breakdown
        if (sortedGameIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.history, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Game History',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...sortedGameIds.map((gameId) {
            final players = gameMap[gameId]!;
            final gameName = players.first.$2.gameName;
            final gameDate = players.first.$2.gameDate;

            // Sort players by net for this game
            players.sort((a, b) => b.$2.net.compareTo(a.$2.net));

            return _buildGameBreakdownCard(
              context: context,
              gameName: gameName,
              gameDate: gameDate,
              players: players,
              currentUserId: currentUserId,
            );
          }),
        ],
      ],
    );
  }

  Widget _buildGameBreakdownCard({
    required BuildContext context,
    required String gameName,
    required DateTime gameDate,
    required List<(RankingRow player, GameBreakdown game)> players,
    String? currentUserId,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final highlightColor = colorScheme.primaryContainer.withValues(alpha: 0.3);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gameName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(gameDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${players.length} players',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FixedColumnWidth(36),
                1: FlexColumnWidth(),
                2: FixedColumnWidth(60),
                3: FixedColumnWidth(80),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _headerCell('#'),
                    _headerCell('Player'),
                    _headerCell('W/L', align: TextAlign.center),
                    _headerCell('Net', align: TextAlign.right),
                  ],
                ),
                ...players.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final (player, game) = entry.value;
                  final isWinner = game.net > 0;
                  final isCurrentUser = currentUserId != null && player.userId == currentUserId;
                  final bg = isCurrentUser ? highlightColor : null;
                  final weight = isCurrentUser ? FontWeight.w700 : FontWeight.normal;
                  final resultText = isWinner ? 'Win' : 'Loss';
                  final resultColor = isWinner ? Colors.green : Colors.red;

                  return TableRow(
                    decoration: bg != null ? BoxDecoration(color: bg) : null,
                    children: [
                      _cell('${idx + 1}', weight: weight),
                      _cell(player.name, weight: weight),
                      _cell(resultText, align: TextAlign.center, color: resultColor, weight: weight),
                      _cell(_formatAmountNoCurrency(game.net), align: TextAlign.right, color: _netColor(game.net), weight: weight),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _cell(String text, {TextAlign align = TextAlign.left, Color? color, FontWeight? weight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 13, color: color, fontWeight: weight),
      ),
    );
  }

  static Widget _buildGroupAvatar(String? url, String fallback, BuildContext context) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : 'G';
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          letter,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    if (url.toLowerCase().contains('svg')) {
      return SizedBox(
        width: 32,
        height: 32,
        child: ClipOval(
          child: SvgPicture.network(
            fixDiceBearUrl(url)!,
            placeholderBuilder: (_) => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundImage: NetworkImage(url),
      backgroundColor: Colors.transparent,
    );
  }
}

// =============================================================================
// Public Games Tab (Paginated)
// =============================================================================

class _PublicGamesTab extends ConsumerStatefulWidget {
  final String? currentUserId;
  final TimeFilter timeFilter;
  final void Function(TimeFilter filter) onTimeFilterChanged;
  final String gameQuery;
  final void Function(String value) onQueryChanged;
  final Future<void> Function() onRefresh;

  const _PublicGamesTab({
    this.currentUserId,
    required this.timeFilter,
    required this.onTimeFilterChanged,
    required this.gameQuery,
    required this.onQueryChanged,
    required this.onRefresh,
  });

  @override
  ConsumerState<_PublicGamesTab> createState() => _PublicGamesTabState();
}

class _PublicGamesTabState extends ConsumerState<_PublicGamesTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedPublicGamesProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedPublicGamesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paginatedPublicGamesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter games based on time and query
    final filtered = state.games
        .where((g) => _isWithinRange(g.game.gameDate, widget.timeFilter))
        .where((g) => g.game.name.toLowerCase().contains(widget.gameQuery.toLowerCase()))
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(paginatedPublicGamesProvider.notifier).refresh();
        await widget.onRefresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Filters Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.filter_list, size: 20, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Filters',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TimeFilterChips(
                        timeFilter: widget.timeFilter,
                        onChanged: widget.onTimeFilterChanged,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: widget.onQueryChanged,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search public games...',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Error state
          if (state.error != null)
            SliverToBoxAdapter(
              child: _ErrorState(message: 'Could not load public games: ${state.error}'),
            ),

          // Loading initial
          if (state.isLoading && state.games.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // Empty state
          if (!state.isLoading && filtered.isEmpty && state.error == null)
            SliverToBoxAdapter(
              child: _buildEmptyState(
                context,
                icon: Icons.public_off,
                message: 'No public games found',
              ),
            ),

          // Games count
          if (filtered.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${filtered.length} public game${filtered.length == 1 ? '' : 's'} found',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

          // Games list
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < filtered.length) {
                    return _buildPublicGameCard(context, filtered[index]);
                  }
                  return null;
                },
                childCount: filtered.length,
              ),
            ),
          ),

          // Loading more indicator
          if (state.isLoading && state.games.isNotEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // End of list indicator
          if (!state.hasMore && state.games.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No more games to load',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPublicGameCard(BuildContext context, RecentGameStats data) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.game.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(context, data.game.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildGroupAvatarSmall(data.groupAvatarUrl, data.groupName, context),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${data.groupName} • ${_formatDate(data.game.gameDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _RecentGameRankingTable(
              ranking: data.ranking,
              currentUserId: widget.currentUserId,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'in_progress':
        bgColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green[700]!;
        label = 'Active';
        break;
      case 'scheduled':
        bgColor = Colors.orange.withValues(alpha: 0.2);
        textColor = Colors.orange[700]!;
        label = 'Scheduled';
        break;
      case 'completed':
        bgColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue[700]!;
        label = 'Completed';
        break;
      case 'cancelled':
        bgColor = Colors.grey.withValues(alpha: 0.2);
        textColor = Colors.grey[700]!;
        label = 'Cancelled';
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.2);
        textColor = Colors.grey[700]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required IconData icon, required String message}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  static Widget _buildGroupAvatarSmall(String? url, String fallback, BuildContext context) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : 'G';
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          letter,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
    if (url.toLowerCase().contains('svg')) {
      return SizedBox(
        width: 24,
        height: 24,
        child: ClipOval(
          child: SvgPicture.network(
            fixDiceBearUrl(url)!,
            placeholderBuilder: (_) => const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1),
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 12,
      backgroundImage: NetworkImage(url),
      backgroundColor: Colors.transparent,
    );
  }
}

// =============================================================================
// Public Groups Tab (Paginated)
// =============================================================================

class _PublicGroupsTab extends ConsumerStatefulWidget {
  final String? currentUserId;
  final String? selectedGroupId;
  final void Function(String id) onGroupChanged;
  final AsyncValue<List<GroupModel>> groupsAsync;
  final Future<void> Function() onRefresh;

  const _PublicGroupsTab({
    this.currentUserId,
    required this.selectedGroupId,
    required this.onGroupChanged,
    required this.groupsAsync,
    required this.onRefresh,
  });

  @override
  ConsumerState<_PublicGroupsTab> createState() => _PublicGroupsTabState();
}

class _PublicGroupsTabState extends ConsumerState<_PublicGroupsTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedPublicGroupsProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedPublicGroupsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paginatedPublicGroupsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(paginatedPublicGroupsProvider.notifier).refresh();
        await widget.onRefresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Group Selector Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.public, size: 20, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Select Public Group',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (state.isLoading && state.groups.isEmpty)
                        const LinearProgressIndicator()
                      else if (state.error != null)
                        Text('Error: ${state.error}')
                      else if (state.groups.isEmpty)
                        const Text('No public groups found.')
                      else
                        DropdownButtonFormField<String>(
                          initialValue: widget.selectedGroupId ?? state.groups.first.id,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (value) {
                            if (value != null) widget.onGroupChanged(value);
                          },
                          items: [
                            for (final group in state.groups)
                              DropdownMenuItem(
                                value: group.id,
                                child: Row(
                                  children: [
                                    _buildGroupAvatar(group.avatarUrl, group.name, context),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(group.name)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Group Stats
          if (widget.selectedGroupId != null || (state.groups.isNotEmpty && widget.selectedGroupId == null))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Consumer(
                  builder: (context, ref, _) {
                    final groupId = widget.selectedGroupId ?? (state.groups.isNotEmpty ? state.groups.first.id : null);
                    if (groupId == null) {
                      return _buildEmptyState(
                        context,
                        icon: Icons.public_off,
                        message: 'No public groups available',
                      );
                    }
                    final groupStatsAsync = ref.watch(publicGroupStatsProvider(groupId));
                    return groupStatsAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => _ErrorState(message: 'Could not load group stats: $err'),
                      data: (data) => _buildPublicGroupStatsCard(context, data),
                    );
                  },
                ),
              ),
            )
          else if (state.groups.isEmpty && !state.isLoading)
            SliverToBoxAdapter(
              child: _buildEmptyState(
                context,
                icon: Icons.public_off,
                message: 'No public groups available',
              ),
            ),

          // Loading more indicator
          if (state.isLoading && state.groups.isNotEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicGroupStatsCard(BuildContext context, GroupStatsSummary data) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Build game breakdown map
    final gameMap = <String, List<(RankingRow player, GameBreakdown game)>>{};
    for (final player in data.ranking) {
      for (final game in player.breakdown) {
        gameMap.putIfAbsent(game.gameId, () => []);
        gameMap[game.gameId]!.add((player, game));
      }
    }

    // Sort games by date (most recent first)
    final sortedGameIds = gameMap.keys.toList()
      ..sort((a, b) {
        final aDate = gameMap[a]!.first.$2.gameDate;
        final bDate = gameMap[b]!.first.$2.gameDate;
        return bDate.compareTo(aDate);
      });

    return Column(
      children: [
        // Summary Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    _buildGroupAvatarLarge(data.groupAvatarUrl, data.groupName, context),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.groupName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${data.gameCount} game${data.gameCount == 1 ? '' : 's'} • ${data.ranking.length} player${data.ranking.length == 1 ? '' : 's'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Overall Leaderboard
                Row(
                  children: [
                    Icon(Icons.leaderboard, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Overall Leaderboard',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (data.ranking.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(Icons.leaderboard_outlined, size: 48, color: colorScheme.outline),
                          const SizedBox(height: 8),
                          Text(
                            'No completed games yet',
                            style: TextStyle(color: colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _RankingTable(
                    currency: data.currency,
                    ranking: data.ranking,
                    currentUserId: widget.currentUserId,
                  ),
              ],
            ),
          ),
        ),

        // Game-by-Game Breakdown
        if (sortedGameIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.history, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Game History',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...sortedGameIds.map((gameId) {
            final players = gameMap[gameId]!;
            final gameName = players.first.$2.gameName;
            final gameDate = players.first.$2.gameDate;

            // Sort players by net for this game
            players.sort((a, b) => b.$2.net.compareTo(a.$2.net));

            return _buildGameBreakdownCard(
              context: context,
              gameName: gameName,
              gameDate: gameDate,
              players: players,
            );
          }),
        ],
      ],
    );
  }

  Widget _buildGameBreakdownCard({
    required BuildContext context,
    required String gameName,
    required DateTime gameDate,
    required List<(RankingRow player, GameBreakdown game)> players,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final highlightColor = colorScheme.primaryContainer.withValues(alpha: 0.3);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gameName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(gameDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${players.length} players',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FixedColumnWidth(36),
                1: FlexColumnWidth(),
                2: FixedColumnWidth(60),
                3: FixedColumnWidth(80),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _headerCell('#'),
                    _headerCell('Player'),
                    _headerCell('W/L', align: TextAlign.center),
                    _headerCell('Net', align: TextAlign.right),
                  ],
                ),
                ...players.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final (player, game) = entry.value;
                  final isWinner = game.net > 0;
                  final isCurrentUser = widget.currentUserId != null && player.userId == widget.currentUserId;
                  final bg = isCurrentUser ? highlightColor : null;
                  final weight = isCurrentUser ? FontWeight.w700 : FontWeight.normal;
                  final resultText = isWinner ? 'Win' : 'Loss';
                  final resultColor = isWinner ? Colors.green : Colors.red;

                  return TableRow(
                    decoration: bg != null ? BoxDecoration(color: bg) : null,
                    children: [
                      _cell('${idx + 1}', weight: weight),
                      _cell(player.name, weight: weight),
                      _cell(resultText, align: TextAlign.center, color: resultColor, weight: weight),
                      _cell(_formatAmountNoCurrency(game.net), align: TextAlign.right, color: _netColor(game.net), weight: weight),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _cell(String text, {TextAlign align = TextAlign.left, Color? color, FontWeight? weight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 13, color: color, fontWeight: weight),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required IconData icon, required String message}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  static Widget _buildGroupAvatar(String? url, String fallback, BuildContext context) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : 'G';
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          letter,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
    if (url.toLowerCase().contains('svg')) {
      return SizedBox(
        width: 24,
        height: 24,
        child: ClipOval(
          child: SvgPicture.network(
            fixDiceBearUrl(url)!,
            placeholderBuilder: (_) => const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1),
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 12,
      backgroundImage: NetworkImage(url),
      backgroundColor: Colors.transparent,
    );
  }

  static Widget _buildGroupAvatarLarge(String? url, String fallback, BuildContext context) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : 'G';
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          letter,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    if (url.toLowerCase().contains('svg')) {
      return SizedBox(
        width: 32,
        height: 32,
        child: ClipOval(
          child: SvgPicture.network(
            fixDiceBearUrl(url)!,
            placeholderBuilder: (_) => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundImage: NetworkImage(url),
      backgroundColor: Colors.transparent,
    );
  }
}

// =============================================================================
// Shared Widgets
// =============================================================================

class _TimeFilterChips extends StatelessWidget {
  final TimeFilter timeFilter;
  final void Function(TimeFilter filter) onChanged;

  const _TimeFilterChips({
    required this.timeFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildChip(context, 'Week', TimeFilter.week),
        _buildChip(context, 'Month', TimeFilter.month),
        _buildChip(context, 'Year', TimeFilter.year),
        _buildChip(context, 'All', TimeFilter.all),
      ],
    );
  }

  Widget _buildChip(BuildContext context, String label, TimeFilter filter) {
    final isSelected = timeFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onChanged(filter),
    );
  }
}

class _RecentGameRankingTable extends StatelessWidget {
  final List<RankingRow> ranking;
  final String? currentUserId;

  const _RecentGameRankingTable({
    required this.ranking,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final highlightColor = colorScheme.primaryContainer.withValues(alpha: 0.3);

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(36),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(60),
        3: FixedColumnWidth(80),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _headerCell('#'),
            _headerCell('Player'),
            _headerCell('W/L', align: TextAlign.center),
            _headerCell('Net', align: TextAlign.right),
          ],
        ),
        ...ranking.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          final isWinner = row.net > 0;
          final isCurrentUser = currentUserId != null && row.userId == currentUserId;
          final bg = isCurrentUser ? highlightColor : null;
          final weight = isCurrentUser ? FontWeight.w700 : FontWeight.normal;
          final resultText = isWinner ? 'Win' : 'Loss';
          final resultColor = isWinner ? Colors.green : Colors.red;

          return TableRow(
            decoration: bg != null ? BoxDecoration(color: bg) : null,
            children: [
              _cell('${idx + 1}', weight: weight),
              _cell(row.name, weight: weight),
              _cell(resultText, align: TextAlign.center, color: resultColor, weight: weight),
              _cell(_formatAmountNoCurrency(row.net), align: TextAlign.right, color: _netColor(row.net), weight: weight),
            ],
          );
        }),
      ],
    );
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _cell(String text, {TextAlign align = TextAlign.left, Color? color, FontWeight? weight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 13, color: color, fontWeight: weight),
      ),
    );
  }
}

class _RankingTable extends StatelessWidget {
  final String currency;
  final List<RankingRow> ranking;
  final String? currentUserId;

  const _RankingTable({
    required this.currency,
    required this.ranking,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlightColor = colorScheme.primaryContainer.withValues(alpha: 0.3);
    final ranks = _calculateRanks(ranking);

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(36),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(40),
        3: FixedColumnWidth(40),
        4: FixedColumnWidth(80),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _headerCell('#'),
            _headerCell('Player'),
            _headerCell('W', align: TextAlign.center),
            _headerCell('L', align: TextAlign.center),
            _headerCell('Net', align: TextAlign.right),
          ],
        ),
        ...ranking.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          final rank = ranks[idx];
          final isCurrentUser = currentUserId != null && row.userId == currentUserId;
          final bg = isCurrentUser ? highlightColor : null;
          final weight = isCurrentUser ? FontWeight.w700 : FontWeight.normal;

          return TableRow(
            decoration: bg != null ? BoxDecoration(color: bg) : null,
            children: [
              _cell('$rank', weight: weight),
              _cell(row.name, weight: weight),
              _cell('${row.wins}', align: TextAlign.center, weight: weight),
              _cell('${row.losses}', align: TextAlign.center, weight: weight),
              _cell(_formatAmountNoCurrency(row.net), align: TextAlign.right, color: _netColor(row.net), weight: weight),
            ],
          );
        }),
      ],
    );
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _cell(String text, {TextAlign align = TextAlign.left, Color? color, FontWeight? weight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 13, color: color, fontWeight: weight),
      ),
    );
  }

  List<int> _calculateRanks(List<RankingRow> rows) {
    if (rows.isEmpty) return [];
    final ranks = List<int>.filled(rows.length, 1);
    int lastRank = 1;
    for (var i = 0; i < rows.length; i++) {
      if (i == 0) {
        ranks[i] = 1;
        continue;
      }
      final sameAsPrev = rows[i].net == rows[i - 1].net;
      if (sameAsPrev) {
        ranks[i] = lastRank;
      } else {
        lastRank = i + 1;
        ranks[i] = lastRank;
      }
    }
    return ranks;
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.error),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Utility Functions
// =============================================================================

bool _isWithinRange(DateTime date, TimeFilter filter) {
  final now = DateTime.now();
  final cutoff = () {
    switch (filter) {
      case TimeFilter.week:
        return now.subtract(const Duration(days: 7));
      case TimeFilter.month:
        return now.subtract(const Duration(days: 30));
      case TimeFilter.year:
        return now.subtract(const Duration(days: 365));
      case TimeFilter.all:
        return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }();

  return !date.isBefore(cutoff);
}

String _formatAmountNoCurrency(double value) {
  final sign = value >= 0 ? '+' : '-';
  final abs = value.abs().toStringAsFixed(2);
  return '$sign\$$abs';
}

Color _netColor(double value) => value >= 0 ? Colors.green : Colors.red;

String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}
