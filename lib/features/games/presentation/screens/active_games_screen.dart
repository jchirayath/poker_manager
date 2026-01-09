import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../providers/games_provider.dart';
import 'game_detail_screen.dart';
import 'games_group_selector_screen.dart';

enum TimeFilter { day, week, month, year, all }

class ActiveGamesScreen extends ConsumerStatefulWidget {
  const ActiveGamesScreen({super.key});

  @override
  ConsumerState<ActiveGamesScreen> createState() => _ActiveGamesScreenState();
}

class _ActiveGamesScreenState extends ConsumerState<ActiveGamesScreen> {
  static const String _allGroupsValue = 'all_groups';

  String _selectedGroupId = _allGroupsValue;
  TimeFilter _timeFilter = TimeFilter.week;

  // Cache date formatter to avoid recreation
  static final DateFormat _dateFormatter = DateFormat('MMM d, yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final activeGamesAsync = ref.watch(activeGamesProvider);
    final pastGamesAsync = ref.watch(pastGamesProvider);
    final groupsAsync = ref.watch(groupsListProvider);
    

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeGamesProvider);
          ref.invalidate(pastGamesProvider);
          ref.invalidate(groupsListProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active Games Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Active Games',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              activeGamesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Error: $error'),
                  );
                },
                data: (games) {
                  if (games.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          const Text('No active games right now'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const GamesGroupSelectorScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.group),
                            label: const Text('Browse Groups'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      return _buildGameCard(context, games[index]);
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              // Past Games Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Games',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _FilterRow(
                      groupsAsync: groupsAsync,
                      selectedGroupId: _selectedGroupId,
                      onGroupChanged: (value) {
                        setState(() => _selectedGroupId = value);
                      },
                      timeFilter: _timeFilter,
                      onTimeFilterChanged: (filter) {
                        setState(() => _timeFilter = filter);
                      },
                    ),
                  ],
                ),
              ),
              pastGamesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Error: $error'),
                  );
                },
                data: (games) {
                  // Single pass filtering for better performance
                  final filtered = <GameWithGroup>[];

                  for (final entry in games) {
                    if (entry.game.status == 'completed' &&
                        (_selectedGroupId == _allGroupsValue || entry.groupId == _selectedGroupId) &&
                        _isWithinRange(entry.game.gameDate)) {
                      filtered.add(entry);
                    }
                  }

                  filtered.sort((a, b) => b.game.gameDate.compareTo(a.game.gameDate));

                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('No games match your filters yet'),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildGameCard(context, filtered[index]);
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  bool _isWithinRange(DateTime date) {
    final now = DateTime.now();
    final cutoff = () {
      switch (_timeFilter) {
        case TimeFilter.day:
          return now.subtract(const Duration(days: 1));
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

  Widget _buildGameCard(BuildContext context, GameWithGroup entry) {
    final game = entry.game;
    final date = _dateFormatter.format(game.gameDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.group,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.groupName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (game.name.isNotEmpty)
              Text(
                game.name,
                style: Theme.of(context).textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (game.location != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      game.location!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Buy-in: ${game.currency} ${game.buyinAmount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            game.status,
            style: const TextStyle(fontSize: 11),
          ),
          backgroundColor: _statusColor(game.status),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue.withOpacity(0.15);
      case 'in_progress':
        return Colors.orange.withOpacity(0.15);
      case 'completed':
        return Colors.green.withOpacity(0.15);
      case 'cancelled':
        return Colors.red.withOpacity(0.15);
      default:
        return Colors.grey.withOpacity(0.15);
    }
  }
}

class _FilterRow extends StatelessWidget {
  final AsyncValue<List<GroupModel>> groupsAsync;
  final String selectedGroupId;
  final void Function(String value) onGroupChanged;
  final TimeFilter timeFilter;
  final void Function(TimeFilter filter) onTimeFilterChanged;

  const _FilterRow({
    required this.groupsAsync,
    required this.selectedGroupId,
    required this.onGroupChanged,
    required this.timeFilter,
    required this.onTimeFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by group and time',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _GroupFilter(
              groupsAsync: groupsAsync,
              selectedGroupId: selectedGroupId,
              onGroupChanged: onGroupChanged,
            ),
            _TimeFilterChips(
              timeFilter: timeFilter,
              onChanged: onTimeFilterChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupFilter extends StatelessWidget {
  final AsyncValue<List<GroupModel>> groupsAsync;
  final String selectedGroupId;
  final void Function(String value) onGroupChanged;

  const _GroupFilter({
    required this.groupsAsync,
    required this.selectedGroupId,
    required this.onGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      child: groupsAsync.when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (err, _) => Text('Groups unavailable: $err'),
        data: (groups) {
          final items = [
            const DropdownMenuItem<String>(
              value: _ActiveGamesScreenState._allGroupsValue,
              child: Text('All groups'),
            ),
            ...groups.map<DropdownMenuItem<String>>((group) {
              return DropdownMenuItem<String>(
                value: group.id,
                child: Row(
                  children: [
                    _buildGroupAvatar(group.avatarUrl, group.name, context),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(group.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            }),
          ];

          return DropdownButton<String>(
            value: selectedGroupId,
            isExpanded: true,
            onChanged: (value) {
              if (value != null) onGroupChanged(value);
            },
            items: items,
          );
        },
      ),
    );
  }

  static Widget _buildGroupAvatar(String? url, String fallback, BuildContext context) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : 'G';
    if ((url ?? '').isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Icon(
          Icons.group,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (url!.toLowerCase().contains('svg')) {
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
      children: [
        ChoiceChip(
          label: const Text('Day'),
          selected: timeFilter == TimeFilter.day,
          onSelected: (_) => onChanged(TimeFilter.day),
        ),
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
