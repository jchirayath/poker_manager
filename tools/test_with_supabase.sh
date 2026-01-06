#!/usr/bin/env bash
set -euo pipefail

if ! command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI not found. Install from https://supabase.com/docs/guides/cli." >&2
  exit 1
fi

# Ensure we run from repo root
cd "$(dirname "$0")/.."

# Push pending migrations
supabase db push

# Run dummy data test with destructive clear
CLEAR_DUMMY_DATA=true flutter test test/setup_dummy_data_test.dart --dart-define-from-file=env.json
