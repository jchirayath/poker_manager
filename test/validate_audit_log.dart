import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';

/// Validate that financial_audit_log has records and is working
void main() {
  test('Validate financial_audit_log has records', () async {
    // Load environment from env.json
    final envFile = File('env.json');
    if (!envFile.existsSync()) {
      throw Exception('env.json file not found');
    }

    final envJson = jsonDecode(envFile.readAsStringSync()) as Map<String, dynamic>;
    final supabaseUrl = envJson['SUPABASE_URL'] as String? ?? '';
    final supabaseServiceKey = envJson['SUPABASE_SERVICE_ROLE_KEY'] as String? ?? '';

    final supabase = SupabaseClient(supabaseUrl, supabaseServiceKey);

    // Get count of all audit records
    final allRecords = await supabase
        .from('financial_audit_log')
        .select()
        .order('created_at', ascending: false);

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║       FINANCIAL AUDIT LOG VALIDATION REPORT                ║');
    print('╚════════════════════════════════════════════════════════════╝\n');

    print('📊 Total Records: ${allRecords.length}');

    if (allRecords.isEmpty) {
      print('❌ No records found in financial_audit_log!');
      print('   The triggers may not be working correctly.');
      throw Exception('No audit records found');
    }

    // Group by table name
    final byTable = <String, int>{};
    final byOperation = <String, int>{};

    for (var record in allRecords) {
      final table = record['table_name'] as String;
      final operation = record['operation'] as String;
      byTable[table] = (byTable[table] ?? 0) + 1;
      byOperation[operation] = (byOperation[operation] ?? 0) + 1;
    }

    print('\n📋 Records by Table:');
    byTable.forEach((table, count) {
      print('   • $table: $count records');
    });

    print('\n🔄 Records by Operation:');
    byOperation.forEach((operation, count) {
      print('   • $operation: $count records');
    });

    // Show recent records
    print('\n📝 Most Recent 10 Audit Entries:');
    final recent = allRecords.take(10).toList();
    for (var i = 0; i < recent.length; i++) {
      final record = recent[i];
      final table = record['table_name'];
      final op = record['operation'];
      final oldAmt = record['old_amount'];
      final newAmt = record['new_amount'];
      final createdAt = record['created_at'];

      print('   ${i + 1}. [$table.$op] ${oldAmt ?? 0.0} → ${newAmt ?? 0.0} @ $createdAt');
    }

    // Verify we have all three trigger types working
    final hasTransactions = byTable.containsKey('transactions');
    final hasSettlements = byTable.containsKey('settlements');
    final hasParticipants = byTable.containsKey('game_participants');

    print('\n✅ Trigger Status:');
    print('   • Transactions trigger: ${hasTransactions ? "✓ Working" : "✗ Not working"}');
    print('   • Settlements trigger:  ${hasSettlements ? "✓ Working" : "✗ Not working"}');
    print('   • Participants trigger: ${hasParticipants ? "✓ Working" : "✗ Not working"}');

    if (hasTransactions && hasSettlements && hasParticipants) {
      print('\n🎉 SUCCESS! All audit triggers are working correctly!');
    } else {
      print('\n⚠️  WARNING: Some triggers may not be working.');
    }

    expect(allRecords.length, greaterThan(0),
           reason: 'Should have audit records');
  });
}
