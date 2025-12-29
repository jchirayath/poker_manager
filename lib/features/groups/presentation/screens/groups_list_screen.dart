import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/groups_provider.dart';
import '../../../../core/constants/route_constants.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

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
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: group.avatarUrl != null
                          ? NetworkImage(group.avatarUrl!)
                          : null,
                      child: group.avatarUrl == null
                          ? Text(group.name[0].toUpperCase())
                          : null,
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${group.defaultCurrency} ${group.defaultBuyin.toStringAsFixed(2)} buy-in',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push(
                        RouteConstants.groupDetail.replaceAll(':id', group.id),
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
