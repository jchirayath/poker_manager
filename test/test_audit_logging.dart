import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';

/// Test to validate that financial audit logging is working
///
/// This test will:
/// 1. Create a test transaction
/// 2. Verify the audit log captured it
/// 3. Update the transaction
/// 4. Verify the update was logged
/// 5. Delete the transaction
/// 6. Verify the delete was logged
void main() {
  late SupabaseClient supabase;

  setUpAll(() async {
    // Load environment from env.json
    final envFile = File('env.json');
    if (!envFile.existsSync()) {
      throw Exception('env.json file not found. Please create it with SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
    }

    final envJson = jsonDecode(envFile.readAsStringSync()) as Map<String, dynamic>;
    final supabaseUrl = envJson['SUPABASE_URL'] as String? ?? '';
    final supabaseServiceKey = envJson['SUPABASE_SERVICE_ROLE_KEY'] as String? ?? '';

    if (supabaseUrl.isEmpty || supabaseServiceKey.isEmpty) {
      throw Exception('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in env.json');
    }

    // Initialize Supabase with service role key (for admin operations)
    supabase = SupabaseClient(supabaseUrl, supabaseServiceKey);
  });

  group('Financial Audit Log Tests', () {
    test('Audit log captures transaction INSERT, UPDATE, and DELETE', () async {
      // Get a test game and user
      final games = await supabase
          .from('games')
          .select('id, group_id')
          .limit(1)
          .maybeSingle();

      if (games == null) {
        print('No games found - skipping test');
        return;
      }

      final gameId = games['id'] as String;

      // Get a user from this game's group
      final member = await supabase
          .from('group_members')
          .select('user_id')
          .eq('group_id', games['group_id'])
          .limit(1)
          .single();

      final userId = member['user_id'] as String;

      // STEP 1: Insert a test transaction
      print('\n1. Creating test transaction...');
      final insertResponse = await supabase
          .from('transactions')
          .insert({
            'game_id': gameId,
            'user_id': userId,
            'type': 'buyin',
            'amount': 100.00,
            'notes': 'Test transaction for audit logging',
          })
          .select()
          .single();

      final transactionId = insertResponse['id'] as String;
      print('   Created transaction: $transactionId');

      // Wait a moment for trigger to execute
      await Future.delayed(Duration(milliseconds: 500));

      // Verify INSERT was logged
      print('\n2. Checking audit log for INSERT...');
      final insertAudit = await supabase
          .from('financial_audit_log')
          .select()
          .eq('table_name', 'transactions')
          .eq('record_id', transactionId)
          .eq('operation', 'INSERT')
          .maybeSingle();

      expect(insertAudit, isNotNull, reason: 'INSERT should be logged');
      expect(insertAudit!['new_amount'], 100.00);
      expect(insertAudit['user_id'], userId);
      print('   ✓ INSERT logged successfully');
      print('   Audit ID: ${insertAudit['id']}');
      print('   New amount: ${insertAudit['new_amount']}');

      // STEP 2: Update the transaction
      print('\n3. Updating transaction amount...');
      await supabase
          .from('transactions')
          .update({'amount': 150.00})
          .eq('id', transactionId);

      await Future.delayed(Duration(milliseconds: 500));

      // Verify UPDATE was logged
      print('\n4. Checking audit log for UPDATE...');
      final updateAudit = await supabase
          .from('financial_audit_log')
          .select()
          .eq('table_name', 'transactions')
          .eq('record_id', transactionId)
          .eq('operation', 'UPDATE')
          .maybeSingle();

      expect(updateAudit, isNotNull, reason: 'UPDATE should be logged');
      expect(updateAudit!['old_amount'], 100.00);
      expect(updateAudit['new_amount'], 150.00);
      print('   ✓ UPDATE logged successfully');
      print('   Audit ID: ${updateAudit['id']}');
      print('   Old amount: ${updateAudit['old_amount']}');
      print('   New amount: ${updateAudit['new_amount']}');

      // STEP 3: Delete the transaction
      print('\n5. Deleting transaction...');
      await supabase
          .from('transactions')
          .delete()
          .eq('id', transactionId);

      await Future.delayed(Duration(milliseconds: 500));

      // Verify DELETE was logged
      print('\n6. Checking audit log for DELETE...');
      final deleteAudit = await supabase
          .from('financial_audit_log')
          .select()
          .eq('table_name', 'transactions')
          .eq('record_id', transactionId)
          .eq('operation', 'DELETE')
          .maybeSingle();

      expect(deleteAudit, isNotNull, reason: 'DELETE should be logged');
      expect(deleteAudit!['old_amount'], 150.00);
      print('   ✓ DELETE logged successfully');
      print('   Audit ID: ${deleteAudit['id']}');
      print('   Old amount: ${deleteAudit['old_amount']}');

      // Summary
      print('\n✅ All audit logging tests passed!');
      print('\nAudit trail for transaction $transactionId:');
      final fullAudit = await supabase
          .from('financial_audit_log')
          .select()
          .eq('record_id', transactionId)
          .order('created_at');

      for (var entry in fullAudit) {
        print('  ${entry['operation']}: ${entry['old_amount'] ?? 0.0} → ${entry['new_amount'] ?? 0.0} at ${entry['created_at']}');
      }
    });

    test('Audit log captures settlement changes', () async {
      print('\n--- Testing Settlement Audit Logging ---');

      // Get a test game
      final games = await supabase
          .from('games')
          .select('id, group_id')
          .limit(1)
          .maybeSingle();

      if (games == null) {
        print('No games found - skipping test');
        return;
      }

      final gameId = games['id'] as String;

      // Get two users from this game's group
      final members = await supabase
          .from('group_members')
          .select('user_id')
          .eq('group_id', games['group_id'])
          .limit(2);

      if (members.length < 2) {
        print('Not enough members - skipping test');
        return;
      }

      final fromUserId = members[0]['user_id'] as String;
      final toUserId = members[1]['user_id'] as String;

      // Create a test settlement
      print('\n1. Creating test settlement...');
      final settlement = await supabase
          .from('settlements')
          .insert({
            'game_id': gameId,
            'from_user_id': fromUserId,
            'to_user_id': toUserId,
            'amount': 50.00,
            'payment_method': 'cash',
            'status': 'pending',
          })
          .select()
          .single();

      final settlementId = settlement['id'] as String;
      print('   Created settlement: $settlementId');

      await Future.delayed(Duration(milliseconds: 500));

      // Verify INSERT was logged
      print('\n2. Checking audit log for settlement INSERT...');
      final insertAudit = await supabase
          .from('financial_audit_log')
          .select()
          .eq('table_name', 'settlements')
          .eq('record_id', settlementId)
          .eq('operation', 'INSERT')
          .maybeSingle();

      expect(insertAudit, isNotNull, reason: 'Settlement INSERT should be logged');
      expect(insertAudit!['new_amount'], 50.00);
      expect(insertAudit['new_status'], 'pending');
      print('   ✓ Settlement INSERT logged');

      // Update settlement to completed
      print('\n3. Marking settlement as completed...');
      await supabase
          .from('settlements')
          .update({'status': 'completed'})
          .eq('id', settlementId);

      await Future.delayed(Duration(milliseconds: 500));

      // Verify UPDATE was logged
      print('\n4. Checking audit log for settlement UPDATE...');
      final updateAudit = await supabase
          .from('financial_audit_log')
          .select()
          .eq('table_name', 'settlements')
          .eq('record_id', settlementId)
          .eq('operation', 'UPDATE')
          .maybeSingle();

      expect(updateAudit, isNotNull, reason: 'Settlement UPDATE should be logged');
      expect(updateAudit!['old_status'], 'pending');
      expect(updateAudit['new_status'], 'completed');
      print('   ✓ Settlement UPDATE logged');

      // Cleanup
      await supabase
          .from('settlements')
          .delete()
          .eq('id', settlementId);

      print('\n✅ Settlement audit logging tests passed!');
    });

    test('Audit log shows complete history', () async {
      print('\n--- Testing Audit History Query ---');

      final auditRecords = await supabase
          .from('financial_audit_log')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      print('\nRecent audit log entries:');
      print('Total records found: ${auditRecords.length}');

      for (var record in auditRecords) {
        print('  ${record['table_name']}.${record['operation']}: '
              'record_id=${record['record_id']}, '
              'amount=${record['old_amount'] ?? 0} → ${record['new_amount'] ?? 0}, '
              'at ${record['created_at']}');
      }

      expect(auditRecords.isNotEmpty, true,
             reason: 'Should have audit records after previous tests');
    });
  });
}
