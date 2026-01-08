import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/avatar_utils.dart';
import 'active_games_screen.dart';
import 'games_group_selector_screen.dart';
import 'game_detail_screen.dart';
import '../providers/games_provider.dart';
import '../../../locations/presentation/providers/locations_provider.dart';

class GamesEntryScreen extends ConsumerStatefulWidget {
  const GamesEntryScreen({super.key});

  @override
  ConsumerState<GamesEntryScreen> createState() => _GamesEntryScreenState();
}

class _GamesEntryScreenState extends ConsumerState<GamesEntryScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _activeGamesKey = GlobalKey();
  final GlobalKey _scheduledGamesKey = GlobalKey();
  final GlobalKey _completedGamesKey = GlobalKey();
  final GlobalKey _cancelledGamesKey = GlobalKey();
  final GlobalKey _createGameKey = GlobalKey();


  @override
  void dispose() {
    _scrollController.dispose();
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

  void _scrollToSection(GlobalKey key) {
    // Wait for the next frame to ensure widgets are laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final context = key.currentContext;
        if (context != null) {
          // Use Scrollable.ensureVisible with proper delay
          // This ensures the widget is visible in the scroll area
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.05, // Position target near the top
          );
        }
      } catch (e) {
        // Removed debugPrint
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateFormatter = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormatter = DateFormat('h:mm a');

    final dateTimeCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dateFormatter.format(now),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 12),
              Text(
                timeFormatter.format(now),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
    
    final activeGamesAsync = ref.watch(activeGamesProvider);
    final pastGamesAsync = ref.watch(pastGamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGameOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('Create Game'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeGamesProvider);
          ref.invalidate(pastGamesProvider);
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            dateTimeCard,
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _NavigationChip(
                    label: 'Active',
                    icon: Icons.play_circle,
                    color: Colors.green,
                    onTap: () => _scrollToSection(_activeGamesKey),
                  ),
                  const SizedBox(width: 8),
                  _NavigationChip(
                    label: 'Scheduled',
                    icon: Icons.schedule,
                    color: Colors.orange,
                    onTap: () => _scrollToSection(_scheduledGamesKey),
                  ),
                  const SizedBox(width: 8),
                  _NavigationChip(
                    label: 'Completed',
                    icon: Icons.check_circle,
                    color: Colors.blue,
                    onTap: () => _scrollToSection(_completedGamesKey),
                  ),
                  const SizedBox(width: 8),
                  _NavigationChip(
                    label: 'Cancelled',
                    icon: Icons.cancel,
                    color: Colors.grey,
                    onTap: () => _scrollToSection(_cancelledGamesKey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            
            // Create New Group or Game
            SizedBox(
              key: _createGameKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Create New Game',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  _EntryCard(
                    icon: Icons.add_circle,
                    title: 'Create New Game',
                    subtitle: 'Start a new poker game in a group.',
                    onTap: () {
                      _showCreateGameOptions(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Active Games (in_progress)
            activeGamesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error loading games: $error'),
              ),
              data: (allGames) {
                final inProgressGames = allGames
                    .where((gwg) => gwg.game.status == 'in_progress')
                    .toList();
                
                // Show all scheduled games, sorted by most recent date
                final allScheduledGames = allGames
                    .where((gwg) => gwg.game.status == 'scheduled')
                    .toList()
                  ..sort((a, b) => b.game.gameDate.compareTo(a.game.gameDate));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Games Section
                    SizedBox(
                      key: _activeGamesKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (inProgressGames.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                'Active Games',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            ...inProgressGames.map((gwg) => _GameCard(
                                  gameWithGroup: gwg,
                                  onTap: () => _openGameDetail(context, gwg.game.id),
                                )),
                            const SizedBox(height: 24),
                          ] else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                    
                    // Start Games Section (scheduled)
                    SizedBox(
                      key: _scheduledGamesKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (allScheduledGames.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                'Scheduled Games',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            ...allScheduledGames.map((gwg) => _GameCard(
                                  gameWithGroup: gwg,
                                  onTap: () => _openGameDetail(context, gwg.game.id),
                                )),
                            const SizedBox(height: 24),
                          ] else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            
            // Select group for game
            _EntryCard(
              icon: Icons.group,
              title: 'Select group for game',
              subtitle: 'Pick a group to view its games or start a new one.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const GamesGroupSelectorScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            
            // Completed Games Section
            SizedBox(
              key: _completedGamesKey,
              child: pastGamesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Error loading past games: $error'),
                ),
                data: (allPastGames) {
                  final completedGames = allPastGames
                      .where((gwg) => gwg.game.status == 'completed')
                      .toList();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Completed Games',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      if (completedGames.isNotEmpty) ...
                        completedGames.take(10).map((gwg) => _GameCard(
                            gameWithGroup: gwg,
                            onTap: () => _openGameDetail(context, gwg.game.id),
                          )),
                      if (completedGames.length > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ActiveGamesScreen(),
                                  ),
                                );
                              },
                              child: Text('View All ${completedGames.length} Completed Games'),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
            
            // Cancelled Games Section
            SizedBox(
              key: _cancelledGamesKey,
              child: pastGamesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
                data: (allPastGames) {
                  final cancelledGames = allPastGames
                      .where((gwg) => gwg.game.status == 'cancelled')
                      .toList();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Cancelled Games',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      if (cancelledGames.isNotEmpty) ...
                        cancelledGames.take(10).map((gwg) => _GameCard(
                            gameWithGroup: gwg,
                            onTap: () => _openGameDetail(context, gwg.game.id),
                          )),
                      if (cancelledGames.length > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ActiveGamesScreen(),
                                  ),
                                );
                              },
                              child: Text('View All ${cancelledGames.length} Cancelled Games'),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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
            const Text(
              'Create a New Game',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

// Navigation Chip Widget
class _NavigationChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NavigationChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameWithGroup gameWithGroup;
  final VoidCallback onTap;

  const _GameCard({
    required this.gameWithGroup,
    required this.onTap,
  });

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
    final dateFormatter = DateFormat('MMM d, yyyy');
    final timeFormatter = DateFormat('h:mm a');
    
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
        iconColor = Theme.of(context).colorScheme.onPrimaryContainer;
        iconData = Icons.schedule;
        backgroundColor = Theme.of(context).colorScheme.primaryContainer;
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
                Text('${dateFormatter.format(game.gameDate)} at ${timeFormatter.format(game.gameDate)}'),
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

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
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
