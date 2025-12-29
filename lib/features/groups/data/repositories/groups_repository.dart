import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/result.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';

class GroupsRepository {
  final SupabaseClient _client = SupabaseService.instance;

  Future<Result<List<GroupModel>>> getUserGroups() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        return const Result.failure('User not authenticated');
      }

      // Join with group_members to filter by membership
      final response = await _client
          .from('groups')
          .select('*, group_members!inner(user_id)')
          .eq('group_members.user_id', userId);

      final groups = (response as List)
          .map((json) => GroupModel.fromJson(json))
          .toList();

      return Result.success(groups);
    } catch (e) {
      return Result.failure('Failed to load groups: ${e.toString()}');
    }
  }

  Future<Result<GroupModel>> getGroup(String groupId) async {
    try {
      final response = await _client
          .from('groups')
          .select()
          .eq('id', groupId)
          .maybeSingle();

      if (response == null) {
        return const Result.failure('Group not found');
      }

      return Result.success(GroupModel.fromJson(response));
    } catch (e) {
      return Result.failure('Failed to load group: ${e.toString()}');
    }
  }

  Future<Result<GroupModel>> createGroup({
    required String name,
    String? description,
    required String privacy,
    required String defaultCurrency,
    required double defaultBuyin,
    required List<double> additionalBuyinValues,
  }) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        return const Result.failure('User not authenticated');
      }

      // Create group
      final groupResponse = await _client
          .from('groups')
          .insert({
            'name': name,
            'description': description,
            'created_by': userId,
            'privacy': privacy,
            'default_currency': defaultCurrency,
            'default_buyin': defaultBuyin,
            'additional_buyin_values': additionalBuyinValues,
          })
          .select()
          .single();

      final group = GroupModel.fromJson(groupResponse);

      // Add creator as admin member (allowed by RLS via creator policy)
      await _client.from('group_members').insert({
        'group_id': group.id,
        'user_id': userId,
        'role': 'admin',
        'is_creator': true,
      });

      return Result.success(group);
    } catch (e) {
      return Result.failure('Failed to create group: ${e.toString()}');
    }
  }

  Future<Result<GroupModel>> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? privacy,
    String? defaultCurrency,
    double? defaultBuyin,
    List<double>? additionalBuyinValues,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (privacy != null) updates['privacy'] = privacy;
      if (defaultCurrency != null) updates['default_currency'] = defaultCurrency;
      if (defaultBuyin != null) updates['default_buyin'] = defaultBuyin;
      if (additionalBuyinValues != null) {
        updates['additional_buyin_values'] = additionalBuyinValues;
      }

      final response = await _client
          .from('groups')
          .update(updates)
          .eq('id', groupId)
          .select()
          .single();

      return Result.success(GroupModel.fromJson(response));
    } catch (e) {
      return Result.failure('Failed to update group: ${e.toString()}');
    }
  }

  Future<Result<void>> deleteGroup(String groupId) async {
    try {
      await _client.from('groups').delete().eq('id', groupId);
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Failed to delete group: ${e.toString()}');
    }
  }

  // Group Members
  Future<Result<List<GroupMemberModel>>> getGroupMembers(String groupId) async {
    try {
      final response = await _client
          .from('group_members')
          .select('*, profile:profiles(*)')
          .eq('group_id', groupId);

      final members = (response as List)
          .map((json) => GroupMemberModel.fromJson(json))
          .toList();

      return Result.success(members);
    } catch (e) {
      return Result.failure('Failed to load members: ${e.toString()}');
    }
  }

  Future<Result<void>> addMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _client.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role': 'member',
        'is_creator': false,
      });

      return const Result.success(null);
    } catch (e) {
      return Result.failure('Failed to add member: ${e.toString()}');
    }
  }

  Future<Result<void>> removeMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);

      return const Result.success(null);
    } catch (e) {
      return Result.failure('Failed to remove member: ${e.toString()}');
    }
  }

  Future<Result<void>> updateMemberRole({
    required String groupId,
    required String userId,
    required String role,
  }) async {
    try {
      await _client
          .from('group_members')
          .update({'role': role})
          .eq('group_id', groupId)
          .eq('user_id', userId);

      return const Result.success(null);
    } catch (e) {
      return Result.failure('Failed to update member role: ${e.toString()}');
    }
  }

  Future<Result<bool>> isUserAdmin(String groupId, String userId) async {
    try {
      final response = await _client
          .from('group_members')
          .select('role')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return const Result.success(false);
      }

      return Result.success(response['role'] == 'admin');
    } catch (e) {
      return Result.failure('Failed to check admin status: ${e.toString()}');
    }
  }
}
