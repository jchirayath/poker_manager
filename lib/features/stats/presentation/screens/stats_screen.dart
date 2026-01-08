import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../groups/data/models/group_model.dart';
import '../providers/stats_provider.dart';

enum StatsMode { recentGame, groupSummary }
enum TimeFilter { week, month, year, all }

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsMode _mode = StatsMode.recentGame;
  String? _selectedGroupId;
  TimeFilter _timeFilter = TimeFilter.week;
  String _gameQuery = '';

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authStateProvider).value?.id;
    final groupsAsync = ref.watch(groupsListProvider);
    final groups = groupsAsync.asData?.value ?? <GroupModel>[];
    final resolvedGroupId = _selectedGroupId ?? (groups.isNotEmpty ? groups.first.id : null);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupsListProvider);
          ref.invalidate(recentGameStatsProvider);
          if (resolvedGroupId != null) {
            ref.invalidate(groupStatsProvider(resolvedGroupId));
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildModeSelector(context),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: (_mode == StatsMode.recentGame)
                    ? _RecentGamesSection(
                        timeFilter: _timeFilter,
                        onTimeFilterChanged: (f) => setState(() => _timeFilter = f),
                        gameQuery: _gameQuery,
                        onQueryChanged: (value) => setState(() => _gameQuery = value),
                        currentUserId: currentUserId,
                      )
                    : _GroupStatsSection(
                        currentUserId: currentUserId,
                        selectedGroupId: resolvedGroupId,
                        onGroupChanged: (id) {
                          setState(() => _selectedGroupId = id);
                        },
                        groupsAsync: groupsAsync,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context) {
    return SegmentedButton<StatsMode>(
      segments: const [
        ButtonSegment(
          value: StatsMode.recentGame,
          icon: Icon(Icons.flash_on),
          label: Text('Recent game'),
        ),
        ButtonSegment(
          value: StatsMode.groupSummary,
          icon: Icon(Icons.groups),
          label: Text('Group summary'),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (selection) {
        setState(() => _mode = selection.first);
      },
    );
  }
}

class _RecentGamesSection extends ConsumerWidget {
    static Widget buildGroupAvatar(String? url, String fallback, BuildContext context) {
      final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : 'G';
      if (url == null || url.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(right: 0),
          child: CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
            child: Text(
              letter,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      }
      if (url.toLowerCase().contains('svg')) {
        return Padding(
          padding: const EdgeInsets.only(right: 0),
          child: SizedBox(
            width: 24,
            height: 24,
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
      return Padding(
        padding: const EdgeInsets.only(right: 0),
        child: CircleAvatar(
          radius: 12,
          backgroundImage: NetworkImage(url),
          backgroundColor: Colors.transparent,
        ),
      );
    }
  final TimeFilter timeFilter;
  final void Function(TimeFilter filter) onTimeFilterChanged;
  final String gameQuery;
  final void Function(String value) onQueryChanged;
   final String? currentUserId;

  const _RecentGamesSection({
    required this.timeFilter,
    required this.onTimeFilterChanged,
    required this.gameQuery,
    required this.onQueryChanged,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentGamesStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent game filters',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _TimeFilterChips(
                  timeFilter: timeFilter,
                  onChanged: onTimeFilterChanged,
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: onQueryChanged,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Filter by game name',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        recentAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => _ErrorState(message: 'Could not load recent games: $err'),
          data: (games) {
            final filtered = games
                .where((g) => _isWithinRange(g.game.gameDate, timeFilter))
                .where((g) => g.game.name.toLowerCase().contains(gameQuery.toLowerCase()))
                .take(20)
                .toList();

            if (filtered.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No games match your filters yet.')),
              );
            }

            final visible = filtered.take(4).toList();

            return Column(
              children: [
                ...visible.map((data) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.game.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                buildGroupAvatar(data.groupAvatarUrl, data.groupName, context),
                                const SizedBox(width: 8),
                                Text('${data.groupName} • ${_formatDate(data.game.gameDate)}'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _RankingTable(
                              currency: data.game.currency,
                              ranking: data.ranking,
                              showBreakdown: false,
                              currentUserId: currentUserId,
                            ),
                          ],
                        ),
                      ),
                    )),
                if (filtered.length > visible.length)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Showing ${visible.length} of ${filtered.length} recent games'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

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
      spacing: 6,
      runSpacing: 6,
      children: [
        ChoiceChip(
          label: const Text('Week'),
          selected: timeFilter == TimeFilter.week,
          onSelected: (_) => onChanged(TimeFilter.week),
        ),
        ChoiceChip(
          label: const Text('Month'),
          selected: timeFilter == TimeFilter.month,
          onSelected: (_) => onChanged(TimeFilter.month),
        ),
        ChoiceChip(
          label: const Text('Year'),
          selected: timeFilter == TimeFilter.year,
          onSelected: (_) => onChanged(TimeFilter.year),
        ),
        ChoiceChip(
          label: const Text('All'),
          selected: timeFilter == TimeFilter.all,
          onSelected: (_) => onChanged(TimeFilter.all),
        ),
      ],
    );
  }
}

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

class _GroupStatsSection extends ConsumerWidget {
  final String? currentUserId;
  final String? selectedGroupId;
  final void Function(String id) onGroupChanged;
  final AsyncValue<List<GroupModel>> groupsAsync;

  const _GroupStatsSection({
    required this.currentUserId,
    required this.selectedGroupId,
    required this.onGroupChanged,
    required this.groupsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Group summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                groupsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => _ErrorState(message: 'Could not load groups: $err'),
                  data: (groups) {
                    if (groups.isEmpty) {
                      return const Text('No groups found.');
                    }
                    return DropdownButton<String>(
                      value: selectedGroupId ?? groups.first.id,
                      isExpanded: true,
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
        const SizedBox(height: 12),
        if (selectedGroupId != null)
          Consumer(
            builder: (context, ref, _) {
              final groupStatsAsync = ref.watch(groupStatsProvider(selectedGroupId!));
              return groupStatsAsync.when(
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                )),
                error: (err, _) => _ErrorState(message: 'Could not load group stats: $err'),
                data: (data) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  _buildGroupAvatar(data.groupAvatarUrl, data.groupName, context),
                                  const SizedBox(width: 8),
                                  Text(
                                    data.groupName,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text('${data.gameCount} games'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (data.ranking.isEmpty)
                            const Text('No completed games yet.')
                          else
                            _RankingTable(
                              currency: data.currency,
                              ranking: data.ranking,
                              showBreakdown: true,
                              currentUserId: currentUserId,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  static Widget _buildGroupAvatar(String? url, String fallback, BuildContext context) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : 'G';
    if (url == null || url.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(right: 0),
        child: CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
          child: Text(
            letter,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    if (url.toLowerCase().contains('svg')) {
      return Padding(
        padding: const EdgeInsets.only(right: 0),
        child: SizedBox(
          width: 24,
          height: 24,
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

    return Padding(
      padding: const EdgeInsets.only(right: 0),
      child: CircleAvatar(
        radius: 12,
        backgroundImage: NetworkImage(url),
        backgroundColor: Colors.transparent,
      ),
    );
  }
}

class _RankingTable extends StatelessWidget {
  final String currency;
  final List<RankingRow> ranking;
  final bool showBreakdown;
  final String? currentUserId;

  const _RankingTable({
    required this.currency,
    required this.ranking,
    this.showBreakdown = false,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final highlightColor = Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.35);
    final highlightTextColor = Theme.of(context).colorScheme.onSecondaryContainer;
    final ranks = _calculateRanks(ranking);

    if (!showBreakdown) {
      return Table(
        columnWidths: const {
          0: FixedColumnWidth(40),
          1: FlexColumnWidth(),
          2: FixedColumnWidth(100),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _headerRow(),
          ...ranking.asMap().entries.map((entry) {
            final idx = entry.key;
            final row = entry.value;
            final rank = ranks[idx];
            final isCurrentUser = currentUserId != null && row.userId == currentUserId;
            final bg = isCurrentUser ? highlightColor : null;
            final fg = isCurrentUser ? highlightTextColor : null;
            final weight = isCurrentUser ? FontWeight.w700 : null;
            return TableRow(
              children: [
                _cell('#$rank', background: bg, color: fg, weight: weight),
                _cell(row.name, background: bg, color: fg, weight: weight),
                _cell(
                  _formatAmount(currency, row.net),
                  align: TextAlign.right,
                  color: _netColor(row.net),
                  background: bg,
                  weight: weight,
                ),
              ],
            );
          }),
        ],
      );
    }

    // Group breakdown by game for detailed view
    final gameMap = <String, List<(RankingRow player, GameBreakdown game)>>{};
    for (int i = 0; i < ranking.length; i++) {
      final row = ranking[i];
      for (final game in row.breakdown) {
        gameMap.putIfAbsent(game.gameId, () => []);
        gameMap[game.gameId]!.add((row, game));
      }
    }

    // Calculate group summary stats
    final totalGames = gameMap.length;
    final totalPlayers = ranking.length;

    return Column(
      children: [
        // Summary card with player records
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Games: $totalGames'),
                    Text('Players: $totalPlayers'),
                  ],
                ),
                const SizedBox(height: 12),
                // Player win-loss table
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(),
                    1: FixedColumnWidth(80),
                    2: FixedColumnWidth(80),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    const TableRow(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('Player', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('Wins', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('Losses', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...ranking.map((player) {
                      final isCurrentUser = currentUserId != null && player.userId == currentUserId;
                      final bg = isCurrentUser ? highlightColor : null;
                      final fg = isCurrentUser ? highlightTextColor : null;
                      final weight = isCurrentUser ? FontWeight.w700 : null;
                      return TableRow(
                        children: [
                          _cell(player.name, background: bg, color: fg, weight: weight),
                          _cell(
                            '${player.wins}',
                            align: TextAlign.center,
                            background: bg,
                            color: fg,
                            weight: weight,
                          ),
                          _cell(
                            '${player.losses}',
                            align: TextAlign.center,
                            background: bg,
                            color: fg,
                            weight: weight,
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Game-by-game breakdown
        ...gameMap.entries.map((entry) {
          final gameId = entry.key;
          final players = entry.value;
          final gameName = players.first.$2.gameName;
          final gameDate = players.first.$2.gameDate;

          // Sort players by net for this game
          players.sort((a, b) => b.$2.net.compareTo(a.$2.net));

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatDate(gameDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Table(
                    columnWidths: const {
                      0: FixedColumnWidth(30),
                      1: FlexColumnWidth(),
                      2: FixedColumnWidth(90),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      const TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Rank', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Player', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Result', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...players.asMap().entries.map((e) {
                        final playerIdx = e.key;
                        final (player, game) = e.value;
                        final isCurrentUser = currentUserId != null && player.userId == currentUserId;
                        final bg = isCurrentUser ? highlightColor : null;
                        final fg = isCurrentUser ? highlightTextColor : null;
                        final weight = isCurrentUser ? FontWeight.w700 : null;
                        return TableRow(
                          children: [
                            _cell('#${playerIdx + 1}', background: bg, color: fg, weight: weight),
                            _cell(player.name, background: bg, color: fg, weight: weight),
                            _cell(
                              _formatAmount(currency, game.net),
                              align: TextAlign.right,
                              background: bg,
                              color: _netColor(game.net),
                              weight: weight,
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Wins/Losses summary for this game
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(),
                      1: FixedColumnWidth(60),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      const TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Player', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Result', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...players.map((p) {
                        final (player, game) = p;
                        final isWinner = game.net > 0;
                        final isCurrentUser = currentUserId != null && player.userId == currentUserId;
                        final bg = isCurrentUser ? highlightColor : null;
                        final fg = isCurrentUser ? highlightTextColor : null;
                        final weight = isCurrentUser ? FontWeight.w700 : null;
                        final resultText = isWinner ? 'Win' : 'Loss';
                        final resultColor = isWinner ? Colors.green : Colors.red;
                        return TableRow(
                          children: [
                            _cell(player.name, background: bg, color: fg, weight: weight),
                            _cell(
                              resultText,
                              align: TextAlign.center,
                              background: bg,
                              color: fg ?? resultColor,
                              weight: weight,
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  TableRow _headerRow() {
    return const TableRow(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Player', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Net', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _cell(
    String text, {
    TextAlign align = TextAlign.left,
    Color? color,
    Color? background,
    FontWeight? weight,
  }) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(color: color, fontWeight: weight),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    );
  }
}

String _formatAmount(String currency, double value) {
  final sign = value >= 0 ? '' : '-';
  final abs = value.abs().toStringAsFixed(2);
  return '$sign$currency $abs';
}

Color _netColor(double value) => value >= 0 ? Colors.green : Colors.red;

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
