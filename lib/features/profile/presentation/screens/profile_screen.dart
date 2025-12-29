import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/profile_provider.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUserAsync = ref.watch(authStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push(RouteConstants.editProfile),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final controller = ref.read(authControllerProvider);
              await controller.signOut();
              if (context.mounted) {
                context.go(RouteConstants.signIn);
              }
            },
          ),
        ],
      ),
      body: authUserAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not signed in'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null && user.firstName.isNotEmpty
                      ? Text(
                          (user.firstName.isNotEmpty ? user.firstName[0] : '') + 
                          (user.lastName.isNotEmpty ? user.lastName[0] : ''),
                          style: const TextStyle(fontSize: 32),
                        )
                      : user.avatarUrl == null
                          ? const Icon(Icons.person, size: 60)
                          : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user.firstName.isNotEmpty || user.lastName.isNotEmpty
                      ? user.fullName
                      : 'User',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user.username != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '@${user.username}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _buildInfoCard(
                  context,
                  'Contact Information',
                  [
                    _InfoRow(icon: Icons.email, label: user.email),
                    if (user.phoneNumber != null)
                      _InfoRow(icon: Icons.phone, label: user.phoneNumber!),
                  ],
                ),
                if (user.hasAddress) ...[
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    context,
                    'Address',
                    [
                      _InfoRow(
                        icon: Icons.location_on,
                        label: user.fullAddress,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
