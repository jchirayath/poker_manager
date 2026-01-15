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
import '../../data/models/game_model.dart';

class EditGameScreen extends ConsumerStatefulWidget {
  final String gameId;

  const EditGameScreen({required this.gameId, super.key});

  @override
  ConsumerState<EditGameScreen> createState() => _EditGameScreenState();
}

class _EditGameScreenState extends ConsumerState<EditGameScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _buyinController;
  late final TextEditingController _additionalBuyinController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedCurrency = 'USD';
  double? _additionalBuyin;
  String? _selectedLocationId;
  String? _groupId;
  bool _isInitialized = false;

  // Cache date formatter to avoid recreation
  static final DateFormat _dateFormatter = DateFormat('MMM d, yyyy');

  Widget _buildMemberAvatar(String? url, String initials) {
    if ((url ?? '').isEmpty) {
      return Text(initials);
    }

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
            return Text('?');
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

  String? _gameLocationString;

  void _initializeFromGame(GameModel game) {
    if (_isInitialized) return;
    
    _nameController.text = game.name;
    _buyinController.text = game.buyinAmount.toString();
    _selectedDate = game.gameDate;
    _selectedTime = TimeOfDay.fromDateTime(game.gameDate);
    _selectedCurrency = game.currency;
    _additionalBuyin = game.additionalBuyinValues.isNotEmpty ? game.additionalBuyinValues.first : null;
    _additionalBuyinController.text = _additionalBuyin?.toString() ?? '';
    _gameLocationString = game.location; // Store for later matching
    _selectedLocationId = null; // Will be set when locations load
    _groupId = game.groupId;
    _isInitialized = true;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _buyinController = TextEditingController();
    _additionalBuyinController = TextEditingController();
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
    if (_groupId == null) return;

    final streetController = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController();
    final postalController = TextEditingController();
    final labelController = TextEditingController();
    String country = 'United States';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                    DropdownButtonFormField<String>(
                      value: country,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        'United States',
                        'Canada',
                        'Mexico',
                        'United Kingdom',
                        'Australia',
                        'Germany',
                        'France',
                        'Spain',
                        'Italy',
                        'Japan',
                        'China',
                        'India',
                        'Brazil',
                        'Other',
                      ]
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => country = value);
                        }
                      },
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter street address')),
                  );
                  return;
                }

                try {
                  final context0 = context;
                  
                  await ref.read(createLocationNotifierProvider.notifier).createLocation(
                        groupId: _groupId!,
                        streetAddress: streetController.text,
                        city: cityController.text.isEmpty ? null : cityController.text,
                        stateProvince: stateController.text.isEmpty ? null : stateController.text,
                        postalCode: postalController.text.isEmpty ? null : postalController.text,
                        country: country,
                        label: labelController.text.isEmpty ? null : labelController.text,
                      );

                  await Future.delayed(const Duration(milliseconds: 500));

                  if (mounted) {
                    // Refresh locations and get the updated list
                    ref.refresh(groupLocationsProvider(_groupId!));
                    
                    // Get the updated locations list
                    final updatedLocations = await ref.read(groupLocationsProvider(_groupId!).future);
                    
                    if (updatedLocations.isNotEmpty) {
                      // Select the most recently created location (first in the list if sorted by created_at desc)
                      setState(() {
                        _selectedLocationId = updatedLocations.first.id;
                      });
                    }
                    
                    Navigator.pop(context0);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context0).showSnackBar(
                        const SnackBar(content: Text('Location added successfully')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
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
      },
    );
  }

  void _updateAdditionalBuyin(String value) {
    final parsedValue = double.tryParse(value);
    setState(() {
      _additionalBuyin = (parsedValue != null && parsedValue > 0) ? parsedValue : null;
    });
  }

  Future<void> _updateGame() async {
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
      await ref.read(updateGameProvider.notifier).updateGame(
            gameId: widget.gameId,
            name: _nameController.text,
            gameDate: dateTime,
            location: _selectedLocationId,
            currency: _selectedCurrency,
            buyinAmount: buyin,
            additionalBuyinValues: _additionalBuyin != null ? [_additionalBuyin!] : [],
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game updated successfully!')),
        );
        Navigator.pop(context, true); // Return true to indicate successful update
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating game: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameDetailProvider(widget.gameId));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Game'),
        centerTitle: true,
      ),
      body: gameAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (game) {
          if (game == null) {
            return const Center(child: Text('Game not found'));
          }

          // Initialize form fields from game data
          _initializeFromGame(game);

          final groupAsync = ref.watch(groupProvider(game.groupId));
          final locationsAsync = ref.watch(groupLocationsProvider(game.groupId));
          final updateGameState = ref.watch(updateGameProvider);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group Name Display
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
                                ? _dateFormatter.format(_selectedDate!)
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

                // Location Dropdown
                locationsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Text('Error loading locations: $error'),
                  data: (locations) {
                    // On first load, try to match game location string to location ID
                    if (_selectedLocationId == null && _gameLocationString != null && locations.isNotEmpty) {
                      LocationModel? matchingLocation;
                      for (final loc in locations) {
                        if (loc.fullAddress == _gameLocationString || loc.label == _gameLocationString) {
                          matchingLocation = loc;
                          break;
                        }
                      }
                      if (matchingLocation != null) {
                        _selectedLocationId = matchingLocation.id;
                      }
                      // If no match found, leave it as null
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String?>(
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
                ),
                const SizedBox(height: 16),

                // Currency, Buy-in, and Additional Buy-ins
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Currency
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _selectedCurrency,
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
                            decoration: const InputDecoration(
                              labelText: 'Add Buy-in',
                              hintText: '50',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: _updateAdditionalBuyin,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Update Game Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: updateGameState.isLoading ? null : () => _updateGameWithLocationString(locationsAsync),
                    child: updateGameState.isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Update Game'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Future<void> _updateGameWithLocationString(AsyncValue<List<LocationModel>> locationsAsync) async {
    // Convert location ID back to full address for storage
    String? locationString;
    
    locationsAsync.whenData((locations) {
      if (_selectedLocationId != null) {
        final location = locations.firstWhere(
          (loc) => loc.id == _selectedLocationId,
          orElse: () => null as LocationModel,
        );
        if (location != null) {
          locationString = location.fullAddress;
        }
      }
    });
    
    // Call the original update game with the location string
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
      await ref.read(updateGameProvider.notifier).updateGame(
            gameId: widget.gameId,
            name: _nameController.text,
            gameDate: dateTime,
            location: locationString,
            currency: _selectedCurrency,
            buyinAmount: buyin,
            additionalBuyinValues: _additionalBuyin != null ? [_additionalBuyin!] : [],
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game updated successfully!')),
        );
        Navigator.pop(context, true); // Return true to indicate successful update
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating game: $e')),
        );
      }
    }
  }
}
