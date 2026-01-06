# Dummy Data Test Guide

This test seeds or validates Supabase data for local/integration use. It uses `env.json` for Supabase credentials and Supabase service role key.

## Prerequisites
- `env.json` present at repo root with `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
- Supabase tables migrated (see `supabase/migrations`).
- Flutter SDK available in PATH.

## Running the test
```bash
# Default: non-destructive (skip clearing), reuse existing records and validate counts
CLEAR_DUMMY_DATA=false flutter test test/setup_dummy_data_test.dart --dart-define-from-file=env.json

# Destructive: clear all related tables and auth users first, then reseed
CLEAR_DUMMY_DATA=true flutter test test/setup_dummy_data_test.dart --dart-define-from-file=env.json
```

## Behavior
- **Non-destructive (default)**: Does not delete data. Existing `@dummy.test` users are reused. Validation expects counts to be at least the seeded totals.
- **Destructive**: Clears transactions, settlements, participants, games, player statistics, group members, locations, groups, profiles, and any `@dummy.test` auth users, then seeds fresh data. Validation expects exact counts.

## Seeded data shape
- Users: 10 named dummy users with profiles and personal locations.
- Groups: 2 groups (6 members and 5 members, with one overlapping user).
- Locations: 10 personal addresses + 1 neutral group location.
- Games: 1 scheduled game in Group 1 at the neutral location with 3 participants and matching buy-in/cash-out transactions.

## Troubleshooting
- `AuthApiException code: email_exists` in non-destructive mode: safe to ignore; the test reuses existing users.
- Schema errors: ensure migrations are applied and `SUPABASE_SERVICE_ROLE_KEY` is correct.
- Connectivity issues: verify Supabase URL and network access.
