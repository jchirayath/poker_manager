import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../common/widgets/app_drawer.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Widget _avatar(BuildContext context, String? url, String initials) {
    if ((url ?? '').isEmpty) {
      return _initialsAvatar(context, initials);
    }

    if (url!.toLowerCase().contains('svg')) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
        child: ClipOval(
          child: SvgPicture.network(
            fixDiceBearUrl(url)!,
            width: 100,
            height: 100,
            placeholderBuilder: (_) => const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 3,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          url,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, stackTrace) {
            return _initialsAvatar(context, initials);
          },
          loadingBuilder: (ctx, child, loadingProgress) {
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
      ),
    );
  }

  Widget _initialsAvatar(BuildContext context, String initials) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 3,
        ),
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : '?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUserAsync = ref.watch(authStateProvider);
    final canPop = Navigator.of(context).canPop();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      drawer: canPop ? null : const AppDrawer(),
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => context.push(RouteConstants.editProfile),
          ),
        ],
      ),
      body: authUserAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not signed in'));
          }

          final initials = (user.firstName.isNotEmpty ? user.firstName[0] : '') +
              (user.lastName.isNotEmpty ? user.lastName[0] : '');

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header section with gradient background
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.primaryContainer.withValues(alpha: 0.3),
                        colorScheme.surface,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _avatar(context, user.avatarUrl, initials),
                      const SizedBox(height: 16),
                      Text(
                        user.firstName.isNotEmpty || user.lastName.isNotEmpty
                            ? user.fullName
                            : 'User',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user.username != null && user.username!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '@${user.username}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Content section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Contact Information Card
                      _buildSectionCard(
                        context: context,
                        icon: Icons.contact_mail_outlined,
                        title: 'Contact Information',
                        children: [
                          _buildInfoTile(
                            context: context,
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: user.email,
                          ),
                          if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                            _buildInfoTile(
                              context: context,
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: user.phoneNumber!,
                            ),
                        ],
                      ),

                      // Address Card
                      if (user.hasAddress) ...[
                        const SizedBox(height: 12),
                        _buildSectionCard(
                          context: context,
                          icon: Icons.location_on_outlined,
                          title: 'Address',
                          children: [
                            _buildInfoTile(
                              context: context,
                              icon: Icons.home_outlined,
                              label: 'Location',
                              value: user.fullAddress,
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Sign Out Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Sign Out'),
                                content: const Text('Are you sure you want to sign out?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Sign Out'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true && context.mounted) {
                              final controller = ref.read(authControllerProvider);
                              await controller.signOut();
                              if (context.mounted) {
                                context.go(RouteConstants.signIn);
                              }
                            }
                          },
                          icon: Icon(Icons.logout, color: colorScheme.error),
                          label: Text(
                            'Sign Out',
                            style: TextStyle(color: colorScheme.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
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
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
