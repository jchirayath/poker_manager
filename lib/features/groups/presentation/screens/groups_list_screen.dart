import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../providers/groups_provider.dart';
import '../../../../core/constants/route_constants.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

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
          url,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups'),
      ),
      body: groupsAsync.when(
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
                            debugPrint('🏢 Group: ${group.name} | Avatar: ${group.avatarUrl}');
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteConstants.createGroup),
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
      ),
    );
  }
}
