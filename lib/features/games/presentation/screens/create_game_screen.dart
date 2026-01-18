import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../core/constants/currencies.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../providers/games_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../locations/presentation/providers/locations_provider.dart';
import '../../../locations/data/models/location_model.dart';
import '../../domain/services/seating_chart_service.dart';
import '../../data/models/game_participant_model.dart';

class CreateGameScreen extends ConsumerStatefulWidget {
  final String groupId;

  const CreateGameScreen({required this.groupId, super.key});

  @override
  ConsumerState<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends ConsumerState<CreateGameScreen> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _nameController;
  late final TextEditingController _buyinController;
  late final TextEditingController _additionalBuyinController;
  late final TextEditingController _occurrencesController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedCurrency = 'USD';
  List<double> _additionalBuyins = [];
  String? _selectedLocationId;
  final Set<String> _selectedPlayerIds = {};

  // Recurring games settings
  bool _isRecurring = false;
  String _recurringFrequency = 'weekly'; // weekly, biweekly, monthly, bimonthly, yearly
  int _occurrences = 4;

  // Seating chart option
  bool _generateSeatingChart = false;

  // Allow member transactions option
  bool _allowMemberTransactions = false;

  // Cache date formatter to avoid recreation
  static final DateFormat _dateFormatter = DateFormat('MMM d, yyyy');

