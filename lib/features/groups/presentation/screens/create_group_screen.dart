import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/groups_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_constants.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _privacy = 'private';
  String _currency = AppConstants.currencies.first;
  double _defaultBuyin = 100.0;
  final List<double> _additionalBuyins = [50.0, 100.0, 200.0];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final controller = ref.read(groupControllerProvider);
    final groupId = await controller.createGroup(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      privacy: _privacy,
      defaultCurrency: _currency,
      defaultBuyin: _defaultBuyin,
      additionalBuyinValues: _additionalBuyins,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (groupId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created successfully')),
      );
      context.go(RouteConstants.groupDetail.replaceAll(':id', groupId));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create group')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
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
              'Default Game Settings',
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
              initialValue: _defaultBuyin.toStringAsFixed(2),
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

            const Text(
              'Additional Buy-in Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: [
                ..._additionalBuyins.asMap().entries.map((entry) {
                  final index = entry.key;
                  final amount = entry.value;
                  return Chip(
                    label: Text('$_currency ${amount.toStringAsFixed(2)}'),
                    onDeleted: () {
                      setState(() => _additionalBuyins.removeAt(index));
                    },
                  );
                }),
                InputChip(
                  label: const Icon(Icons.add),
                  onPressed: () => _showAddBuyinDialog(),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _createGroup,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Group', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddBuyinDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Buy-in Amount'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Amount',
            prefix: Text('$_currency '),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                setState(() => _additionalBuyins.add(amount));
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
