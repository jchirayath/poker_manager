import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../core/utils/avatar_utils.dart';
import '../providers/games_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../locations/presentation/providers/locations_provider.dart';
import '../../../locations/data/models/location_model.dart';

class CreateGameScreen extends ConsumerStatefulWidget {
  final String groupId;

  const CreateGameScreen({required this.groupId, super.key});

  @override
  ConsumerState<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends ConsumerState<CreateGameScreen> {
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
        return AlertDialog(
          title: const Text('Add New Location'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: streetController,
                  decoration: const InputDecoration(
                    labelText: 'Street Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stateController,
                  decoration: const InputDecoration(
                    labelText: 'State/Province',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: postalController,
                  decoration: const InputDecoration(
                    labelText: 'Postal Code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label (e.g., "John\'s House")',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (streetController.text.isEmpty) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter street address')),
                  );
                  return;
                }

                try {
                  final context0 = context;
                  
                  // Create the location
                  await ref.read(createLocationNotifierProvider.notifier).createLocation(
                        groupId: widget.groupId,
                        streetAddress: streetController.text,
                        city: cityController.text.isEmpty ? null : cityController.text,
                        stateProvince: stateController.text.isEmpty ? null : stateController.text,
                        postalCode: postalController.text.isEmpty ? null : postalController.text,
                        country: country,
                        label: labelController.text.isEmpty ? null : labelController.text,
                      );

                  // Wait a moment for the database to complete
                  await Future.delayed(const Duration(milliseconds: 500));

                  if (mounted) {
                    // Refresh the locations list to get the newly created location
                    // ignore: unused_result
                    ref.refresh(groupLocationsProvider(widget.groupId));
                    
                    // Close the dialog
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context0);
                    
                    // Show success message
                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context0).showSnackBar(
                        const SnackBar(content: Text('Location added successfully')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding location: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
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

  void _removeAdditionalBuyin(int index) {
    setState(() => _additionalBuyins.removeAt(index));
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

  /// Filter locations to show only those from selected members' profiles
  /// If no members selected, show all group locations
  Future<List<LocationModel>> _getFilteredLocations(
    List<LocationModel> allLocations,
    List<dynamic> members,
  ) async {
    // If no members selected, return all group locations
    if (_selectedPlayerIds.isEmpty) {
      return allLocations;
    }

    // Get the selected members' profiles
    final selectedMembers = members
        .where((m) => _selectedPlayerIds.contains(m.userId))
        .toList();

    // Extract unique profile IDs and build a set for quick lookup
    final memberProfileIds = <String>{};

    for (final member in selectedMembers) {
      if (member.profile != null) {
        memberProfileIds.add(member.profile!.id);
      }
    }

    // Filter locations: include group-level locations OR locations associated with selected members
    final filteredLocations = allLocations
        .where((location) {
          // Include if location is associated with a selected member's profile
          if (location.profileId != null &&
              memberProfileIds.contains(location.profileId)) {
            return true;
          }
          // Include all group-level locations (no profileId) to allow manual entry
          if (location.profileId == null) {
            return true;
          }
          return false;
        })
        .toList();

    return filteredLocations;
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
        final selectedLocation = locations.firstWhere(
          (loc) => loc.id == _selectedLocationId,
          orElse: () => locations.first,
        );
        locationString = selectedLocation.label ?? selectedLocation.fullAddress;
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
            );
            if (i < gamesToCreate - 1) {
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }
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
          gameName = '$gameName ${i + 1}/${gamesToCreate}';
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
            );
        
        // Small delay between creations to avoid overwhelming the database
        if (i < gamesToCreate - 1) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      if (mounted) {
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    _startGame(
                      groupId: widget.groupId,
                      gameName: _nameController.text,
                      playerIds: _selectedPlayerIds.toList(),
                      buyinAmount: buyin,
                      currency: _selectedCurrency,
                    );
                  },
                  child: const Text('Start Game'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Game'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (group.avatarUrl?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundImage: NetworkImage(group.avatarUrl!),
                                    onBackgroundImageError: (_, __) {},
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.group,
                                    size: 24,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  group.name,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (group.description != null && group.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              group.description!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Game Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Game Name',
                hintText: 'e.g., Friday Night Game',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Date and Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _selectedDate != null
                            ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                            : 'Select date',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Time',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _selectedTime != null
                            ? _selectedTime!.format(context)
                            : 'Select time',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recurring Games Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Recurring Games',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
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
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _recurringFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                          border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: 'Number of Games',
                          hintText: '4',
                          border: OutlineInputBorder(),
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
            const SizedBox(height: 16),

            // Players Section (moved before location)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Players',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                membersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
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

                    return CheckboxListTile(
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
                      secondary: CircleAvatar(
                        child: _buildMemberAvatar(
                          member.profile?.avatarUrl,
                          initialsText,
                        ),
                      ),
                      title: Text(displayName),
                      subtitle: member.role != 'member'
                          ? Text('${member.role} of group')
                          : null,
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),

            // Location Dropdown
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
                            DropdownButtonFormField<String?>(
                              // ignore: deprecated_member_use
                              value: _selectedLocationId,
                              decoration: InputDecoration(
                                labelText: 'Location',
                                hintText: 'Select a location',
                                border: const OutlineInputBorder(),
                                suffixIcon: locations.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: _showAddLocationDialog,
                                      )
                                    : null,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('No Location'),
                                ),
                                ...locations.map((location) {
                                  return DropdownMenuItem(
                                    value: location.id,
                                    child: Text(
                                      location.label ?? location.fullAddress,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedLocationId = value);
                              },
                            ),
                            if (locations.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _showAddLocationDialog,
                                    icon: const Icon(Icons.add),
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
            const SizedBox(height: 16),

            // Currency, Buy-in, and Additional Buy-ins on one line
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Currency and Buy-in on one line
                    Row(
                      children: [
                        // Currency
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedCurrency,
                            decoration: const InputDecoration(
                              labelText: 'Currency',
                              border: OutlineInputBorder(),
                            ),
                            items: ['USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY']
                                .map((currency) => DropdownMenuItem(
                                      value: currency,
                                      child: Text(currency),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedCurrency = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Buy-in Amount
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _buyinController,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Buy-in',
                              hintText: '100',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Additional Buy-in Input - Now Editable
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _additionalBuyinController,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Add Buy-in',
                              hintText: '50',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: _addAdditionalBuyin,
                              ),
                            ),
                            onFieldSubmitted: (_) => _addAdditionalBuyin(),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Create and Start Game Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: createGameState.isLoading ? null : _createGame,
                child: createGameState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create Game'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
