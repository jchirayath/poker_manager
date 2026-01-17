import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../../shared/models/result.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';

class GroupsRepository {
  final SupabaseClient _client = SupabaseService.instance;

  // Expose client for storage operations
  SupabaseClient get client => _client;

  Future<Result<List<GroupModel>>> getUserGroups() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) {
        return const Failure('User not authenticated');
      }

      // Query all groups where user is a member (RLS allows via group_members table)
      // This single query handles both creators and regular members
      final response = await _client
          .from('group_members')
          .select('groups(*)')
          .eq('user_id', userId);

      final groups = (response as List)
          .map((json) {
            final groupData = json['groups'] as Map<String, dynamic>;
            // Fix DiceBear URLs to exclude metadata tags
            if (groupData['avatar_url'] != null) {
              final original = groupData['avatar_url'];
              groupData['avatar_url'] = fixDiceBearUrl(groupData['avatar_url']);
              // Removed group avatar URL fixed debug
            }
            return GroupModel.fromJson(groupData);
          })
          .toList();

      return Success(groups);
    } catch (e) {
      return Failure('Failed to load groups: ${e.toString()}');
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
        return const Failure('Group not found');
      }

      // Fix DiceBear URLs to exclude metadata tags
      if (response['avatar_url'] != null) {
        response['avatar_url'] = fixDiceBearUrl(response['avatar_url']);
      }
      return Success(GroupModel.fromJson(response));
    } catch (e) {
      return Failure('Failed to load group: ${e.toString()}');
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
        return const Failure('User not authenticated');
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

      // Fix DiceBear URLs to exclude metadata tags
      if (groupResponse['avatar_url'] != null) {
        groupResponse['avatar_url'] = fixDiceBearUrl(groupResponse['avatar_url']);
      }
      final group = GroupModel.fromJson(groupResponse);

      // Add creator as admin member (allowed by RLS via creator policy)
      await _client.from('group_members').insert({
        'group_id': group.id,
        'user_id': userId,
        'role': 'admin',
        'is_creator': true,
      });

      return Success(group);
    } catch (e) {
      return Failure('Failed to create group: ${e.toString()}');
    }
  }

  Future<Result<GroupModel>> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? avatarUrl,
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
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
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

      // Fix DiceBear URLs to exclude metadata tags
      if (response['avatar_url'] != null) {
        response['avatar_url'] = fixDiceBearUrl(response['avatar_url']);
      }
      return Success(GroupModel.fromJson(response));
    } catch (e) {
      return Failure('Failed to update group: ${e.toString()}');
    }
  }

  Future<Result<void>> deleteGroup(String groupId) async {
    try {
      // First verify the group exists and user has permission
      final checkResponse = await _client
          .from('groups')
          .select('id, created_by')
          .eq('id', groupId)
          .maybeSingle();

      if (checkResponse == null) {
        return const Failure('Group not found or you do not have permission to delete it');
      }

      // Perform the delete
      await _client.from('groups').delete().eq('id', groupId);

      // Verify deletion was successful
      final verifyResponse = await _client
          .from('groups')
          .select('id')
          .eq('id', groupId)
          .maybeSingle();

      if (verifyResponse != null) {
        return const Failure('Group was not deleted. You may not have permission to delete this group.');
      }

      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete group: ${e.toString()}');
    }
  }

  // Group Members
  Future<Result<List<GroupMemberModel>>> getGroupMembers(String groupId) async {
    try {
      final response = await _client
          .from('group_members')
          .select('*, profiles!user_id(*)')
          .eq('group_id', groupId);

      final members = (response as List)
          .map((json) {
            // Remap nested profile relation to the expected single profile object
            final profiles = json['profiles'];
            if (profiles is List && profiles.isNotEmpty) {
              json['profile'] = profiles.first;
              json.remove('profiles');
            } else if (profiles is Map<String, dynamic>) {
              json['profile'] = profiles;
              json.remove('profiles');
            }
            return GroupMemberModel.fromJson(json);
          })
          .toList();

      return Success(members);
    } catch (e) {
      return Failure('Failed to load members: ${e.toString()}');
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

      return const Success(null);
    } catch (e) {
      return Failure('Failed to add member: ${e.toString()}');
    }
  }

  Future<Result<void>> removeMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      // First, verify the member exists
      final checkResponse = await _client
          .from('group_members')
          .select('id')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();

      if (checkResponse == null) {
        return const Success(null);
      }

      // Perform the delete with select to get affected rows
      final response = await _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .select();

      if (response == null || (response as List).isEmpty) {
        return const Failure('Delete blocked by database policy');
      }

      return const Success(null);
    } catch (e) {
      return Failure('Failed to remove member: ${e.toString()}');
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

      return const Success(null);
    } catch (e) {
      return Failure('Failed to update member role: ${e.toString()}');
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
        return const Success(false);
      }

      return Success(response['role'] == 'admin');
    } catch (e) {
      return Failure('Failed to check admin status: ${e.toString()}');
    }
  }

  /// Fetch all public groups (privacy = 'public')
  Future<Result<List<GroupModel>>> getPublicGroups() async {
    try {
      debugPrint('[GroupsRepository] Fetching all public groups');
      debugPrint('[GroupsRepository] Current user ID: ${SupabaseService.currentUserId}');

      final response = await _client
          .from('groups')
          .select()
          .eq('privacy', 'public')
          .order('created_at', ascending: false);

      debugPrint('[GroupsRepository] getPublicGroups response: $response');

      final groups = (response as List).map((json) {
        // Fix DiceBear URLs to exclude metadata tags
        if (json['avatar_url'] != null) {
          json['avatar_url'] = fixDiceBearUrl(json['avatar_url']);
        }
        return GroupModel.fromJson(json);
      }).toList();

      debugPrint('[GroupsRepository] Loaded ${groups.length} public groups (non-paginated)');
      return Success(groups);
    } catch (e) {
      debugPrint('[GroupsRepository] Error loading public groups: $e');
      return Failure('Failed to load public groups: ${e.toString()}');
    }
  }

  /// Fetch public groups with pagination
  Future<Result<List<GroupModel>>> getPublicGroupsPaginated({
    required int page,
    required int pageSize,
  }) async {
    try {
      final offset = (page - 1) * pageSize;
      debugPrint('[GroupsRepository] Fetching public groups: page=$page, pageSize=$pageSize, offset=$offset');
      debugPrint('[GroupsRepository] Current user ID: ${SupabaseService.currentUserId}');

      final response = await _client
          .from('groups')
          .select()
          .eq('privacy', 'public')
          .order('created_at', ascending: false)
          .range(offset, offset + pageSize - 1);

      debugPrint('[GroupsRepository] Response: $response');

      final groups = (response as List).map((json) {
        if (json['avatar_url'] != null) {
          json['avatar_url'] = fixDiceBearUrl(json['avatar_url']);
        }
        return GroupModel.fromJson(json);
      }).toList();

      debugPrint('[GroupsRepository] Loaded ${groups.length} public groups');
      return Success(groups);
    } catch (e) {
      debugPrint('[GroupsRepository] Error loading public groups: $e');
      return Failure('Failed to load public groups: ${e.toString()}');
    }
  }
}
