import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/groups_repository.dart';
import '../../data/models/group_model.dart';
import '../../data/models/group_member_model.dart';
import '../../../../shared/models/result.dart';

final groupsRepositoryProvider = Provider((ref) => GroupsRepository());

final groupsListProvider = FutureProvider<List<GroupModel>>((ref) async {
  final repository = ref.watch(groupsRepositoryProvider);
  final result = await repository.getUserGroups();
  return result is Success<List<GroupModel>> ? result.data : [];
});

final publicGroupsProvider = FutureProvider<List<GroupModel>>((ref) async {
  final repository = ref.watch(groupsRepositoryProvider);
  final result = await repository.getPublicGroups();
  return result is Success<List<GroupModel>> ? result.data : [];
});

final groupProvider = FutureProvider.family<GroupModel?, String>((ref, groupId) async {
  final repository = ref.watch(groupsRepositoryProvider);
  final result = await repository.getGroup(groupId);
  return result is Success<GroupModel> ? result.data : null;
});

final groupMembersProvider =
    FutureProvider.family<List<GroupMemberModel>, String>((ref, groupId) async {
  final repository = ref.watch(groupsRepositoryProvider);
  final result = await repository.getGroupMembers(groupId);
  return result is Success<List<GroupMemberModel>> ? result.data : [];
});

final groupControllerProvider = Provider((ref) {
  return GroupController(ref.watch(groupsRepositoryProvider), ref);
});

class GroupController {
  final GroupsRepository _repository;
  final Ref _ref;

  GroupController(this._repository, this._ref);

  Future<Result<String>> createGroup({
    required String name,
    String? description,
    required String privacy,
    required String defaultCurrency,
    required double defaultBuyin,
    required List<double> additionalBuyinValues,
  }) async {
    final result = await _repository.createGroup(
      name: name,
      description: description,
      privacy: privacy,
      defaultCurrency: defaultCurrency,
      defaultBuyin: defaultBuyin,
      additionalBuyinValues: additionalBuyinValues,
    );

    if (result is Success<GroupModel>) {
      _ref.invalidate(groupsListProvider);
      return Success(result.data.id);
    }

    if (result is Failure<GroupModel>) {
      return Failure(result.message, exception: result.exception);
    }

    return const Failure('Unknown error creating group');
  }

  Future<bool> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? avatarUrl,
    String? privacy,
    String? defaultCurrency,
    double? defaultBuyin,
    List<double>? additionalBuyinValues,
  }) async {
    final result = await _repository.updateGroup(
      groupId: groupId,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      privacy: privacy,
      defaultCurrency: defaultCurrency,
      defaultBuyin: defaultBuyin,
      additionalBuyinValues: additionalBuyinValues,
    );

    if (result is Success) {
      _ref.invalidate(groupsListProvider);
      _ref.invalidate(groupProvider(groupId));
      return true;
    }
    return false;
  }

  Future<bool> deleteGroup(String groupId) async {
    final result = await _repository.deleteGroup(groupId);

    if (result is Success) {
      _ref.invalidate(groupsListProvider);
      return true;
    }
    return false;
  }

  Future<bool> addMember(String groupId, String userId) async {
    final result = await _repository.addMember(
      groupId: groupId,
      userId: userId,
    );

    if (result is Success) {
      _ref.invalidate(groupMembersProvider(groupId));
      return true;
    }
    return false;
  }

  Future<bool> removeMember(String groupId, String userId) async {
    final result = await _repository.removeMember(
      groupId: groupId,
      userId: userId,
    );

    if (result is Success) {
      _ref.invalidate(groupMembersProvider(groupId));
      return true;
    }
    return false;
  }

  Future<bool> updateMemberRole({
    required String groupId,
    required String userId,
    required String role,
  }) async {
    final result = await _repository.updateMemberRole(
      groupId: groupId,
      userId: userId,
      role: role,
    );

    if (result is Success) {
      _ref.invalidate(groupMembersProvider(groupId));
      return true;
    }
    return false;
  }

  Future<bool> isUserAdmin(String groupId, String userId) async {
    final result = await _repository.isUserAdmin(groupId, userId);
    return result is Success<bool> ? result.data : false;
  }
}
