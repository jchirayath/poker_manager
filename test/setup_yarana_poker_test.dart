// ignore_for_file: avoid_print
//
// Yarana Family Poker Group Setup Test
//
// Usage:
//   flutter test test/setup_yarana_poker_test.dart
//

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';

void main() {
  group('Yarana Family Poker Setup', () {
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

    test('Create Yarana Family Poker group', () async {
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║           YARANA FAMILY POKER SETUP                        ║');
      print('╚════════════════════════════════════════════════════════════╝\n');

      const defaultPassword = 'TestPassword123!';

      final now = DateTime.now();
      final nowIso = now.toIso8601String();

      final yaranaMembers = <Map<String, String>>[
        {
          'email': 'monish.sharma@yarana.test',
          'first': 'Monish',
          'last': 'Sharma',
          'username': 'monish.sharma',
          'street': '3296 Ashbourne Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'sapna.sharma@yarana.test',
          'first': 'Sapna',
          'last': 'Sharma',
          'username': 'sapna.sharma',
          'street': '3296 Ashbourne Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'tarun.kapur@yarana.test',
          'first': 'Tarun',
          'last': 'Kapur',
          'username': 'tarun.kapur',
          'street': '3334 Ashbourne Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'shikha.kapur@yarana.test',
          'first': 'Shikha',
          'last': 'Kapur',
          'username': 'shikha.kapur',
          'street': '3334 Ashbourne Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'saloni.kharbanda@yarana.test',
          'first': 'Saloni',
          'last': 'Kharbanda',
          'username': 'saloni.kharbanda',
          'street': '3412 Ashbourne Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'vishal.walia@yarana.test',
          'first': 'Vishal',
          'last': 'Walia',
          'username': 'vishal.walia',
          'street': '3412 Ashbourne Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'sapna.gangwani@yarana.test',
          'first': 'Sapna',
          'last': 'Gangwani',
          'username': 'sapna.gangwani',
          'street': '3539 Ashbourne Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'raj.patel@yarana.test',
          'first': 'Raj',
          'last': 'Patel',
          'username': 'raj.patel',
          'street': '3551 Ashbourne Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'brinda.patel@yarana.test',
          'first': 'Brinda',
          'last': 'Patel',
          'username': 'brinda.patel',
          'street': '3551 Ashbourne Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'jacob.chirayath@yarana.test',
          'first': 'Jacob',
          'last': 'Chirayath',
          'username': 'jacob.chirayath',
          'street': '407 Camberly Court',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'kirti.sazawal@yarana.test',
          'first': 'Kirti',
          'last': 'Sazawal',
          'username': 'kirti.sazawal',
          'street': '407 Camberly Court',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'raj.meghani@yarana.test',
          'first': 'Raj',
          'last': 'Meghani',
          'username': 'raj.meghani',
          'street': '208 Cliffecastle Court',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'sapna.meghani@yarana.test',
          'first': 'Sapna',
          'last': 'Meghani',
          'username': 'sapna.meghani',
          'street': '208 Cliffecastle Court',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'pawan.kumar@yarana.test',
          'first': 'Pawan',
          'last': 'Kumar',
          'username': 'pawan.kumar',
          'street': '400 Cranleigh Court',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'vaishali.kumar@yarana.test',
          'first': 'Vaishali',
          'last': 'Kumar',
          'username': 'vaishali.kumar',
          'street': '400 Cranleigh Court',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'ankur.gupta@yarana.test',
          'first': 'Ankur',
          'last': 'Gupta',
          'username': 'ankur.gupta',
          'street': '627 Hardcastle Court',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'sk.panda@yarana.test',
          'first': 'SK',
          'last': 'Panda',
          'username': 'sk.panda',
          'street': '627 Hardcastle Court',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'rakesh.patel@yarana.test',
          'first': 'Rakesh',
          'last': 'Patel',
          'username': 'rakesh.patel',
          'street': '1078 Hawkshead Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'sharmila.patel@yarana.test',
          'first': 'Sharmila',
          'last': 'Patel',
          'username': 'sharmila.patel',
          'street': '1078 Hawkshead Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'bakul.roy@yarana.test',
          'first': 'Bakul',
          'last': 'Roy',
          'username': 'bakul.roy',
          'street': '1196 Hawkshed Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'hema.roy@yarana.test',
          'first': 'Hema',
          'last': 'Roy',
          'username': 'hema.roy',
          'street': '1196 Hawkshed Circle',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'arun.prakash@yarana.test',
          'first': 'Arun',
          'last': 'Prakash',
          'username': 'arun.prakash',
          'street': '236 Lyndhurst Place',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'sunita.prakash@yarana.test',
          'first': 'Sunita',
          'last': 'Prakash',
          'username': 'sunita.prakash',
          'street': '236 Lyndhurst Place',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'dharmesh.patel@yarana.test',
          'first': 'Dharmesh',
          'last': 'Patel',
          'username': 'dharmesh.patel',
          'street': '255 Lyndhurst Place',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'hema.patel@yarana.test',
          'first': 'Hema',
          'last': 'Patel',
          'username': 'hema.patel',
          'street': '255 Lyndhurst Place',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'sachin.agarwal@yarana.test',
          'first': 'Sachin',
          'last': 'Agarwal',
          'username': 'sachin.agarwal',
          'street': '130 Wittenham Court',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
        {
          'email': 'vanita.agarwal@yarana.test',
          'first': 'Vanita',
          'last': 'Agarwal',
          'username': 'vanita.agarwal',
          'street': '130 Wittenham Court',
          'city': 'SAN RAMON',
          'state': 'CA',
          'postal': '94583',
          'country': 'United States',
        },
      ];

      print('🚀 Creating ${yaranaMembers.length} Yarana Family Poker members...\n');

      final userIds = <String>[];
      final existingUsers = await client.auth.admin.listUsers();

      for (final user in yaranaMembers) {
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
          } catch (e) {
            print('    ⚠️  Location insert failed: $e');
          }
        } catch (e) {
          print('  ✗ Failed to create user $email: $e');
          rethrow;
        }
      }

      print('\n✅ Successfully created ${userIds.length} Yarana Family Poker members with addresses\n');

      // Create the Yarana Family Poker group
      print('👥 Creating Yarana Family Poker group...');
      final yaranaGroupId = uuid.v4();

      await client.from('groups').insert({
        'id': yaranaGroupId,
        'name': 'Yarana Family Poker',
        'description': "Where friendships are forged over flops, turns, and the occasional all-in bluff - because nothing says 'family' like taking each other's chips!",
        'avatar_url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=yarana-family-poker&excludeMetadata=true',
        'created_by': userIds[0], // Monish as creator
        'privacy': 'private',
        'default_currency': 'USD',
        'default_buyin': 100.0,
        'additional_buyin_values': [50.0, 25.0],
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // Add all members to the group
      final memberRows = <Map<String, dynamic>>[];

      // First member (Monish) is the creator/admin
      memberRows.add({
        'group_id': yaranaGroupId,
        'user_id': userIds[0],
        'role': 'admin',
        'is_creator': true,
      });

      // Rest of the members
      for (var i = 1; i < userIds.length; i++) {
        memberRows.add({
          'group_id': yaranaGroupId,
          'user_id': userIds[i],
          'role': 'member',
          'is_creator': false,
        });
      }

      await client.from('group_members').insert(memberRows);
      print('✅ Yarana Family Poker group created with ${memberRows.length} members\n');

      print('✅ Yarana Family Poker setup completed successfully!');
      print('   • Default password (all users): $defaultPassword');
      print('   • Users created: ${userIds.length}');
      print('   • Group creator: ${yaranaMembers[0]['first']} ${yaranaMembers[0]['last']} (${yaranaMembers[0]['email']})');
    });
  });
}
