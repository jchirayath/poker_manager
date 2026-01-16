// ignore_for_file: avoid_print
//
// Database Setup Test - Clear data and/or insert dummy data
//
// Usage (environment variables control behavior):
//
//   # Clear all data only:
//   CLEAR_DATA=true INSERT_DATA=false flutter test test/setup_dummy_data_test.dart
//   # Or using legacy variable:
//   CLEAR_DUMMY_DATA=true INSERT_DATA=false flutter test test/setup_dummy_data_test.dart
//
//   # Insert dummy data only (without clearing first):
//   INSERT_DATA=true flutter test test/setup_dummy_data_test.dart
//
//   # Clear all data AND insert dummy data (default):
//   flutter test test/setup_dummy_data_test.dart
//
//   # Or explicitly:
//   CLEAR_DATA=true INSERT_DATA=true flutter test test/setup_dummy_data_test.dart
//

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Check if an environment variable is set to 'true'
bool _envBool(String name) {
  final value = Platform.environment[name]?.toLowerCase();
  return value == 'true' || value == '1' || value == 'yes';
}

/// Check if an environment variable is explicitly set to 'false'
bool _envExplicitlyFalse(String name) {
  final value = Platform.environment[name]?.toLowerCase();
  return value == 'false' || value == '0' || value == 'no';
}

/// Get operation mode from environment variables
/// Returns (shouldClear, shouldInsert)
(bool, bool) _getOperationMode() {
  // Support both old (CLEAR_DUMMY_DATA) and new (CLEAR_DATA) variable names
  final clearData = _envBool('CLEAR_DATA') || _envBool('CLEAR_DUMMY_DATA');
  final insertData = _envBool('INSERT_DATA');

  // Check if INSERT_DATA is explicitly set to false
  final insertExplicitlyFalse = _envExplicitlyFalse('INSERT_DATA');

  // If clear is requested but insert is explicitly false, only clear
  if (clearData && insertExplicitlyFalse) {
    return (true, false);
  }

  // If clear is requested (and insert not explicitly false), do both for backwards compatibility
  if (clearData && !insertData) {
    return (true, true);
  }

  // If only insert is requested
  if (insertData && !clearData) {
    return (false, true);
  }

  // If both are explicitly set
  if (clearData && insertData) {
    return (true, true);
  }

  // Default: do both
  return (true, true);
}

