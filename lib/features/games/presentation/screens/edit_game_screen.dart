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
  bool _allowMemberTransactions = false;
  final Set<String> _selectedPlayerIds = {};

  // Cache date formatter to avoid recreation
  static final DateFormat _dateFormatter = DateFormat('MMM d, yyyy');

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
    _allowMemberTransactions = game.allowMemberTransactions;
    _isInitialized = true;

    // Load existing participants
    _loadExistingParticipants();
  }

  Future<void> _loadExistingParticipants() async {
    if (_groupId == null) return;

    final participantsAsync = ref.read(gameWithParticipantsProvider(widget.gameId));
    participantsAsync.whenData((gameWithParticipants) {
      if (mounted) {
        setState(() {
          _selectedPlayerIds.clear();
          _selectedPlayerIds.addAll(
            gameWithParticipants.participants.map((p) => p.userId),
          );
        });
      }
    });
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
                      initialValue: country,
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
                    // ignore: unused_result
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
                    if (context0.mounted) {
                      ScaffoldMessenger.of(context0).showSnackBar(
                        const SnackBar(content: Text('Location added successfully')),
                      );
                    }
                  }
                } catch (e) {
                  final context0 = context;
                  if (context0.mounted) {
                    ScaffoldMessenger.of(context0).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameDetailProvider(widget.gameId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Edit Game'),
        centerTitle: true,
      ),
      body: gameAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (game) {
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
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer.withAlpha((0.3 * 255).toInt()),
                            colorScheme.secondaryContainer.withAlpha((0.3 * 255).toInt()),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withAlpha((0.2 * 255).toInt()),
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
                        color: colorScheme.primary.withAlpha((0.1 * 255).toInt()),
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
                              color: colorScheme.primary.withAlpha((0.1 * 255).toInt()),
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
                              color: colorScheme.primary.withAlpha((0.1 * 255).toInt()),
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

                // Location Section
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
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withAlpha((0.1 * 255).toInt()),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedLocationId,
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
                ),
                const SizedBox(height: 20),

                // Buy-in Settings
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.attach_money,
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
                        Currencies.symbols[_selectedCurrency] ?? _selectedCurrency,
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
                              color: colorScheme.primary.withAlpha((0.1 * 255).toInt()),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _buyinController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                              color: colorScheme.primary.withAlpha((0.1 * 255).toInt()),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _additionalBuyinController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Add Buy-in',
                            hintText: '50',
                            prefixIcon: Icon(Icons.add_card, color: colorScheme.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface,
                          ),
                          onChanged: _updateAdditionalBuyin,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Allow Member Transactions Option
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest.withAlpha((0.3 * 255).toInt()),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: colorScheme.outline.withAlpha((0.2 * 255).toInt()),
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

                // Player Selection Section (only for scheduled games)
                if (game.status == 'scheduled') ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.people,
                          size: 20,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Players',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ref.watch(groupMembersProvider(_groupId ?? '')).when(
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
                  ref.watch(groupMembersProvider(_groupId ?? '')).when(
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
                          final displayName = member.profile?.fullName ?? member.userId;
                          final initialsText = (member.profile?.firstName ?? 'U')[0].toUpperCase() +
                              (member.profile?.lastName ?? '')[0].toUpperCase();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? colorScheme.primaryContainer.withAlpha((0.3 * 255).toInt()) : colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? colorScheme.primary : colorScheme.outline.withAlpha((0.3 * 255).toInt()),
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
                ],

                // Update Game Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withAlpha((0.8 * 255).toInt()),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withAlpha((0.3 * 255).toInt()),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: updateGameState.isLoading ? null : () => _updateGameWithLocationString(locationsAsync),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: updateGameState.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save, size: 24),
                      label: Text(
                        updateGameState.isLoading ? 'Updating...' : 'Update Game',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Future<void> _updateGameWithLocationString(AsyncValue<List<LocationModel>> locationsAsync) async {
    // Get the current game to check status
    final gameAsync = ref.read(gameDetailProvider(widget.gameId));
    final game = gameAsync.value;

    // Convert location ID back to full address for storage
    String? locationString;

    locationsAsync.whenData((locations) {
      if (_selectedLocationId != null) {
        try {
          final location = locations.firstWhere(
            (loc) => loc.id == _selectedLocationId,
          );
          locationString = location.label ?? location.fullAddress;
        } catch (e) {
          // Location not found
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
            allowMemberTransactions: _allowMemberTransactions,
            // Only update participants for scheduled games
            participantUserIds: (game?.status == 'scheduled' && _selectedPlayerIds.isNotEmpty)
                ? _selectedPlayerIds.toList()
                : null,
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
