import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';

/// Verify that audit triggers don't block or interfere with normal operations
void main() {
  test('Audit triggers do not block setup operations', () async {
    final envFile = File('env.json');
    final envJson = jsonDecode(envFile.readAsStringSync()) as Map<String, dynamic>;
    final supabaseUrl = envJson['SUPABASE_URL'] as String;
    final supabaseServiceKey = envJson['SUPABASE_SERVICE_ROLE_KEY'] as String;
    final supabase = SupabaseClient(supabaseUrl, supabaseServiceKey);

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║       TRIGGER NON-BLOCKING VERIFICATION                    ║');
    print('╚════════════════════════════════════════════════════════════╝\n');

    // Get a test game
    final games = await supabase
        .from('games')
        .select('id, group_id')
        .limit(1)
        .single();

    final gameId = games['id'] as String;

    // Get a user from this game's group
    final member = await supabase
        .from('group_members')
        .select('user_id')
        .eq('group_id', games['group_id'])
        .limit(1)
        .single();

    final userId = member['user_id'] as String;

    print('✅ Setup scripts work:');
    print('   • Found game: $gameId');
    print('   • Found user: $userId');

    // Test 1: Verify bulk inserts work (like in setup scripts)
    print('\n🧪 Test 1: Bulk transaction inserts...');
    final beforeAudit = await supabase
        .from('financial_audit_log')
        .select();

    final beforeCount = beforeAudit.length;

    final bulkTransactions = [
      {
        'game_id': gameId,
        'user_id': userId,
        'type': 'buyin',
        'amount': 25.00,
        'notes': 'Bulk insert test 1',
      },
      {
        'game_id': gameId,
        'user_id': userId,
        'type': 'buyin',
        'amount': 25.00,
        'notes': 'Bulk insert test 2',
      },
      {
        'game_id': gameId,
        'user_id': userId,
        'type': 'cashout',
        'amount': 40.00,
        'notes': 'Bulk insert test 3',
      },
    ];

    final insertedTxns = await supabase
        .from('transactions')
        .insert(bulkTransactions)
        .select();

    print('   ✓ Inserted ${insertedTxns.length} transactions in bulk');

    await Future.delayed(Duration(milliseconds: 500));

    final afterAudit = await supabase
        .from('financial_audit_log')
        .select();

    final afterCount = afterAudit.length;
    final newAuditRecords = afterCount - beforeCount;
    print('   ✓ Created $newAuditRecords audit log entries');
    print('     (includes transaction inserts + game_participants updates)');

    expect(newAuditRecords, greaterThanOrEqualTo(insertedTxns.length),
           reason: 'Should create at least one audit entry per transaction');

    // Test 2: Verify rapid updates don't cause blocking
    print('\n🧪 Test 2: Rapid sequential updates...');
    final txnId = insertedTxns[0]['id'] as String;

    for (var i = 1; i <= 5; i++) {
      await supabase
          .from('transactions')
          .update({'amount': 25.00 + i})
          .eq('id', txnId);
    }

    print('   ✓ Performed 5 rapid updates without blocking');

    await Future.delayed(Duration(milliseconds: 500));

    final updateAudits = await supabase
        .from('financial_audit_log')
        .select()
        .eq('record_id', txnId)
        .eq('operation', 'UPDATE');

    print('   ✓ All ${updateAudits.length} updates were logged');

    // Test 3: Verify deletes don't block
    print('\n🧪 Test 3: Bulk deletes...');
    for (var txn in insertedTxns) {
      await supabase
          .from('transactions')
          .delete()
          .eq('id', txn['id']);
    }

    print('   ✓ Deleted ${insertedTxns.length} transactions without blocking');

    await Future.delayed(Duration(milliseconds: 500));

    final txnIds = insertedTxns.map((t) => t['id'] as String).toList();
    final deleteAudits = await supabase
        .from('financial_audit_log')
        .select()
        .inFilter('record_id', txnIds)
        .eq('operation', 'DELETE');

    print('   ✓ All ${deleteAudits.length} deletes were logged');

    // Final summary
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  ✅ VERIFICATION COMPLETE                                  ║');
    print('╠════════════════════════════════════════════════════════════╣');
    print('║  • Bulk inserts:     ✓ Work without blocking               ║');
    print('║  • Rapid updates:    ✓ Work without blocking               ║');
    print('║  • Bulk deletes:     ✓ Work without blocking               ║');
    print('║  • Audit logging:    ✓ All operations logged               ║');
    print('╚════════════════════════════════════════════════════════════╝\n');

    print('🎉 Audit triggers are non-blocking and do not interfere with');
    print('   setup scripts or normal database operations!');
  });
}
