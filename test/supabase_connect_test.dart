import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

Future<Map<String, dynamic>> _loadEnvJson() async {
  final file = File('env.json');
  if (!await file.exists()) {
    throw StateError('env.json not found at project root');
  }
  final text = await file.readAsString();
  return jsonDecode(text) as Map<String, dynamic>;
}

String? _envValue(Map<String, dynamic> env, List<String> keys) {
  for (final k in keys) {
    if (env.containsKey(k) && (env[k]?.toString().isNotEmpty ?? false)) {
      return env[k].toString();
    }
  }
  return null;
}

void main() {
  group('Supabase connectivity', () {
    late SupabaseClient client;

    setUpAll(() async {
      final env = await _loadEnvJson();
      final url = _envValue(env, ['SUPABASE_URL', 'supabaseUrl']);
      final anonKey = _envValue(env, ['SUPABASE_ANON_KEY', 'supabaseAnonKey']);

      if (url == null || anonKey == null) {
        throw StateError('Missing SUPABASE_URL/SUPABASE_ANON_KEY in env.json');
      }

      client = SupabaseClient(url, anonKey);
    });

    test('select from public.profiles succeeds (public SELECT policy)', () async {
      final res = await client.from('profiles').select('id').limit(1);
      expect(res, isA<List>());
    });

    test('insert into profiles without auth is blocked by RLS', () async {
      try {
        await client.from('profiles').insert({
          'id': '00000000-0000-0000-0000-000000000000',
          'email': 'test@example.com',
          'first_name': 'Test',
          'last_name': 'User',
          'country': 'US',
        });
        fail('Expected PostgrestException due to RLS');
      } on PostgrestException catch (e) {
        final msg = e.message.toLowerCase();
        expect(msg.contains('permission') || msg.contains('policy') || msg.contains('not allowed'), isTrue);
      }
    });

    test('insert into group_members without auth is blocked by RLS', () async {
      try {
        await client.from('group_members').insert({
          'group_id': '00000000-0000-0000-0000-000000000000',
          'user_id': '00000000-0000-0000-0000-000000000000',
          'role': 'member',
          'is_creator': false,
        });
        fail('Expected PostgrestException due to RLS');
      } on PostgrestException catch (e) {
        final msg = e.message.toLowerCase();
        expect(msg.contains('permission') || msg.contains('policy') || msg.contains('not allowed'), isTrue);
      }
    });
  });
}
