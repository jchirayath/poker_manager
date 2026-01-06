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

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedCurrency = 'USD';
  List<double> _additionalBuyins = [];
  String? _selectedLocationId;
  final Set<String> _selectedPlayerIds = {};

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
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _selectedTime = TimeOfDay.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _buyinController.dispose();
    _additionalBuyinController.dispose();
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
      // Create the game
      await ref.read(createGameProvider.notifier).createGame(
            groupId: widget.groupId,
            name: _nameController.text,
            gameDate: dateTime,
            location: _selectedLocationId,
            maxPlayers: _selectedPlayerIds.length,
            currency: _selectedCurrency,
            buyinAmount: buyin,
            additionalBuyinValues: _additionalBuyins,
            participantUserIds: _selectedPlayerIds.toList(),
          );

      if (mounted) {
        // Show a dialog to confirm starting the game
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
      debugPrint('🎮 Starting game: $gameName with ${playerIds.length} players');
      
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
                  padding: const EdgeInsets.only(bottom: 16),
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

            // Players Section (moved before location)
            Text(
              'Select Players',
              style: Theme.of(context).textTheme.titleMedium,
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
                    // Currency, Buy-in, Additional Buy-in input on one line
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
                        // Additional Buy-in Input
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
                    // Display additional buy-ins
                    if (_additionalBuyins.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _additionalBuyins.asMap().entries.map((entry) {
                          return Chip(
                            label: Text('$_selectedCurrency ${entry.value}'),
                            onDeleted: () => _removeAdditionalBuyin(entry.key),
                            backgroundColor: Colors.blue.withValues(alpha: 0.2),
                          );
                        }).toList(),
                      ),
                    ],
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
                    : const Text('Create & Start Game'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
