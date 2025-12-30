import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';

void main() {
  group('Setup Dummy Data for Testing', () {
    late SupabaseClient client;
    late String supabaseUrl;
    late String supabaseServiceKey;
    final uuid = Uuid();

    setUpAll(() async {
      // Load environment from env.json
      final envFile = File('env.json');
      if (!envFile.existsSync()) {
        throw Exception('env.json file not found. Please create it with SUPABASE_URL and SUPABASE_SERVICE_KEY');
      }

      final envJson = jsonDecode(envFile.readAsStringSync()) as Map<String, dynamic>;
      supabaseUrl = envJson['SUPABASE_URL'] as String? ?? '';
      supabaseServiceKey = envJson['SUPABASE_SERVICE_KEY'] as String? ?? '';

      if (supabaseUrl.isEmpty || supabaseServiceKey.isEmpty) {
        throw Exception('SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in env.json');
      }

      // Initialize Supabase with service role key (for admin operations)
      client = SupabaseClient(supabaseUrl, supabaseServiceKey);
    });

    test('Create 10 dummy users and 2 groups with games', () async {
      print('\n🚀 Starting dummy data setup...\n');

      // Step 1: Create 10 dummy users
      print('📝 Creating 10 dummy users...');
      final userIds = <String>[];

      for (int i = 1; i <= 10; i++) {
        try {
          // Generate proper UUID
          final userId = uuid.v4();
          final email = 'user$i@dummy.test';
          final password = 'TestPassword123!';
          
          // Use Supabase Admin API to create user
          final response = await client.auth.admin.createUser(
            AdminUserAttributes(
              email: email,
              password: password,
              emailConfirm: true,
              userMetadata: {
                'username': 'dummy_user_$i',
                'first_name': 'Dummy',
                'last_name': 'User $i',
              },
            ),
          );
          
          final createdUserId = response.user?.id ?? userId;
          
          // Update profile with additional info
          await client.from('profiles').upsert({
            'id': createdUserId,
            'email': email,
            'username': 'dummy_user_$i',
            'first_name': 'Dummy',
            'last_name': 'User $i',
            'country': 'United States',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          userIds.add(createdUserId);
          print('  ✓ Created user $i: $email (ID: $createdUserId)');
        } catch (e) {
          print('  ✗ Failed to create user $i: $e');
          rethrow;
        }
      }

      expect(userIds.length, 10, reason: 'Should have created 10 users');
      print('\n✅ Successfully created 10 dummy users\n');

      // Step 2: Create 2 groups
      print('👥 Creating 2 groups...');
      final groupIds = <String>[];

      final group1Id = uuid.v4();
      final group2Id = uuid.v4();

      try {
        // Group 1
        await client.from('groups').insert({
          'id': group1Id,
          'name': 'Test Poker Group 1',
          'description': 'First test group for poker games',
          'created_by': userIds[0],
          'privacy': 'private',
          'default_currency': 'USD',
          'default_buyin': 100.0,
          'additional_buyin_values': [50.0],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Add creator as admin member
        await client.from('group_members').insert({
          'group_id': group1Id,
          'user_id': userIds[0],
          'role': 'admin',
          'is_creator': true,
        });

        // Add other users to group 1
        for (int i = 1; i < 6; i++) {
          await client.from('group_members').insert({
            'group_id': group1Id,
            'user_id': userIds[i],
            'role': 'member',
            'is_creator': false,
          });
        }

        groupIds.add(group1Id);
        print('  ✓ Created Group 1 with 6 members');

        // Group 2
        await client.from('groups').insert({
          'id': group2Id,
          'name': 'Test Poker Group 2',
          'description': 'Second test group for poker games',
          'created_by': userIds[5],
          'privacy': 'public',
          'default_currency': 'USD',
          'default_buyin': 50.0,
          'additional_buyin_values': [25.0],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Add creator as admin member
        await client.from('group_members').insert({
          'group_id': group2Id,
          'user_id': userIds[5],
          'role': 'admin',
          'is_creator': true,
        });

        // Add other users to group 2
        for (int i = 6; i < 10; i++) {
          await client.from('group_members').insert({
            'group_id': group2Id,
            'user_id': userIds[i],
            'role': 'member',
            'is_creator': false,
          });
        }

        groupIds.add(group2Id);
        print('  ✓ Created Group 2 with 5 members');
      } catch (e) {
        print('  ✗ Failed to create groups: $e');
        rethrow;
      }

      expect(groupIds.length, 2, reason: 'Should have created 2 groups');
      print('\n✅ Successfully created 2 groups\n');

      // Step 3: Create games in each group
      print('🎮 Creating games in groups...');

      try {
        // Game 1 in Group 1
        final game1Id = uuid.v4();
        await client.from('games').insert({
          'id': game1Id,
          'group_id': group1Id,
          'name': 'Game 1 - Group 1',
          'game_date': DateTime.now().toIso8601String(),
          'location': 'Home',
          'location_host_user_id': userIds[0],
          'max_players': 6,
          'currency': 'USD',
          'buyin_amount': 100.0,
          'additional_buyin_values': [50.0],
          'status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Add game participants for Game 1
        for (int i = 0; i < 5; i++) {
          final participantId = uuid.v4();
          await client.from('game_participants').insert({
            'id': participantId,
            'game_id': game1Id,
            'user_id': userIds[i],
            'rsvp_status': 'going',
            'total_buyin': i == 0 ? 200.0 : 100.0,
            'total_cashout': i == 0 ? 350.0 : 75.0,
            'created_at': DateTime.now().toIso8601String(),
          });

          // Add transactions
          await client.from('transactions').insert({
            'game_id': game1Id,
            'user_id': userIds[i],
            'type': 'buyin',
            'amount': i == 0 ? 200.0 : 100.0,
            'timestamp': DateTime.now().toIso8601String(),
            'notes': 'Initial buy-in',
          });

          await client.from('transactions').insert({
            'game_id': game1Id,
            'user_id': userIds[i],
            'type': 'cashout',
            'amount': i == 0 ? 350.0 : 75.0,
            'timestamp': DateTime.now().add(Duration(hours: 2)).toIso8601String(),
            'notes': 'Cash out',
          });
        }

        print('  ✓ Created Game 1 in Group 1 with 5 participants and transactions');

        // Game 2 in Group 2
        final game2Id = uuid.v4();
        await client.from('games').insert({
          'id': game2Id,
          'group_id': group2Id,
          'name': 'Game 2 - Group 2',
          'game_date': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
          'location': 'Casino',
          'location_host_user_id': userIds[5],
          'max_players': 8,
          'currency': 'USD',
          'buyin_amount': 50.0,
          'additional_buyin_values': [25.0],
          'status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Add game participants for Game 2
        for (int i = 5; i < 10; i++) {
          final participantId = uuid.v4();
          await client.from('game_participants').insert({
            'id': participantId,
            'game_id': game2Id,
            'user_id': userIds[i],
            'rsvp_status': 'going',
            'total_buyin': 50.0,
            'total_cashout': i % 2 == 0 ? 120.0 : 20.0,
            'created_at': DateTime.now().toIso8601String(),
          });

          // Add transactions
          await client.from('transactions').insert({
            'game_id': game2Id,
            'user_id': userIds[i],
            'type': 'buyin',
            'amount': 50.0,
            'timestamp': DateTime.now().toIso8601String(),
            'notes': 'Buy-in',
          });

          await client.from('transactions').insert({
            'game_id': game2Id,
            'user_id': userIds[i],
            'type': 'cashout',
            'amount': i % 2 == 0 ? 120.0 : 20.0,
            'timestamp': DateTime.now().add(Duration(hours: 3)).toIso8601String(),
            'notes': 'Cash out',
          });
        }

        print('  ✓ Created Game 2 in Group 2 with 5 participants and transactions');
      } catch (e) {
        print('  ✗ Failed to create games: $e');
        rethrow;
      }

      print('\n✅ Successfully created 2 games with participants and transactions\n');

      // Summary
      print('📊 Summary:');
      print('   • Users created: ${userIds.length}');
      print('   • Groups created: ${groupIds.length}');
      print('   • Games created: 2');
      print('   • Total transactions: 20');
      print('\n✨ Dummy data setup completed successfully!\n');
    });
  });
}
