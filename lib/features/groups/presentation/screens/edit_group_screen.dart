import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/groups_provider.dart';
import '../../../../core/constants/app_constants.dart';

class EditGroupScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String name;
  final String? description;
  final String privacy;
  final String currency;
  final double defaultBuyin;
  final List<double> additionalBuyins;

  const EditGroupScreen({
    super.key,
    required this.groupId,
    required this.name,
    this.description,
    required this.privacy,
    required this.currency,
    required this.defaultBuyin,
    required this.additionalBuyins,
  });

  @override
  ConsumerState<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends ConsumerState<EditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _defaultBuyinController;
  late TextEditingController _additionalBuyinController;

  late String _privacy;
  late String _currency;
  late double _defaultBuyin;
  late List<double> _additionalBuyins;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _descriptionController = TextEditingController(text: widget.description ?? '');
    _defaultBuyinController = TextEditingController(text: widget.defaultBuyin.toStringAsFixed(2));
    _additionalBuyinController = TextEditingController(
      text: widget.additionalBuyins.isNotEmpty ? widget.additionalBuyins.first.toStringAsFixed(2) : '50',
    );
    _privacy = widget.privacy;
    _currency = widget.currency;
    _defaultBuyin = widget.defaultBuyin;
    _additionalBuyins = List.from(widget.additionalBuyins);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _defaultBuyinController.dispose();
    _additionalBuyinController.dispose();
    super.dispose();
  }

  Future<void> _updateGroup() async {
    debugPrint('🔵 Updating group');
    if (!_formKey.currentState!.validate()) {
      debugPrint('🔴 Form validation failed');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parse additional buyin
      final additionalValue = double.tryParse(_additionalBuyinController.text.trim());
      final additionalBuyins = <double>[];
      if (additionalValue != null && additionalValue > 0) {
        additionalBuyins.add(additionalValue);
      }

      final controller = ref.read(groupControllerProvider);
      debugPrint('🔵 Calling updateGroup for ${widget.groupId}');
      final ok = await controller.updateGroup(
        groupId: widget.groupId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        privacy: _privacy,
        defaultCurrency: _currency,
        defaultBuyin: _defaultBuyin,
        additionalBuyinValues: additionalBuyins,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (ok) {
        debugPrint('✅ Group updated successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group updated successfully')),
        );
        context.pop();
      } else {
        debugPrint('🔴 Group update failed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update group')),
        );
      }
    } catch (e, stack) {
      debugPrint('🔴 Error updating group: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Group'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name *',
                border: OutlineInputBorder(),
              ),
              maxLength: AppConstants.maxGroupNameLength,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a group name';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _privacy,
              decoration: const InputDecoration(
                labelText: 'Privacy',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'private', child: Text('Private')),
                DropdownMenuItem(value: 'public', child: Text('Public')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _privacy = value);
                }
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Game Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: AppConstants.currencies.map((currency) {
                return DropdownMenuItem(
                  value: currency,
                  child: Text(currency),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _currency = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _defaultBuyinController,
              decoration: InputDecoration(
                labelText: 'Default Buy-in',
                border: const OutlineInputBorder(),
                prefix: Text('$_currency '),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a default buy-in';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount < AppConstants.minBuyin) {
                  return 'Invalid amount';
                }
                return null;
              },
              onChanged: (value) {
                final amount = double.tryParse(value);
                if (amount != null) {
                  setState(() => _defaultBuyin = amount);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _additionalBuyinController,
              decoration: InputDecoration(
                labelText: 'Additional Buy-in (optional)',
                border: const OutlineInputBorder(),
                helperText: 'Single amount, leave blank if none',
                prefix: Text('$_currency '),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateGroup,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Update Group', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
