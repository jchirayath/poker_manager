import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/groups_provider.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Details'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/groups');
              }
            },
          ),
        ),
      ),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () {
                      context.push(
                        '/groups/${groupId}/edit',
                        extra: {
                          'name': group.name,
                          'description': group.description,
                          'privacy': group.privacy,
                          'currency': group.defaultCurrency,
                          'defaultBuyin': group.defaultBuyin,
                          'additionalBuyins': group.additionalBuyinValues,
                        },
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.group_add),
                    label: const Text('Members'),
                    onPressed: () {
                      context.push('/groups/${groupId}/members');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: group.avatarUrl != null
                      ? NetworkImage(group.avatarUrl!)
                      : null,
                  child: group.avatarUrl == null
                      ? Text(group.name[0].toUpperCase())
                      : null,
                ),
                title: Text(group.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                subtitle: Text('${group.defaultCurrency} ${group.defaultBuyin.toStringAsFixed(2)} buy-in'),
              ),
              const SizedBox(height: 16),
              const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              membersAsync.when(
                data: (members) {
                  if (members.isEmpty) {
                    return const Text('No members yet');
                  }
                  return Column(
                    children: members.map((m) {
                      final profile = m.profile;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profile?.avatarUrl != null
                              ? NetworkImage(profile!.avatarUrl!)
                              : null,
                          child: profile?.avatarUrl == null
                              ? Text(profile?.firstName.isNotEmpty == true
                                  ? profile!.firstName[0]
                                  : '?')
                              : null,
                        ),
                        title: Text(profile?.fullName ?? 'Unknown'),
                        subtitle: Text(m.role),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error loading members: $e'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
