#!/usr/bin/env node

/**
 * Quick test to verify env.json configuration
 * Run: npx tsx supabase/test_config.ts
 */

import * as fs from 'fs';
import * as path from 'path';

const envPath = path.join(__dirname, '..', 'env.json');

console.log('\n🔍 Testing configuration...\n');
console.log(`Looking for env.json at: ${envPath}`);

if (!fs.existsSync(envPath)) {
  console.log('❌ env.json not found!');
  process.exit(1);
}

console.log('✅ env.json found');

const envContent = fs.readFileSync(envPath, 'utf-8');
const config = JSON.parse(envContent);

console.log('\n📋 Configuration:');
console.log(`   SUPABASE_URL: ${config.SUPABASE_URL || '❌ Missing'}`);
console.log(`   SUPABASE_ANON_KEY: ${config.SUPABASE_ANON_KEY ? '✅ Present' : '❌ Missing'}`);
console.log(`   SUPABASE_SERVICE_ROLE_KEY: ${config.SUPABASE_SERVICE_ROLE_KEY ? '✅ Present' : '❌ Missing'}`);
console.log(`   SUPABASE_DB_URL: ${config.SUPABASE_DB_URL || '❌ Missing'}`);
console.log(`   SUPABASE_ACCESS_TOKEN: ${config.SUPABASE_ACCESS_TOKEN ? '✅ Present' : '⚠️  Not set (required for email template updates)'}`);

// Extract project ref
if (config.SUPABASE_URL) {
  const match = config.SUPABASE_URL.match(/https:\/\/([^.]+)\.supabase\.co/);
  if (match) {
    console.log(`\n📍 Project Reference: ${match[1]}`);
  }
}

console.log('\n');

if (!config.SUPABASE_ACCESS_TOKEN) {
  console.log('⚠️  To update email templates, add SUPABASE_ACCESS_TOKEN to env.json');
  console.log('   See ENV_SETUP.md for instructions\n');
} else {
  console.log('✅ Ready to update email templates!\n');
}
