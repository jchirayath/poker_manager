import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../../shared/models/result.dart';
import 'games_list_screen.dart';

class GamesGroupSelectorScreen extends ConsumerWidget {
  const GamesGroupSelectorScreen({super.key});

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

  Future<String> _getCreatorName(String createdBy) async {
    try {
      final repository = ProfileRepository();
      final result = await repository.getProfile(createdBy);
      if (result is Success<dynamic>) {
        return (result as Success).data.fullName;
      }
    } catch (e) {
      // Fallback to ID if profile fetch fails
    }
    return createdBy;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Group'),
        centerTitle: true,
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
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
                    'Create a group to get started',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: groups.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: _buildGroupAvatar(group.avatarUrl, group.name),
                  title: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${group.defaultCurrency} ${group.defaultBuyin.toStringAsFixed(2)}'),
                      if (group.description != null && group.description!.isNotEmpty) ...[
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
                    // Navigate to games list for this group
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            GamesListScreen(groupId: group.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
