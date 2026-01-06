import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Widget _avatar(String? url, String initials) {
    debugPrint('🎯 Avatar URL: "$url" | Initials: "$initials"');
    if ((url ?? '').isEmpty) {
      debugPrint('📭 Using initials avatar (no URL)');
      return _initialsAvatar(initials);
    }
    
    if (url!.toLowerCase().contains('svg')) {
      debugPrint('🖼️ Loading SVG: $url');
      return ClipOval(
        child: SvgPicture.network(
          fixDiceBearUrl(url)!,
          width: 120,
          height: 120,
          placeholderBuilder: (_) => const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    debugPrint('🖼️ Loading image: $url');
    return ClipOval(
      child: Image.network(
        url,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('🔴 Error loading image avatar: $error');
          return _initialsAvatar(initials);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _initialsAvatar(String initials) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : '?',
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }

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
                _avatar(
                  user.avatarUrl,
                  (user.firstName.isNotEmpty ? user.firstName[0] : '') +
                      (user.lastName.isNotEmpty ? user.lastName[0] : ''),
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
