import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/result.dart';
import '../providers/games_provider.dart' show gamesProvider;
import '../../../auth/presentation/providers/auth_provider.dart' show authStateProvider;
import '../../../groups/presentation/providers/groups_provider.dart' show groupControllerProvider;

class GameSettingsScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String groupId;

  const GameSettingsScreen({
    required this.gameId,
    required this.groupId,
    super.key,
  });

  @override
  ConsumerState<GameSettingsScreen> createState() => _GameSettingsScreenState();
}

class _GameSettingsScreenState extends ConsumerState<GameSettingsScreen> {
  bool _isLoading = true;
  bool _allowMemberTransactions = false;
  bool _isAdmin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if user is admin
      final uid = ref.read(authStateProvider).value?.id;
      if (uid != null) {
        final isAdmin = await ref.read(groupControllerProvider).isUserAdmin(widget.groupId, uid);
        if (!mounted) return;

        if (!isAdmin) {
          setState(() {
            _errorMessage = 'Only admins can access game settings';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _isAdmin = true;
        });
      }

      // Load game settings
      final gameResult = await ref.read(gamesProvider.notifier).getGame(widget.gameId);
      if (!mounted) return;

      gameResult.when(
        success: (game) {
          setState(() {
            _allowMemberTransactions = game.allowMemberTransactions;
            _isLoading = false;
          });
        },
        failure: (message, _) {
          setState(() {
            _errorMessage = message;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load settings: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSettings(bool value) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(gamesProvider.notifier).updateGameSettings(
        gameId: widget.gameId,
        allowMemberTransactions: value,
      );

      if (!mounted) return;

      result.when(
        success: (_) {
          setState(() {
            _allowMemberTransactions = value;
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        failure: (message, _) {
          setState(() {
            _errorMessage = message;
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update settings: $message'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error updating settings: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Game Settings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null && !_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Game Settings'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, color: Colors.blue),
                      const SizedBox(width: 12),
                      Text(
                        'Transaction Permissions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Allow Members to Create Transactions'),
                    subtitle: const Text(
                      'When enabled, all group members can create buy-ins and cash-outs. '
                      'When disabled, only admins can create transactions.',
                    ),
                    value: _allowMemberTransactions,
                    onChanged: _isLoading ? null : _updateSettings,
                    secondary: Icon(
                      _allowMemberTransactions ? Icons.people : Icons.admin_panel_settings,
                      color: _allowMemberTransactions ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Note: Admins can always modify and delete transactions, '
                            'regardless of this setting.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.policy, color: Colors.purple),
                      const SizedBox(width: 12),
                      Text(
                        'Current Policy',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPolicyItem(
                    icon: Icons.add_circle,
                    title: 'Create Transactions',
                    description: _allowMemberTransactions
                        ? 'All group members can create buy-ins and cash-outs'
                        : 'Only admins can create buy-ins and cash-outs',
                    color: _allowMemberTransactions ? Colors.green : Colors.orange,
                  ),
                  const Divider(height: 24),
                  _buildPolicyItem(
                    icon: Icons.edit,
                    title: 'Modify Transactions',
                    description: 'Only admins can update transaction amounts',
                    color: Colors.blue,
                  ),
                  const Divider(height: 24),
                  _buildPolicyItem(
                    icon: Icons.delete,
                    title: 'Delete Transactions',
                    description: 'Only admins can delete transactions',
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