void main() {
  group('Setup Dummy Data for Testing', () {
    late SupabaseClient client;
    late String supabaseUrl;
    late String supabaseServiceKey;
    const uuid = Uuid();

    setUpAll(() async {
      // Load environment from env.json
      final envFile = File('env.json');
      if (!envFile.existsSync()) {
        throw Exception('env.json file not found. Please create it with SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
      }

      final envJson = jsonDecode(envFile.readAsStringSync()) as Map<String, dynamic>;
      supabaseUrl = envJson['SUPABASE_URL'] as String? ?? '';
      supabaseServiceKey = envJson['SUPABASE_SERVICE_ROLE_KEY'] as String? ?? '';

      if (supabaseUrl.isEmpty || supabaseServiceKey.isEmpty) {
        throw Exception('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in env.json');
      }

      // Initialize Supabase with service role key (for admin operations)
      client = SupabaseClient(supabaseUrl, supabaseServiceKey);
    });

    test('Reset, seed, and validate dummy data', () async {
      // Get operation mode from environment variables
      final (shouldClear, shouldInsert) = _getOperationMode();

      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║           DATABASE SETUP TEST                              ║');
      print('╠════════════════════════════════════════════════════════════╣');
      print('║  CLEAR_DATA:  ${shouldClear ? '✓ YES' : '✗ NO '}                                        ║');
      print('║  INSERT_DATA: ${shouldInsert ? '✓ YES' : '✗ NO '}                                        ║');
      print('╚════════════════════════════════════════════════════════════╝\n');

      const defaultPassword = 'TestPassword123!';

      Future<void> clearExistingData() async {
        print('🧹 Clearing existing data...\n');


        Future<void> deleteAll(String table, {bool skipIdCheck = false}) async {
          if (skipIdCheck) {
            // PostgREST requires a WHERE clause for DELETE; use a filter that matches all rows
            // Try 'id' column first, fallback to 'created_at' if 'id' does not exist
            try {
              await client.from(table).delete().neq('id', '00000000-0000-0000-0000-000000000000');
            } catch (_) {
              await client.from(table).delete().neq('created_at', '');
            }
          } else {
            await client.from(table).delete().neq('id', '00000000-0000-0000-0000-000000000000');
          }
          print('  ✓ Cleared $table');
        }

        await deleteAll('transactions');
        await deleteAll('settlements');
        await deleteAll('game_participants');
        await deleteAll('games');
        await deleteAll('player_statistics');
        await deleteAll('group_members');
        await deleteAll('locations');
        await deleteAll('groups');
        await deleteAll('profiles');
        await deleteAll('financial_audit_log', skipIdCheck: true); // No id column constraint

        final existingUsers = await client.auth.admin.listUsers();
        for (final user in existingUsers) {
          final email = user.email ?? '';
          try {
            await client.auth.admin.deleteUser(user.id);
            print('  ✓ Removed auth user $email');
          } catch (e) {
            print('  ⚠️ Failed to delete auth user $email: $e');
          }
        }

        print('\n✅ Database cleared successfully!\n');
      }

      // Clear data if requested
      if (shouldClear) {
        await clearExistingData();
      }

      // Exit early if only clearing
      if (!shouldInsert) {
        print('ℹ️  INSERT_DATA not set. Skipping dummy data insertion.\n');
        return;
      }

      print('🚀 Starting dummy data insertion...\n');

      final now = DateTime.now();
      final nowIso = now.toIso8601String();

      final dummyUsers = <Map<String, String>>[
        {
          'email': 'avery.nguyen@dummy.test',
          'first': 'Avery',
          'last': 'Nguyen',
          'username': 'avery.nguyen',
          'street': '101 River Walk',
          'city': 'Austin',
          'state': 'TX',
          'postal': '78701',
          'country': 'United States',
        },
        {
          'email': 'bella.martinez@dummy.test',
          'first': 'Bella',
          'last': 'Martinez',
          'username': 'bella.martinez',
          'street': '245 Cedar Trail',
          'city': 'Denver',
          'state': 'CO',
          'postal': '80203',
          'country': 'United States',
        },
        {
          'email': 'cam.johnson@dummy.test',
          'first': 'Cam',
          'last': 'Johnson',
          'username': 'cam.johnson',
          'street': '77 Orchard Lane',
          'city': 'Chicago',
          'state': 'IL',
          'postal': '60610',
          'country': 'United States',
        },
        {
          'email': 'dylan.cho@dummy.test',
          'first': 'Dylan',
          'last': 'Cho',
          'username': 'dylan.cho',
          'street': '980 Hillcrest Blvd',
          'city': 'Los Angeles',
          'state': 'CA',
          'postal': '90027',
          'country': 'United States',
        },
        {
          'email': 'ella.wright@dummy.test',
          'first': 'Ella',
          'last': 'Wright',
          'username': 'ella.wright',
          'street': '15 Harbor View Dr',
          'city': 'Seattle',
          'state': 'WA',
          'postal': '98101',
          'country': 'United States',
        },
        {
          'email': 'finley.patel@dummy.test',
          'first': 'Finley',
          'last': 'Patel',
          'username': 'finley.patel',
          'street': '300 Brookstone Ave',
          'city': 'Phoenix',
          'state': 'AZ',
          'postal': '85004',
          'country': 'United States',
        },
        {
          'email': 'gia.ross@dummy.test',
          'first': 'Gia',
          'last': 'Ross',
          'username': 'gia.ross',
          'street': '612 Meadow Ridge Rd',
          'city': 'Nashville',
          'state': 'TN',
          'postal': '37203',
          'country': 'United States',
        },
        {
          'email': 'henry.lee@dummy.test',
          'first': 'Henry',
          'last': 'Lee',
          'username': 'henry.lee',
          'street': '54 Pine Street',
          'city': 'Boston',
          'state': 'MA',
          'postal': '02110',
          'country': 'United States',
        },
        {
          'email': 'iris.khan@dummy.test',
          'first': 'Iris',
          'last': 'Khan',
          'username': 'iris.khan',
          'street': '890 Elmwood Pl',
          'city': 'Columbus',
          'state': 'OH',
          'postal': '43215',
          'country': 'United States',
        },
        {
          'email': 'jax.ramirez@dummy.test',
          'first': 'Jax',
          'last': 'Ramirez',
          'username': 'jax.ramirez',
          'street': '442 Maple Bend',
          'city': 'Miami',
          'state': 'FL',
          'postal': '33130',
          'country': 'United States',
        },
      ];

      final userIds = <String>[];
      final locationIds = <String>[];
      final userNames = <String>[];
      final existingUsers = await client.auth.admin.listUsers();

      String? adminUserId;

      for (final user in dummyUsers) {
        final email = user['email']!;
        final firstName = user['first']!;
        final lastName = user['last']!;
        final username = user['username']!;
        final street = user['street']!;
        final city = user['city']!;
        final state = user['state']!;
        final postal = user['postal']!;
        final country = user['country']!;

        try {
          String userId;

          final existing = existingUsers.where((u) => u.email == email).toList();

          if (existing.isNotEmpty) {
            userId = existing.first.id;
            print('  ℹ Using existing user $firstName $lastName ($email)');
          } else {
            try {
              final response = await client.auth.admin.createUser(
                AdminUserAttributes(
                  email: email,
                  password: defaultPassword,
                  emailConfirm: true,
                  userMetadata: {
                    'username': username,
                    'first_name': firstName,
                    'last_name': lastName,
                    'country': country,
                  },
                ),
              );
              userId = response.user?.id ?? uuid.v4();
              print('  ✓ Seeded $firstName $lastName ($email)');
            } on AuthApiException catch (e) {
              if (e.code == 'email_exists') {
                final refreshedUsers = await client.auth.admin.listUsers();
                final refreshed = refreshedUsers.where((u) => u.email == email).toList();
                if (refreshed.isEmpty) {
                  rethrow;
                }
                userId = refreshed.first.id;
                print('  ℹ Using existing user after conflict $firstName $lastName ($email)');
              } else {
                rethrow;
              }
            }
          }

          userIds.add(userId);
          userNames.add('$firstName $lastName');

          // Wait a moment for trigger to complete
          await Future.delayed(const Duration(milliseconds: 100));

          // Check if profile was created by trigger
          final existingProfile = await client
              .from('profiles')
              .select('id')
              .eq('id', userId)
              .maybeSingle();

          final avatarUrl = 'https://api.dicebear.com/7.x/avataaars/svg?seed=$email&excludeMetadata=true';
          if (existingProfile == null) {
            // Profile wasn't created by trigger, create it directly
            try {
              await client.from('profiles').insert({
                'id': userId,
                'email': email,
                'username': username,
                'first_name': firstName,
                'last_name': lastName,
                'avatar_url': avatarUrl,
                'street_address': street,
                'city': city,
                'state_province': state,
                'postal_code': postal,
                'country': country,
                'created_at': nowIso,
                'updated_at': nowIso,
              });
            } catch (e) {
              print('    ⚠️  Failed to create profile: $e');
              rethrow;
            }
          } else {
            // Profile exists, just update the additional fields
            try {
              await client.from('profiles').update({
                'avatar_url': avatarUrl,
                'street_address': street,
                'city': city,
                'state_province': state,
                'postal_code': postal,
                'country': country,
                'updated_at': nowIso,
              }).eq('id', userId);
            } catch (e) {
              print('    ⚠️  Failed to update profile: $e');
            }
          }

          final locationId = uuid.v4();
          try {
            await client.from('locations').insert({
              'id': locationId,
              'group_id': null,
              'profile_id': userId,
              'street_address': street,
              'city': city,
              'state_province': state,
              'postal_code': postal,
              'country': country,
              'label': '$firstName $lastName Home',
              'is_primary': true,
              'created_by': userId,
              'created_at': nowIso,
              'updated_at': nowIso,
            });
            locationIds.add(locationId);
          } catch (e) {
            print('    ⚠️  Location insert failed: $e');
          }
        } catch (e) {
          print('  ✗ Failed to create user $email: $e');
          rethrow;
        }
      }

      // Create or reuse admin user with broad group access
      const adminEmail = 'jacobc@aspl.net';
      const adminFirst = 'Jacob';
      const adminLast = 'C';
      const adminUsername = 'jacob.admin';

      try {
        final existingAdmin = existingUsers.where((u) => u.email == adminEmail).toList();
        if (existingAdmin.isNotEmpty) {
          adminUserId = existingAdmin.first.id;
          print('  ℹ Using existing admin user $adminFirst $adminLast ($adminEmail)');
        } else {
          final response = await client.auth.admin.createUser(
            AdminUserAttributes(
              email: adminEmail,
              password: defaultPassword,
              emailConfirm: true,
              userMetadata: {
                'username': adminUsername,
                'first_name': adminFirst,
                'last_name': adminLast,
                'country': 'United States',
              },
            ),
          );
          adminUserId = response.user?.id ?? uuid.v4();
          print('  ✓ Seeded admin user $adminFirst $adminLast ($adminEmail)');
        }

        if (adminUserId == null) {
          throw Exception('Admin user id missing');
        }

        userIds.add(adminUserId!);
        userNames.add('$adminFirst $adminLast');

        // Wait for trigger to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Check if profile was created by trigger
        final existingAdminProfile = await client
            .from('profiles')
            .select('id')
            .eq('id', adminUserId)
            .maybeSingle();

        final adminAvatarUrl = 'https://api.dicebear.com/7.x/avataaars/svg?seed=$adminEmail&excludeMetadata=true';
        if (existingAdminProfile == null) {
          // Profile wasn't created by trigger, create it directly
          try {
            await client.from('profiles').insert({
              'id': adminUserId,
              'email': adminEmail,
              'username': adminUsername,
              'first_name': adminFirst,
              'last_name': adminLast,
              'avatar_url': adminAvatarUrl,
              'street_address': '1 Admin Way',
              'city': 'Austin',
              'state_province': 'TX',
              'postal_code': '78701',
              'country': 'United States',
              'created_at': nowIso,
              'updated_at': nowIso,
            });
          } catch (e) {
            print('    ⚠️  Failed to create admin profile: $e');
            rethrow;
          }
        } else {
          // Profile exists, update additional fields
          try {
            await client.from('profiles').update({
              'avatar_url': adminAvatarUrl,
              'street_address': '1 Admin Way',
              'city': 'Austin',
              'state_province': 'TX',
              'postal_code': '78701',
              'country': 'United States',
              'updated_at': nowIso,
            }).eq('id', adminUserId);
          } catch (e) {
            print('    ⚠️  Failed to update admin profile: $e');
          }
        }

        final adminLocationId = uuid.v4();
        try {
          await client.from('locations').insert({
            'id': adminLocationId,
            'group_id': null,
            'profile_id': adminUserId,
            'street_address': '1 Admin Way',
            'city': 'Austin',
            'state_province': 'TX',
            'postal_code': '78701',
            'country': 'United States',
            'label': 'Admin Home',
            'is_primary': true,
            'created_by': adminUserId,
            'created_at': nowIso,
            'updated_at': nowIso,
          });
          locationIds.add(adminLocationId);
        } catch (e) {
          print('    ⚠️  Admin location insert failed: $e');
        }
      } catch (e) {
        print('  ✗ Failed to create admin user: $e');
        rethrow;
      }

      expect(userIds.length, 11, reason: 'Should have seeded 10 users + 1 admin with profiles and locations');
      print('\n✅ Successfully created 11 users (10 dummy + 1 admin) with addresses\n');

      print('👥 Creating 3 groups (2 by Avery, 1 by Finley) with memberships...');
      final group1Id = uuid.v4();
      final group2Id = uuid.v4();
      final group3Id = uuid.v4();

      await client.from('groups').insert({
        'id': group1Id,
        'name': 'Downtown Sharks',
        'description': "Thursday night no-limit hold'em crew",
        'avatar_url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=downtown-sharks&excludeMetadata=true',
        'created_by': userIds[0], // Avery
        'privacy': 'private',
        'default_currency': 'USD',
        'default_buyin': 120.0,
        'additional_buyin_values': [60.0],
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      await client.from('groups').insert({
        'id': group2Id,
        'name': 'River Runners',
        'description': 'Avery-hosted midweek mix',
        'avatar_url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=river-runners&excludeMetadata=true',
        'created_by': userIds[0], // Avery
        'privacy': 'public',
        'default_currency': 'USD',
        'default_buyin': 90.0,
        'additional_buyin_values': [45.0],
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      await client.from('groups').insert({
        'id': group3Id,
        'name': 'High Desert Crew',
        'description': 'Finley-hosted weekend games',
        'avatar_url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=high-desert-crew&excludeMetadata=true',
        'created_by': userIds[5], // Finley
        'privacy': 'private',
        'default_currency': 'USD',
        'default_buyin': 75.0,
        'additional_buyin_values': [35.0],
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      final groupIds = [group1Id, group2Id, group3Id];

      final group1Members = [userIds[0], userIds[1], userIds[2], userIds[3], userIds[4]]; // Avery + 4
      final group2Members = [userIds[0], userIds[5], userIds[6], userIds[7], userIds[8]]; // Avery + 4
      final group3Members = [userIds[5], userIds[2], userIds[9]]; // Finley + 2
      final adminId = adminUserId!;

      final memberRows = <Map<String, dynamic>>[
        // Group 1 (Avery creator)
        {
          'group_id': group1Id,
          'user_id': group1Members.first,
          'role': 'admin',
          'is_creator': true,
        },
        ...group1Members.skip(1).map((id) => {
              'group_id': group1Id,
              'user_id': id,
              'role': 'member',
              'is_creator': false,
            }),
        {
          'group_id': group1Id,
          'user_id': adminId,
          'role': 'admin',
          'is_creator': false,
        },

        // Group 2 (Avery creator)
        {
          'group_id': group2Id,
          'user_id': group2Members.first,
          'role': 'admin',
          'is_creator': true,
        },
        ...group2Members.skip(1).map((id) => {
              'group_id': group2Id,
              'user_id': id,
              'role': 'member',
              'is_creator': false,
            }),
        {
          'group_id': group2Id,
          'user_id': adminId,
          'role': 'admin',
          'is_creator': false,
        },

        // Group 3 (Finley creator)
        {
          'group_id': group3Id,
          'user_id': group3Members.first,
          'role': 'admin',
          'is_creator': true,
        },
        ...group3Members.skip(1).map((id) => {
              'group_id': group3Id,
              'user_id': id,
              'role': 'member',
              'is_creator': false,
            }),
        {
          'group_id': group3Id,
          'user_id': adminId,
          'role': 'admin',
          'is_creator': false,
        },
      ];

      await client.from('group_members').insert(memberRows);
      print('✅ Groups created with ${memberRows.length} total memberships\n');

      // Neutral locations per group
      final neutralLocations = [
        {
          'id': uuid.v4(),
          'group_id': group1Id,
          'street': '400 Harbor Point',
          'city': 'San Diego',
          'state': 'CA',
          'postal': '92101',
          'label': 'Neutral Event Space 1',
        },
        {
          'id': uuid.v4(),
          'group_id': group2Id,
          'street': '50 Lake Shore Dr',
          'city': 'Chicago',
          'state': 'IL',
          'postal': '60601',
          'label': 'Neutral Event Space 2',
        },
        {
          'id': uuid.v4(),
          'group_id': group3Id,
          'street': '700 Desert View',
          'city': 'Phoenix',
          'state': 'AZ',
          'postal': '85004',
          'label': 'Neutral Event Space 3',
        },
      ];

      for (final loc in neutralLocations) {
        await client.from('locations').insert({
          'id': loc['id'],
          'group_id': loc['group_id'],
          'profile_id': null,
          'street_address': loc['street'],
          'city': loc['city'],
          'state_province': loc['state'],
          'postal_code': loc['postal'],
          'country': 'United States',
          'label': loc['label'],
          'is_primary': false,
          'created_by': adminId,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
        locationIds.add(loc['id'] as String);
      }

      print('🎮 Creating 4 games per group (12 total) + 1 GBP game...');
      final gamesCreated = <String>[];
      final allParticipants = <Map<String, dynamic>>[];

      final gameConfigs = [
        {'groupId': group1Id, 'members': group1Members, 'prefix': 'Sharks', 'currency': 'USD'},
        {'groupId': group2Id, 'members': group2Members, 'prefix': 'Runners', 'currency': 'USD'},
        {'groupId': group3Id, 'members': group3Members, 'prefix': 'Desert', 'currency': 'USD'},
      ];

      // Only completed, cancelled, and scheduled games are created (in_progress skipped)
      for (final cfg in gameConfigs) {
        final gid = cfg['groupId'] as String;
        final members = (cfg['members'] as List<String>);
        final prefix = cfg['prefix'] as String;
        final currency = cfg['currency'] as String;
        final neutralAddr = neutralLocations.firstWhere((l) => l['group_id'] == gid);
        for (var i = 0; i < 5; i++) {
          // --- ACTIVE (in-progress) game population removed as requested ---
          if (i == 3) {
            // Skipping in-progress game population
            continue;
          }

          final gameId = uuid.v4();
          final gameName = '$prefix Game ${i + 1}';
          String gameStatus;
          DateTime gameDate;
          bool hasTransactions;

          if (i == 0) {
            gameStatus = 'completed';
            gameDate = now.subtract(const Duration(days: 14));
            hasTransactions = true;
          } else if (i == 1) {
            gameStatus = 'completed';
            gameDate = now.subtract(const Duration(days: 7));
            hasTransactions = true;
          } else if (i == 2) {
            gameStatus = 'cancelled';
            gameDate = now.subtract(const Duration(days: 3));
            hasTransactions = false; // Cancelled games have no transactions
          } else {
            gameStatus = 'scheduled';
            gameDate = now.add(const Duration(days: 2)); // Within 3-day window for "Start Games"
            hasTransactions = false; // Scheduled games have no transactions yet
          }

          await client.from('games').insert({
            'id': gameId,
            'group_id': gid,
            'name': gameName,
            'game_date': gameDate.toIso8601String(),
            'location': '${neutralAddr['street']}, ${neutralAddr['city']}, ${neutralAddr['state']} ${neutralAddr['postal']}, United States',
            'location_host_user_id': null,
            'max_players': 8,
            'currency': currency,
            'buyin_amount': 100.0,
            'additional_buyin_values': [50.0],
            'status': gameStatus,
            'created_at': nowIso,
            'updated_at': nowIso,
          });
          gamesCreated.add(gameId);

          if (!hasTransactions) {
            // For scheduled and cancelled games, create participants without transactions
            final participants = [
              {'userId': members[0]},
              {'userId': members.length > 1 ? members[1] : adminId},
              {'userId': members.length > 2 ? members[2] : adminId},
            ];
            for (final participant in participants) {
              final participantId = uuid.v4();
              await client.from('game_participants').insert({
                'id': participantId,
                'game_id': gameId,
                'user_id': participant['userId'],
                'rsvp_status': gameStatus == 'cancelled' ? 'not_going' : 'going',
                'total_buyin': 0.0,
                'total_cashout': 0.0,
                'created_at': nowIso,
              });
            }
            continue;
          }

          // For completed games, create realistic transaction data
          List<Map<String, dynamic>> participants;
          if (i == 0) {
            participants = [
              {'userId': members[0], 'buyins': [100.0, 50.0, 50.0], 'cashout': 100.0},
              {'userId': members.length > 1 ? members[1] : adminId, 'buyins': [100.0], 'cashout': 150.0},
              {'userId': members.length > 2 ? members[2] : adminId, 'buyins': [100.0, 50.0], 'cashout': 200.0},
            ];
          } else if (i == 1) {
            participants = [
              {'userId': members[0], 'buyins': [100.0], 'cashout': 80.0},
              {'userId': members.length > 1 ? members[1] : adminId, 'buyins': [100.0, 50.0], 'cashout': 200.0},
              {'userId': members.length > 2 ? members[2] : adminId, 'buyins': [100.0], 'cashout': 70.0},
            ];
          } else {
            // Should not reach here for in-progress (i==3) due to continue above
            continue;
          }

          // Batch insert all participants at once
          final participantRows = <Map<String, dynamic>>[];
          final transactionRows = <Map<String, dynamic>>[];

          for (final participant in participants) {
            final buyins = participant['buyins'] as List<double>;
            final totalBuyin = buyins.fold<double>(0.0, (sum, amount) => sum + amount);
            final cashout = participant['cashout'] as double;

            final participantId = uuid.v4();
            participantRows.add({
              'id': participantId,
              'game_id': gameId,
              'user_id': participant['userId'],
              'rsvp_status': 'going',
              'total_buyin': totalBuyin,
              'total_cashout': cashout,
              'created_at': nowIso,
            });

            // Collect buy-in transactions for completed games
            if (gameStatus == 'completed') {
              for (var j = 0; j < buyins.length; j++) {
                transactionRows.add({
                  'game_id': gameId,
                  'user_id': participant['userId'],
                  'type': 'buyin',
                  'amount': buyins[j],
                  'timestamp': gameDate.add(Duration(minutes: j * 30)).toIso8601String(),
                  'notes': j == 0 ? 'Initial buy-in' : 'Additional buy-in',
                });
              }
              // Only completed games get cash-out transactions
              if (cashout > 0) {
                transactionRows.add({
                  'game_id': gameId,
                  'user_id': participant['userId'],
                  'type': 'cashout',
                  'amount': cashout,
                  'timestamp': gameDate.add(const Duration(hours: 4)).toIso8601String(),
                  'notes': 'Final cash out',
                });
              }
            }
          }

          // Insert all participants in one batch
          await client.from('game_participants').insert(participantRows);

          // Insert all transactions
          if (transactionRows.isNotEmpty) {
            await client.from('transactions').insert(transactionRows);
          }

          allParticipants.addAll(participants.map((p) => {
            'userId': p['userId'],
            'buyin': (p['buyins'] as List<double>).fold<double>(0.0, (sum, amount) => sum + amount),
            'cashout': p['cashout'],
          }));
        }
      }

      // Create an additional GBP game in Group 1 (Downtown Sharks)
      print('🇬🇧 Creating additional GBP game...');
      final gbpGameId = uuid.v4();
      final gbpGameDate = now.subtract(const Duration(days: 5));
      final gbpNeutralAddr = neutralLocations.firstWhere((l) => l['group_id'] == group1Id);

      await client.from('games').insert({
        'id': gbpGameId,
        'group_id': group1Id,
        'name': 'Sharks GBP Night',
        'game_date': gbpGameDate.toIso8601String(),
        'location': '${gbpNeutralAddr['street']}, ${gbpNeutralAddr['city']}, ${gbpNeutralAddr['state']} ${gbpNeutralAddr['postal']}, United States',
        'location_host_user_id': null,
        'max_players': 8,
        'currency': 'GBP',
        'buyin_amount': 50.0,
        'additional_buyin_values': [25.0],
        'status': 'completed',
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      gamesCreated.add(gbpGameId);

      // Add participants with transactions for the GBP game
      final gbpParticipants = [
        {'userId': group1Members[0], 'buyins': [50.0, 25.0], 'cashout': 100.0},
        {'userId': group1Members[1], 'buyins': [50.0], 'cashout': 40.0},
        {'userId': group1Members[2], 'buyins': [50.0, 25.0], 'cashout': 60.0},
      ];

      final gbpParticipantRows = <Map<String, dynamic>>[];
      final gbpTransactionRows = <Map<String, dynamic>>[];

      for (final participant in gbpParticipants) {
        final buyins = participant['buyins'] as List<double>;
        final totalBuyin = buyins.fold<double>(0.0, (sum, amount) => sum + amount);
        final cashout = participant['cashout'] as double;

        final participantId = uuid.v4();
        gbpParticipantRows.add({
          'id': participantId,
          'game_id': gbpGameId,
          'user_id': participant['userId'],
          'rsvp_status': 'going',
          'total_buyin': totalBuyin,
          'total_cashout': cashout,
          'created_at': nowIso,
        });

        for (var j = 0; j < buyins.length; j++) {
          gbpTransactionRows.add({
            'game_id': gbpGameId,
            'user_id': participant['userId'],
            'type': 'buyin',
            'amount': buyins[j],
            'timestamp': gbpGameDate.add(Duration(minutes: j * 30)).toIso8601String(),
            'notes': j == 0 ? 'Initial buy-in' : 'Additional buy-in',
          });
        }
        gbpTransactionRows.add({
          'game_id': gbpGameId,
          'user_id': participant['userId'],
          'type': 'cashout',
          'amount': cashout,
          'timestamp': gbpGameDate.add(const Duration(hours: 4)).toIso8601String(),
          'notes': 'Final cash out',
        });
      }

      await client.from('game_participants').insert(gbpParticipantRows);
      await client.from('transactions').insert(gbpTransactionRows);

      allParticipants.addAll(gbpParticipants.map((p) => {
        'userId': p['userId'],
        'buyin': (p['buyins'] as List<double>).fold<double>(0.0, (sum, amount) => sum + amount),
        'cashout': p['cashout'],
      }));

      print('✅ GBP game created with ${gbpParticipants.length} participants\n');

      print('\n📊 Validation checks...');
      expect(groupIds.length, 3, reason: 'Three groups should be present');
      expect(locationIds.length, 14, reason: '11 personal locations (including admin) + 3 neutral group locations');
      expect(memberRows.length, 16, reason: 'Group1:6, Group2:6, Group3:4 memberships total');
      expect(allParticipants.length, 21, reason: 'Six USD games with transactions * 3 participants each + 1 GBP game * 3 participants');
      expect(gamesCreated.length, 13, reason: 'Four games per group (3 groups) = 12 USD games + 1 GBP game = 13 total');

      // Verify all users have avatar URLs
      final profilesWithAvatars = await client.from('profiles').select('id, avatar_url').gt('avatar_url', '');
      expect(profilesWithAvatars.length, userIds.length, reason: 'All users should have avatar URLs assigned');
      print('✅ All ${profilesWithAvatars.length} users have avatar URLs from DiceBear\n');

        // Verify neutral locations are group-bound, not profile-bound
        for (final loc in neutralLocations) {
        final dbLoc = await client
          .from('locations')
          .select('profile_id, group_id')
          .eq('id', loc['id'] as String)
          .single();
        expect(dbLoc['profile_id'], isNull, reason: 'Neutral location must not be bound to a member');
        expect(dbLoc['group_id'], loc['group_id'], reason: 'Neutral location must belong to its group');
        }

        // Verify a sample game is host-less and uses the neutral address
        final sampleGameId = gamesCreated.first;
        final sampleGame = await client
          .from('games')
          .select('location_host_user_id, location, group_id')
          .eq('id', sampleGameId)
          .single();
        expect(sampleGame['location_host_user_id'], isNull, reason: 'Game should not be bound to a host user');
        final expectedAddr = neutralLocations
          .firstWhere((l) => l['group_id'] == sampleGame['group_id']);
        expect(
        sampleGame['location'],
        '${expectedAddr['street']}, ${expectedAddr['city']}, ${expectedAddr['state']} ${expectedAddr['postal']}, United States',
        reason: 'Game should use the neutral location address for its group',
        );

        // Schema-level sanity checks via row counts
        final profiles = await client.from('profiles').select('id');
        final groupsTable = await client.from('groups').select('id');
        final locationsTable = await client.from('locations').select('id, profile_id, group_id');
        final gamesTable = await client.from('games').select('id');
        final membersTable = await client.from('group_members').select('id');
        final participantsTable = await client.from('game_participants').select('id');
        final transactionsTable = await client.from('transactions').select('id');

        final personalLocationsCount = locationsTable.where((loc) => loc['profile_id'] != null && loc['group_id'] == null).length;
        final neutralLocationsCount = locationsTable.where((loc) => loc['profile_id'] == null && loc['group_id'] != null).length;

        final lenient = !shouldClear;

        void expectCount(int actual, int expected, String msg) {
          if (lenient) {
            expect(actual, greaterThanOrEqualTo(expected), reason: '$msg (lenient)');
          } else {
            expect(actual, expected, reason: msg);
          }
        }

        expectCount(profiles.length, 11, 'profiles table should contain 10 seeded users + 1 admin');
        final expectedNeutrals = shouldClear ? 3 : 1; // existing data may have fewer if not cleared
        final expectedLocations = shouldClear ? 14 : 12; // existing data may have old totals

        expectCount(groupsTable.length, 3, 'groups table should contain 3 seeded groups');
        expectCount(membersTable.length, 16, 'group_members table should contain 16 memberships');
        expectCount(personalLocationsCount, 11, 'locations table should contain 11 personal addresses');
        expectCount(neutralLocationsCount, expectedNeutrals, 'locations table should contain neutral group addresses');
        expectCount(locationsTable.length, expectedLocations, 'locations table should contain total addresses');
        expectCount(gamesTable.length, 13, 'games table should contain 13 games (12 USD + 1 GBP)');
        expectCount(participantsTable.length, 39, 'game_participants table should contain 39 participants (12 USD games * 3 + 1 GBP game * 3)');
        // Transactions: 7 completed games have transactions (6 USD + 1 GBP)
        // Each completed game has varied buy-ins + cash-outs
        expect(transactionsTable.length, greaterThan(45), reason: 'transactions table should contain buy-ins and cash-outs for completed games');

      final group1AdminIdx = userIds.indexOf(group1Members.first);
      final group2AdminIdx = userIds.indexOf(group2Members.first);
      final group3AdminIdx = userIds.indexOf(group3Members.first);
      final group1AdminName = group1AdminIdx >= 0 ? userNames[group1AdminIdx] : 'Unknown';
      final group2AdminName = group2AdminIdx >= 0 ? userNames[group2AdminIdx] : 'Unknown';
      final group3AdminName = group3AdminIdx >= 0 ? userNames[group3AdminIdx] : 'Unknown';
      final group1AdminEmail = group1AdminIdx >= 0 ? dummyUsers[group1AdminIdx]['email'] : 'Unknown';
      final group2AdminEmail = group2AdminIdx >= 0 ? dummyUsers[group2AdminIdx]['email'] : 'Unknown';
      final group3AdminEmail = group3AdminIdx >= 0 ? dummyUsers[group3AdminIdx]['email'] : 'Unknown';
      final globalAdminName = '$adminFirst $adminLast';

      print('\n✅ Dummy data setup completed successfully!');
      print('   • Default password (all users): $defaultPassword');
      print('   • Users created: ${userIds.length}');
      print('   • Groups created: ${groupIds.length}');
      print('   • Locations created: ${locationIds.length}');
      print('   • Games created: ${gamesCreated.length}');
      print('   • Participants added: ${allParticipants.length}');
      print('   • Transactions written: ${allParticipants.length * 2}');
      print('   • Group "Downtown Sharks" admin: $group1AdminName ($group1AdminEmail)');
      print('   • Group "River Runners" admin: $group2AdminName ($group2AdminEmail)');
      print('   • Group "High Desert Crew" admin: $group3AdminName ($group3AdminEmail)');
      print('   • Global admin user: $globalAdminName ($adminEmail)');
    });
  });
}