  Widget _buildMemberAvatar(String? url, String initials) {
    if ((url ?? '').isEmpty) {
      return Text(initials);
    }

    // Check if URL contains 'svg' - handles DiceBear URLs like /svg?seed=...
    if (url!.toLowerCase().contains('svg')) {
      return SvgPicture.network(
          fixDiceBearUrl(url)!,
          width: 40,
          height: 40,
          placeholderBuilder: (_) => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          errorBuilder: (context, error, stackTrace) {
            debugPrint('SVG load error for URL: ${fixDiceBearUrl(url)}');
            debugPrint('Error: $error');
            return const Text('?');
          },
        );
    }

    return Image.network(
      url,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Text(initials);
      },
    );
  }

  Widget _buildGroupAvatar(String? url, String fallback, double radius) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : '?';

    if ((url ?? '').isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          letter,
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    // Check if URL contains 'svg' - handles DiceBear URLs
    if (url!.toLowerCase().contains('svg')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: ClipOval(
          child: SvgPicture.network(
            fixDiceBearUrl(url)!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholderBuilder: (_) => SizedBox(
              width: radius,
              height: radius,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            errorBuilder: (context, error, stackTrace) {
              debugPrint('SVG load error for URL: ${fixDiceBearUrl(url)}');
              return Text(
                letter,
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (exception, stackTrace) {
        debugPrint('Image load error: $exception');
      },
      child: const SizedBox.shrink(),
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _buyinController = TextEditingController();
    _additionalBuyinController = TextEditingController();
    _occurrencesController = TextEditingController(text: '4');
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _selectedTime = TimeOfDay.now();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _buyinController.dispose();
    _additionalBuyinController.dispose();
    _occurrencesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _generateWittyName() {
    final wittyNames = [
      'All-In Alley',
      'Royal Flush Rush',
      'Chip Chase Championship',
      'Bluff Boulevard',
      'Poker Face Palace',
      'Full House Fiesta',
      'The Flop Shop',
      'River Rats Rendezvous',
      'Ace High Hangout',
      'Showdown Showtime',
      'The Turn Table',
      'Pocket Rockets Party',
      'Straight Street Shuffle',
      'Betting Bonanza',
      'High Stakes Hideout',
      'The Big Blind Bash',
      'Dealer\'s Choice Duel',
      'Card Shark Soiree',
      'Nuts & Bolts Night',
      'The Check-Raise Challenge',
      'Pot Odds Playground',
      'Felt Fury Friday',
      'Texas Hold\'em Throwdown',
      'Ante Up Arena',
      'The Cooler Club',
      'Bad Beat Boulevard',
      'Rainbow Flop Fest',
      'Set Mining Society',
      'The Grind House',
      'Fish Fry Friday',
    ];

    final random = DateTime.now().millisecondsSinceEpoch % wittyNames.length;
    setState(() {
      _nameController.text = wittyNames[random];
    });
  }

  void _showAddLocationDialog() {
    final streetController = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController();
    final postalController = TextEditingController();
    final labelController = TextEditingController();
    String country = 'USA';

    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.surface,
                        colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.add_location_alt,
                                color: colorScheme.onPrimaryContainer,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add Location',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'New game location',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Label Field
                        TextFormField(
                          controller: labelController,
                          decoration: InputDecoration(
                            labelText: 'Label (Optional)',
                            hintText: 'John\'s House',
                            prefixIcon: Icon(Icons.label_outline, color: colorScheme.primary, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Street Address
                        TextFormField(
                          controller: streetController,
                          decoration: InputDecoration(
                            labelText: 'Street Address *',
                            hintText: '123 Main St',
                            prefixIcon: Icon(Icons.home_outlined, color: colorScheme.primary, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // City
                        TextFormField(
                          controller: cityController,
                          decoration: InputDecoration(
                            labelText: 'City',
                            hintText: 'San Francisco',
                            prefixIcon: Icon(Icons.location_city, color: colorScheme.primary, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // State and Postal Code Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: stateController,
                                decoration: InputDecoration(
                                  labelText: 'State',
                                  hintText: 'CA',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: postalController,
                                decoration: InputDecoration(
                                  labelText: 'Zip',
                                  hintText: '94102',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () async {
                                if (streetController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Please enter street address'),
                                      backgroundColor: colorScheme.error,
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  final context0 = context;

                                  await ref.read(createLocationNotifierProvider.notifier).createLocation(
                                        groupId: widget.groupId,
                                        streetAddress: streetController.text,
                                        city: cityController.text.isEmpty ? null : cityController.text,
                                        stateProvince: stateController.text.isEmpty ? null : stateController.text,
                                        postalCode: postalController.text.isEmpty ? null : postalController.text,
                                        country: country,
                                        label: labelController.text.isEmpty ? null : labelController.text,
                                      );

                                  await Future.delayed(const Duration(milliseconds: 500));

                                  if (mounted) {
                                    ref.refresh(groupLocationsProvider(widget.groupId));
                                    Navigator.pop(context0);

                                    if (mounted) {
                                      ScaffoldMessenger.of(context0).showSnackBar(
                                        const SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.white),
                                              SizedBox(width: 12),
                                              Text('Location added'),
                                            ],
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: colorScheme.error,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.add_location, size: 18),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addAdditionalBuyin() {
    final value = double.tryParse(_additionalBuyinController.text);
    if (value != null && value > 0) {
      setState(() {
        _additionalBuyins.add(value);
        _additionalBuyinController.clear();
      });
    }
  }

  /// Calculate the next game date based on the recurring frequency
  DateTime _calculateNextDate(DateTime currentDate, String frequency) {
    switch (frequency) {
      case 'weekly':
        return currentDate.add(const Duration(days: 7));
      case 'biweekly':
        return currentDate.add(const Duration(days: 14));
      case 'monthly':
        return DateTime(
          currentDate.year,
          currentDate.month + 1,
          currentDate.day,
          currentDate.hour,
          currentDate.minute,
        );
      case 'bimonthly':
        return DateTime(
          currentDate.year,
          currentDate.month + 2,
          currentDate.day,
          currentDate.hour,
          currentDate.minute,
        );
      case 'yearly':
        return DateTime(
          currentDate.year + 1,
          currentDate.month,
          currentDate.day,
          currentDate.hour,
          currentDate.minute,
        );
      default:
        return currentDate.add(const Duration(days: 7));
    }
  }

  /// Get locations for selected members
  /// Returns group locations and member locations from the locations table
  Future<List<LocationModel>> _getFilteredLocations(
    List<LocationModel> allLocations,
    List<dynamic> members,
  ) async {
    // If no members selected, return just group-level locations
    if (_selectedPlayerIds.isEmpty) {
      return allLocations.where((loc) => loc.profileId == null).toList();
    }

    // Get the selected members' profiles
    final selectedMembers = members
        .where((m) => _selectedPlayerIds.contains(m.userId))
        .toList();

    // Extract unique profile IDs for filtering
    final memberProfileIds = <String>{};
    for (final member in selectedMembers) {
      if (member.profile != null) {
        memberProfileIds.add(member.profile!.id);
      }
    }

    // Return group locations + member locations (no duplicates needed - locations table is source of truth)
    return allLocations.where((location) {
      // Include group-level locations
      if (location.profileId == null) return true;

      // Include locations belonging to selected members
      if (memberProfileIds.contains(location.profileId)) return true;

      return false;
    }).toList();
  }


  Future<void> _createGame() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter game name')),
      );
      return;
    }

    if (_buyinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter buy-in amount')),
      );
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    if (_selectedPlayerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one player')),
      );
      return;
    }

    final buyin = double.tryParse(_buyinController.text);

    if (buyin == null || buyin <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid buy-in amount')),
      );
      return;
    }

    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      // Get the location address if a location was selected
      String? locationString;
      if (_selectedLocationId != null) {
        final locationsAsync = ref.read(groupLocationsProvider(widget.groupId));
        final locations = locationsAsync.value ?? [];
        try {
          final selectedLocation = locations.firstWhere(
            (loc) => loc.id == _selectedLocationId,
          );
          // Use label if available, otherwise full address
          locationString = selectedLocation.label ?? selectedLocation.fullAddress;
        } catch (e) {
          // Location not found, locationString stays null
        }
      }

      // Determine how many games to create
      final gamesToCreate = _isRecurring ? _occurrences : 1;

      if (_isRecurring) {
        // Pop the screen immediately, then create games in the background
        if (mounted) Navigator.pop(context);
        Future(() async {
          for (int i = 0; i < gamesToCreate; i++) {
            DateTime gameDateTime = dateTime;
            if (i > 0) {
              DateTime previousDate = dateTime;
              for (int j = 0; j < i; j++) {
                previousDate = _calculateNextDate(previousDate, _recurringFrequency);
              }
              gameDateTime = previousDate;
            }
            String gameName = _nameController.text;
            if (gamesToCreate > 1) {
              gameName = '$gameName ${i + 1}/$gamesToCreate';
            }
            await ref.read(createGameProvider.notifier).createGame(
              groupId: widget.groupId,
              name: gameName,
              gameDate: gameDateTime,
              location: locationString,
              maxPlayers: _selectedPlayerIds.length,
              currency: _selectedCurrency,
              buyinAmount: buyin,
              additionalBuyinValues: _additionalBuyins,
              participantUserIds: _selectedPlayerIds.toList(),
              allowMemberTransactions: _allowMemberTransactions,
            );
            if (i < gamesToCreate - 1) {
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }
          // Invalidate games providers after all recurring games are created
          ref.invalidate(groupGamesProvider(widget.groupId));
          ref.invalidate(activeGamesProvider);
        });
        return;
      }

      // Create games based on schedule
      for (int i = 0; i < gamesToCreate; i++) {
        // Calculate the date for this game
        DateTime gameDateTime = dateTime;
        if (i > 0) {
          // For subsequent games, calculate based on frequency
          DateTime previousDate = dateTime;
          for (int j = 0; j < i; j++) {
            previousDate = _calculateNextDate(previousDate, _recurringFrequency);
          }
          gameDateTime = previousDate;
        }
        
        // Generate game name with sequence number if recurring
        String gameName = _nameController.text;
        if (_isRecurring && gamesToCreate > 1) {
          gameName = '$gameName ${i + 1}/$gamesToCreate';
        }

        // Create the game
        await ref.read(createGameProvider.notifier).createGame(
              groupId: widget.groupId,
              name: gameName,
              gameDate: gameDateTime,
              location: locationString,
              maxPlayers: _selectedPlayerIds.length,
              currency: _selectedCurrency,
              buyinAmount: buyin,
              additionalBuyinValues: _additionalBuyins,
              participantUserIds: _selectedPlayerIds.toList(),
              allowMemberTransactions: _allowMemberTransactions,
            );

        // Generate seating chart if option is enabled
        if (_generateSeatingChart) {
          final createdGameState = ref.read(createGameProvider);
          createdGameState.whenData((game) async {
            if (game != null) {
              // Create mock participants list for seating chart generation
              final participants = _selectedPlayerIds.map((userId) {
                return GameParticipantModel(
                  id: '',
                  gameId: game.id,
                  userId: userId,
                  rsvpStatus: 'going',
                  totalBuyin: 0,
                  totalCashout: 0,
                  netResult: 0,
                );
              }).toList();

              final seatingChart = SeatingChartService.generateSeatingChart(participants);
              if (seatingChart.isNotEmpty) {
                await ref.read(gamesRepositoryProvider).updateSeatingChart(
                  gameId: game.id,
                  seatingChart: seatingChart,
                );
              }
            }
          });
        }

        // Small delay between creations to avoid overwhelming the database
        if (i < gamesToCreate - 1) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      if (mounted) {
        // Invalidate games providers to refresh the games list
        ref.invalidate(groupGamesProvider(widget.groupId));
        ref.invalidate(activeGamesProvider);

        final successMessage = _isRecurring
            ? '$gamesToCreate games created successfully!'
            : 'Game created successfully!';

        // Show a dialog to confirm starting the game (only for single games)
        if (!_isRecurring) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Game Created'),
              content: const Text('Start the game now? All selected players are assumed to have paid their buy-in.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close Create Game screen
                  },
                  child: const Text('Create Game'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog
                    await _startGame(
                      groupId: widget.groupId,
                      gameName: _nameController.text,
                      playerIds: _selectedPlayerIds.toList(),
                      buyinAmount: buyin,
                      currency: _selectedCurrency,
                    );
                  },
                  child: const Text('Create and Start Game'),
                ),
              ],
            ),
          );
        } else {
          // For recurring games, just go back (no snackbar)
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating game: $e')),
        );
      }
    }
  }

  Future<void> _startGame({
    required String groupId,
    required String gameName,
    required List<String> playerIds,
    required double buyinAmount,
    required String currency,
  }) async {
    try {
      // Removed avatar debug logging
      
      // Get the game ID from the create game provider state
      final createGameState = ref.read(createGameProvider);
      final gameId = createGameState.maybeWhen(
        data: (game) => game?.id,
        orElse: () => null,
      );
      
      if (gameId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Game ID not found')),
          );
        }
        return;
      }
      
      // Update game status to 'in_progress'
      await ref.read(startGameProvider.notifier).startExistingGame(gameId);
      
      // Refresh the active games provider to reflect the status change
      ref.invalidate(activeGamesProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game started! Buy-ins recorded.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting game: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final createGameState = ref.watch(createGameProvider);
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    final locationsAsync = ref.watch(groupLocationsProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text('Create Game', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        // title: Row(
        //   mainAxisAlignment: MainAxisAlignment.center,
        //   mainAxisSize: MainAxisSize.min,
        //   children: [
        //     Material(
        //       color: Colors.transparent,
        //       child: InkWell(
        //         borderRadius: BorderRadius.circular(20),
        //         onTap: () {
        //           if (_scrollController.hasClients) {
        //             _scrollController.animateTo(
        //               0,
        //               duration: const Duration(milliseconds: 500),
        //               curve: Curves.easeInOut,
        //             );
        //           }
        //         },
        //         child: Container(
        //           padding: const EdgeInsets.all(8),
        //           decoration: BoxDecoration(
        //             color: colorScheme.primaryContainer,
        //             shape: BoxShape.circle,
        //           ),
        //           child: Icon(Icons.arrow_upward, size: 18, color: colorScheme.onPrimaryContainer),
        //         ),
        //       ),
        //     ),
        //     const SizedBox(width: 12),
        //     Text('Create Game', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        //     const SizedBox(width: 12),
        //     Material(
        //       color: Colors.transparent,
        //       child: InkWell(
        //         borderRadius: BorderRadius.circular(20),
        //         onTap: () {
        //           if (_scrollController.hasClients) {
        //             _scrollController.animateTo(
        //               _scrollController.position.maxScrollExtent,
        //               duration: const Duration(milliseconds: 500),
        //               curve: Curves.easeInOut,
        //             );
        //           }
        //         },
        //         child: Container(
        //           padding: const EdgeInsets.all(8),
        //           decoration: BoxDecoration(
        //             color: colorScheme.primaryContainer,
        //             shape: BoxShape.circle,
        //           ),
        //           child: Icon(Icons.arrow_downward, size: 18, color: colorScheme.onPrimaryContainer),
        //         ),
        //       ),
        //     ),
        //   ],
        // ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Name and Description Display
            groupAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
              data: (group) {
                if (group == null) {
                  return const SizedBox.shrink();
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withOpacity(0.3),
                        colorScheme.secondaryContainer.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: (group.avatarUrl?.isNotEmpty == true)
                                  ? _buildGroupAvatar(group.avatarUrl, group.name, 24)
                                  : CircleAvatar(
                                      radius: 24,
                                      backgroundColor: colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.group,
                                        size: 28,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (group.description != null && group.description!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      group.description!,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Game Name
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Game Name',
                  hintText: 'e.g., Friday Night Game',
                  prefixIcon: Icon(Icons.casino, color: colorScheme.primary),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.auto_awesome, color: colorScheme.primary),
                    tooltip: 'Generate witty name',
                    onPressed: _generateWittyName,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date and Time
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today, color: colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                        ),
                        child: Text(
                          _selectedDate != null
                              ? _dateFormatter.format(_selectedDate!)
                              : 'Select date',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Time',
                          prefixIcon: Icon(Icons.access_time, color: colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                        ),
                        child: Text(
                          _selectedTime != null
                              ? _selectedTime!.format(context)
                              : 'Select time',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Recurring Games Section
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.tertiaryContainer.withOpacity(0.3),
                    colorScheme.primaryContainer.withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.repeat,
                            size: 20,
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Recurring Games',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Switch(
                          value: _isRecurring,
                          onChanged: (value) {
                            setState(() => _isRecurring = value);
                          },
                        ),
                      ],
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Create multiple games on a schedule',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _recurringFrequency,
                        decoration: InputDecoration(
                          labelText: 'Frequency',
                          prefixIcon: Icon(Icons.event_repeat, color: colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'biweekly', child: Text('Every 2 Weeks')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'bimonthly', child: Text('Every 2 Months')),
                          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _recurringFrequency = value;
                              int defaultOccurrences;
                              switch (value) {
                                case 'weekly':
                                  defaultOccurrences = 52;
                                  break;
                                case 'biweekly':
                                  defaultOccurrences = 26;
                                  break;
                                case 'monthly':
                                  defaultOccurrences = 12;
                                  break;
                                case 'bimonthly':
                                  defaultOccurrences = 6;
                                  break;
                                case 'yearly':
                                  defaultOccurrences = 1;
                                  break;
                                default:
                                  defaultOccurrences = 4;
                              }
                              _occurrences = defaultOccurrences;
                              _occurrencesController.text = defaultOccurrences.toString();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _occurrencesController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Number of Games',
                          hintText: '4',
                          prefixIcon: Icon(Icons.format_list_numbered, color: colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                          helperText: 'How many games to create',
                        ),
                        onChanged: (value) {
                          final occurrences = int.tryParse(value) ?? 4;
                          setState(() => _occurrences = occurrences.clamp(1, 52));
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Seating Chart Option
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.event_seat,
                        size: 20,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generate Seating Chart',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Randomly assign seats to players',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _generateSeatingChart,
                      onChanged: (value) {
                        setState(() => _generateSeatingChart = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Allow Member Transactions Option
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.swap_horiz,
                        size: 20,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Allow Member Transactions',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Let all members add buy-ins and cash-outs',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _allowMemberTransactions,
                      onChanged: (value) {
                        setState(() => _allowMemberTransactions = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Players Section (moved before location)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.people,
                        size: 20,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Select Players',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                membersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (members) {
                    if (members.isEmpty) return const SizedBox.shrink();

                    final allSelected = members.every((m) => _selectedPlayerIds.contains(m.userId));
                    
                    return TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (allSelected) {
                            _selectedPlayerIds.clear();
                          } else {
                            _selectedPlayerIds.addAll(members.map((m) => m.userId));
                          }
                        });
                      },
                      icon: Icon(allSelected ? Icons.check_box : Icons.check_box_outline_blank),
                      label: Text(allSelected ? 'Deselect All' : 'Select All'),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error loading members: $error'),
              data: (members) {
                if (members.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No members in this group'),
                  );
                }

                return Column(
                  children: members.map((member) {
                    final isSelected = _selectedPlayerIds.contains(member.userId);
                    final displayName =
                        member.profile?.fullName ?? member.userId;
                    final initialsText = (member.profile?.firstName ?? 'U')[0].toUpperCase() +
                        (member.profile?.lastName ?? '')[0].toUpperCase();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.primaryContainer.withOpacity(0.3) : colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked ?? false) {
                              _selectedPlayerIds.add(member.userId);
                            } else {
                              _selectedPlayerIds.remove(member.userId);
                            }
                          });
                        },
                        secondary: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? colorScheme.primary : colorScheme.outline,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: _buildMemberAvatar(
                              member.profile?.avatarUrl,
                              initialsText,
                            ),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        subtitle: member.role != 'member'
                            ? Text(
                                '${member.role} of group',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),

            // Location Dropdown
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on,
                    size: 20,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            locationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error loading locations: $error'),
              data: (allLocations) {
                return membersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Text('Error loading members: $error'),
                  data: (members) {
                    return FutureBuilder<List<LocationModel>>(
                      future: _getFilteredLocations(allLocations, members),
                      builder: (context, snapshot) {
                        final locations = snapshot.data ?? allLocations;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonFormField<String?>(
                                // ignore: deprecated_member_use
                                value: _selectedLocationId,
                                decoration: InputDecoration(
                                  labelText: 'Location',
                                  hintText: 'Select a location',
                                  prefixIcon: Icon(Icons.place, color: colorScheme.primary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surface,
                                  suffixIcon: locations.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.add_circle, color: colorScheme.primary),
                                          onPressed: _showAddLocationDialog,
                                        )
                                      : null,
                                ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('No Location'),
                                ),
                                ...locations.map((location) {
                                  // Show label if available, otherwise show full address
                                  final hasLabel = location.label != null && location.label!.isNotEmpty;
                                  final fullAddr = location.fullAddress;
                                  final displayText = hasLabel ? location.label! : (fullAddr.isNotEmpty ? fullAddr : 'Unknown Location');

                                  return DropdownMenuItem(
                                    value: location.id,
                                    child: Text(
                                      displayText,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }),
                              ],
                                onChanged: (value) {
                                  setState(() => _selectedLocationId = value);
                                },
                              ),
                            ),
                            if (locations.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _showAddLocationDialog,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.all(16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.add_location),
                                    label: const Text('Add Location'),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // Buy-in Settings
            groupAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text('Error loading group: $error'),
              data: (group) {
                if (group == null) {
                  return const Text('Group not found');
                }

                // Auto-populate buy-in and currency on first load
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_buyinController.text.isEmpty) {
                    _buyinController.text = group.defaultBuyin.toString();
                  }
                  if (_selectedCurrency == 'USD' &&
                      group.defaultCurrency != _selectedCurrency) {
                    setState(() => _selectedCurrency = group.defaultCurrency);
                  }
                  if (_additionalBuyins.isEmpty &&
                      group.additionalBuyinValues.isNotEmpty) {
                    setState(() => _additionalBuyins = List.from(group.additionalBuyinValues));
                  }
                });

                IconData getCurrencyIcon(String currency) {
                  switch (currency) {
                    case 'EUR':
                      return Icons.euro;
                    case 'GBP':
                      return Icons.currency_pound;
                    case 'JPY':
                      return Icons.currency_yen;
                    case 'INR':
                      return Icons.currency_rupee;
                    case 'USD':
                    default:
                      return Icons.attach_money;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            getCurrencyIcon(group.defaultCurrency),
                            size: 20,
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Buy-in Settings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            Currencies.symbols[group.defaultCurrency] ?? group.defaultCurrency,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Buy-in and Additional Buy-in on one line
                    Row(
                      children: [
                        // Buy-in Amount
                        Expanded(
                          flex: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _buyinController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Buy-in Amount',
                                hintText: '100',
                                prefixIcon: Icon(Icons.paid, color: colorScheme.primary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Additional Buy-in Input
                        Expanded(
                          flex: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _additionalBuyinController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Add Buy-in',
                                hintText: '50',
                                prefixIcon: Icon(Icons.add_card, color: colorScheme.primary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surface,
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.add_circle, color: colorScheme.primary),
                                  onPressed: _addAdditionalBuyin,
                                ),
                              ),
                              onFieldSubmitted: (_) => _addAdditionalBuyin(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Create and Start Game Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: createGameState.isLoading ? null : _createGame,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: createGameState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add_circle_outline, size: 24),
                  label: Text(
                    createGameState.isLoading ? 'Creating...' : 'Create Game',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
