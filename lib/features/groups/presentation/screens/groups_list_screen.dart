import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../data/models/group_model.dart';
import '../providers/groups_provider.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../common/widgets/app_drawer.dart';

class GroupsListScreen extends ConsumerStatefulWidget {
  const GroupsListScreen({super.key});

  @override
  ConsumerState<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends ConsumerState<GroupsListScreen>
    with SingleTickerProviderStateMixin {
  static final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Widget _buildUserAvatarAction(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => context.push(RouteConstants.profile),
          );
        }

        final initials = (user.firstName.isNotEmpty ? user.firstName[0] : '') +
            (user.lastName.isNotEmpty ? user.lastName[0] : '');
        final fallbackInitials = initials.isNotEmpty ? initials : '?';
        final avatarUrl = user.avatarUrl;

        Widget avatar;
        if ((avatarUrl ?? '').isEmpty) {
          avatar = CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              fallbackInitials,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          );
        } else if (avatarUrl!.toLowerCase().contains('svg')) {
          avatar = CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: ClipOval(
              child: SvgPicture.network(
                fixDiceBearUrl(avatarUrl)!,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => Text(
                  fallbackInitials,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          );
        } else {
          avatar = CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(avatarUrl),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => context.push(RouteConstants.profile),
            child: avatar,
          ),
        );
      },
      loading: () => const SizedBox(width: 40),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.account_circle),
        onPressed: () => context.push(RouteConstants.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myGroupsAsync = ref.watch(groupsListProvider);
    final publicGroupsAsync = ref.watch(publicGroupsProvider);
    final myGroupsCount = myGroupsAsync.asData?.value.length ?? 0;
    final publicGroupsCount = publicGroupsAsync.asData?.value.length ?? 0;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Groups'),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          _buildUserAvatarAction(context),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.groups),
              child: Text(
                'My Groups ($myGroupsCount)',
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Tab(
              icon: const Icon(Icons.public),
              child: Text(
                'Public ($publicGroupsCount)',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Groups Tab
          _GroupsListTab(
            groupsProvider: groupsListProvider,
            isPublic: false,
            buildGroupAvatar: _buildGroupAvatar,
            scrollController: _scrollController,
          ),
          // Public Groups Tab
          _GroupsListTab(
            groupsProvider: publicGroupsProvider,
            isPublic: true,
            buildGroupAvatar: _buildGroupAvatar,
            scrollController: ScrollController(),
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

class _GroupsListTab extends ConsumerWidget {
  final FutureProvider<List<GroupModel>> groupsProvider;
  final bool isPublic;
  final Widget Function(String?, String) buildGroupAvatar;
  final ScrollController scrollController;

  const _GroupsListTab({
    required this.groupsProvider,
    required this.isPublic,
    required this.buildGroupAvatar,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPublic ? Icons.public : Icons.group_outlined,
                  size: 100,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  isPublic ? 'No public groups' : 'No groups yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPublic
                      ? 'Public groups will appear here'
                      : 'Create your first poker group',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(groupsProvider.future),
          child: ListView.builder(
            controller: scrollController,
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
                      leading: buildGroupAvatar(group.avatarUrl, group.name),
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
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
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
              onPressed: () => ref.invalidate(groupsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

