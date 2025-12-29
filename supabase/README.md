# Supabase Database Setup

## Apply Migration

### Option 1: Using Supabase CLI (Recommended)

1. Install Supabase CLI if you haven't already:
```bash
brew install supabase/tap/supabase
```

2. Link your project:
```bash
supabase link --project-ref YOUR_PROJECT_REF
```

3. Apply the migration:
```bash
supabase db push
```

### Option 2: Using Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Click **New Query**
4. Copy the contents of `migrations/001_initial_schema.sql`
5. Paste and click **Run**

## Storage Buckets Setup

After applying the migration, create storage buckets in the Supabase dashboard:

### 1. Create Buckets

Go to **Storage** in your Supabase dashboard and create:
- `avatars` (public bucket)
- `group-images` (public bucket)

### 2. Apply Storage Policies

For the **avatars** bucket, go to **Storage > avatars > Policies** and add:

```sql
-- Users can upload their own avatars
CREATE POLICY "Users can upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can view all avatars
CREATE POLICY "Avatars are publicly accessible"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- Users can update their own avatars
CREATE POLICY "Users can update own avatar"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can delete their own avatars
CREATE POLICY "Users can delete own avatar"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

For the **group-images** bucket:

```sql
-- Group admins can upload group images
CREATE POLICY "Admins can upload group images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'group-images'
  );

-- Everyone can view group images
CREATE POLICY "Group images are publicly accessible"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'group-images');

-- Group admins can update group images
CREATE POLICY "Admins can update group images"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'group-images');

-- Group admins can delete group images
CREATE POLICY "Admins can delete group images"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'group-images');
```

## Database Schema Overview

The migration creates:

### Tables
- `profiles` - User profile information
- `groups` - Poker groups
- `group_members` - Group membership and roles
- `games` - Scheduled and completed games
- `game_participants` - Player participation in games
- `transactions` - Buy-in and cash-out transactions
- `settlements` - Payment settlements between players
- `player_statistics` - Aggregated player stats per group

### Functions
- `get_full_address(profiles)` - Returns formatted full address
- `update_updated_at_column()` - Trigger function for timestamp updates
- `set_creator_as_admin()` - Ensures group creators are admins
- `update_player_statistics()` - Updates stats when game completes
- `calculate_settlement(UUID)` - Calculates optimized payment settlements

### Row Level Security
All tables have RLS enabled with appropriate policies for:
- Profile viewing and editing
- Group access control
- Game management
- Transaction tracking
- Settlement management

## Verify Installation

After applying the migration, verify in SQL Editor:

```sql
-- Check all tables were created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_name;

-- Verify RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';

-- Check indexes
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

## Testing the Setup

Create a test profile after signing up:

```sql
-- This should work after a user signs up via your app
INSERT INTO profiles (id, email, first_name, last_name, country)
VALUES (auth.uid(), 'test@example.com', 'Test', 'User', 'USA');
```

## Troubleshooting

### Migration fails with "relation already exists"
The migration uses `IF NOT EXISTS` clauses, so it's safe to re-run. If you need to start fresh:

```sql
-- WARNING: This deletes all data
DROP TABLE IF EXISTS player_statistics CASCADE;
DROP TABLE IF EXISTS settlements CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS game_participants CASCADE;
DROP TABLE IF EXISTS games CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS groups CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
```

### RLS Policy errors
Make sure you're testing with an authenticated user. Use `auth.uid()` in the SQL editor won't work unless you're authenticated.

### Storage bucket policies not working
Ensure the buckets are created first, then apply the policies in the Storage UI or via SQL.
