import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../providers/groups_provider.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});
  static final ScrollController _scrollController = ScrollController();

  Widget _buildUserAvatar(String? url, String fallback) {
    final initials = fallback.isNotEmpty ? fallback : '?';
    if ((url ?? '').isEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade200,
        child: Text(
          initials,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }
    
    if (url!.toLowerCase().contains('svg')) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade200,
        child: SvgPicture.network(
          fixDiceBearUrl(url)!,
          width: 48,
          height: 48,
          placeholderBuilder: (_) => const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    
    return CircleAvatar(
      radius: 24,
      backgroundImage: NetworkImage(url),
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildGroupAvatar(String? url, String fallback) {
    final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : '?';
    if ((url ?? '').isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Text(letter),
      );
    }
    
    // Check contains 'svg' - handles DiceBear URLs like /svg?seed=...
    if (url!.toLowerCase().contains('svg')) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: SvgPicture.network(
          fixDiceBearUrl(url)!,
          width: 40,
          height: 40,
          placeholderBuilder: (_) => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    
    return CircleAvatar(
      backgroundImage: NetworkImage(url),
      child: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsListProvider);
    final authUserAsync = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('My Groups'),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_downward, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // User Profile Card at top
          authUserAsync.when(
            data: (user) {
              if (user == null) return const SizedBox.shrink();
              final displayName = user.firstName.isNotEmpty || user.lastName.isNotEmpty
                  ? user.fullName
                  : user.username ?? user.email.split('@').first;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _buildUserAvatar(user.avatarUrl, 
                      (user.firstName.isNotEmpty ? user.firstName[0] : '') +
                      (user.lastName.isNotEmpty ? user.lastName[0] : '')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'logged in user',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (user.username != null && user.username!.isNotEmpty)
                            Text(
                              '@${user.username}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person),
                      onPressed: () => context.push(RouteConstants.profile),
                      tooltip: 'View Profile',
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Groups list
          Expanded(
            child: groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 100,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No groups yet',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first poker group',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(groupsListProvider.future),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Consumer(
                          builder: (context, ref, _) {
                            final membersAsync = ref.watch(groupMembersProvider(group.id));
                            final subtitleText = membersAsync.when(
                              data: (members) => '${group.defaultCurrency} ${group.defaultBuyin.toStringAsFixed(2)} • ${members.length} member${members.length == 1 ? '' : 's'}',
                              loading: () => '${group.defaultCurrency} ${group.defaultBuyin.toStringAsFixed(2)} • loading...',
                              error: (e, _) => '${group.defaultCurrency} ${group.defaultBuyin.toStringAsFixed(2)}',
                            );
                            return ListTile(
                              leading: Builder(
                                builder: (context) {
                                  // Removed group debug info
                                  return _buildGroupAvatar(group.avatarUrl, group.name);
                                },
                              ),
                              title: Text(
                                group.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(subtitleText),
                                  if (group.description?.isNotEmpty == true) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      group.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                context.push(
                                  RouteConstants.groupDetail.replaceAll(':id', group.id),
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(groupsListProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteConstants.createGroup),
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
      ),
    );
  }
}
