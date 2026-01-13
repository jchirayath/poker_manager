-- =============================================
-- Poker Manager Database Schema - Consolidated
-- Consolidated from 25 individual migrations
-- =============================================

-- Enable UUID/crypto extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================
-- UTILITY FUNCTIONS
-- =============================================

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- TABLE: profiles
-- =============================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  avatar_url TEXT,
  phone_number TEXT,
  street_address TEXT,
  city TEXT,
  state_province TEXT,
  postal_code TEXT,
  country TEXT NOT NULL,
  is_local_user BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Get full address display (must be after profiles table)
CREATE OR REPLACE FUNCTION get_full_address(p profiles)
RETURNS TEXT AS $$
BEGIN
  RETURN CONCAT_WS(', ',
    NULLIF(p.street_address, ''),
    NULLIF(p.city, ''),
    NULLIF(p.state_province, ''),
    NULLIF(p.postal_code, ''),
    NULLIF(p.country, '')
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- Auto-create a profile when a new auth user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    username,
    first_name,
    last_name,
    country,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'username', NULL),
    COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'country', 'United States'),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- =============================================
-- TABLE: groups
-- =============================================
CREATE TABLE IF NOT EXISTS public.groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  privacy TEXT CHECK (privacy IN ('private', 'public')) DEFAULT 'private',
  default_currency TEXT DEFAULT 'USD',
  default_buyin DECIMAL(10,2),
  additional_buyin_values DECIMAL(10,2)[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_groups_updated_at
  BEFORE UPDATE ON groups
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- TABLE: group_members
-- =============================================
CREATE TABLE IF NOT EXISTS public.group_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  role TEXT CHECK (role IN ('admin', 'member')) DEFAULT 'member',
  is_creator BOOLEAN DEFAULT FALSE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(group_id, user_id)
);

-- Trigger to set creator as admin
CREATE OR REPLACE FUNCTION set_creator_as_admin()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_creator = TRUE THEN
    NEW.role := 'admin';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ensure_creator_is_admin
  BEFORE INSERT OR UPDATE ON group_members
  FOR EACH ROW
  EXECUTE FUNCTION set_creator_as_admin();

-- =============================================
-- TABLE: locations
-- =============================================
CREATE TABLE IF NOT EXISTS public.locations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  street_address TEXT NOT NULL,
  city TEXT,
  state_province TEXT,
  postal_code TEXT,
  country TEXT NOT NULL,
  label TEXT,
  is_primary BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT has_group_or_profile CHECK (group_id IS NOT NULL OR profile_id IS NOT NULL),
  UNIQUE(group_id, profile_id, label)
);

CREATE TRIGGER update_locations_updated_at
  BEFORE UPDATE ON locations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_locations_group_id ON locations(group_id);
CREATE INDEX IF NOT EXISTS idx_locations_profile_id ON locations(profile_id);
CREATE INDEX IF NOT EXISTS idx_locations_group_profile ON locations(group_id, profile_id);

-- =============================================
-- TABLE: games
-- =============================================
CREATE TABLE IF NOT EXISTS public.games (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  game_date TIMESTAMPTZ NOT NULL,
  location TEXT,
  location_host_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  max_players INTEGER,
  currency TEXT,
  buyin_amount DECIMAL(10,2),
  additional_buyin_values DECIMAL(10,2)[] DEFAULT '{}',
  status TEXT CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')) DEFAULT 'scheduled',
  recurrence_pattern JSONB,
  parent_game_id UUID REFERENCES games(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER update_games_updated_at
  BEFORE UPDATE ON games
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- TABLE: game_participants
-- =============================================
CREATE TABLE IF NOT EXISTS public.game_participants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  game_id UUID REFERENCES games(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  rsvp_status TEXT CHECK (rsvp_status IN ('going', 'not_going', 'maybe')) DEFAULT 'maybe',
  total_buyin DECIMAL(10,2) DEFAULT 0 CHECK (total_buyin >= 0),
  total_cashout DECIMAL(10,2) DEFAULT 0 CHECK (total_cashout >= 0),
  net_result DECIMAL(10,2) GENERATED ALWAYS AS (total_cashout - total_buyin) STORED,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(game_id, user_id)
);

-- =============================================
-- TABLE: transactions
-- =============================================
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  game_id UUID REFERENCES games(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT CHECK (type IN ('buyin', 'cashout')) NOT NULL,
  amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT
);

-- =============================================
-- TABLE: settlements
-- =============================================
CREATE TABLE IF NOT EXISTS public.settlements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  game_id UUID REFERENCES games(id) ON DELETE CASCADE NOT NULL,
  from_user_id UUID REFERENCES profiles(id) ON DELETE RESTRICT NOT NULL,
  to_user_id UUID REFERENCES profiles(id) ON DELETE RESTRICT NOT NULL,
  amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  payment_method VARCHAR(50) DEFAULT 'cash' CHECK (payment_method IN ('cash', 'paypal', 'venmo')),
  status TEXT CHECK (status IN ('pending', 'completed')) DEFAULT 'pending',
  settled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(game_id, from_user_id, to_user_id)
);

-- =============================================
-- TABLE: player_statistics
-- =============================================
CREATE TABLE IF NOT EXISTS public.player_statistics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE NOT NULL,
  games_played INTEGER DEFAULT 0,
  total_buyin DECIMAL(10,2) DEFAULT 0,
  total_cashout DECIMAL(10,2) DEFAULT 0,
  net_profit DECIMAL(10,2) DEFAULT 0,
  biggest_win DECIMAL(10,2) DEFAULT 0,
  biggest_loss DECIMAL(10,2) DEFAULT 0,
  current_streak INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, group_id)
);

CREATE TRIGGER update_player_statistics_updated_at
  BEFORE UPDATE ON player_statistics
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- TABLE: group_invitations
-- =============================================
CREATE TABLE IF NOT EXISTS public.group_invitations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  invited_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  invited_name TEXT,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'cancelled', 'expired')),
  token TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days')
);

CREATE TRIGGER update_group_invitations_updated_at
  BEFORE UPDATE ON group_invitations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_group_invitations_group_id ON public.group_invitations(group_id);
CREATE INDEX IF NOT EXISTS idx_group_invitations_email ON public.group_invitations(email);
CREATE INDEX IF NOT EXISTS idx_group_invitations_status ON public.group_invitations(status);
CREATE INDEX IF NOT EXISTS idx_group_invitations_token ON public.group_invitations(token);

-- =============================================
-- ALL INDEXES FOR PERFORMANCE
-- =============================================

CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_games_group_id ON games(group_id);
CREATE INDEX IF NOT EXISTS idx_games_game_date ON games(game_date);
CREATE INDEX IF NOT EXISTS idx_game_participants_game_id ON game_participants(game_id);
CREATE INDEX IF NOT EXISTS idx_game_participants_user_id ON game_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_game_id ON transactions(game_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_settlements_game_id ON settlements(game_id);
CREATE INDEX IF NOT EXISTS idx_settlements_users ON settlements(from_user_id, to_user_id);
CREATE INDEX IF NOT EXISTS idx_settlements_settled_at ON settlements(settled_at DESC);
CREATE INDEX IF NOT EXISTS idx_player_statistics_user_id ON player_statistics(user_id);
CREATE INDEX IF NOT EXISTS idx_player_statistics_group_id ON player_statistics(group_id);

-- =============================================
-- REALTIME SUBSCRIPTIONS
-- =============================================

ALTER PUBLICATION supabase_realtime ADD TABLE game_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE settlements;

-- =============================================
-- DATA FIXES (from migration 002)
-- =============================================

-- Fix country values for consistency
UPDATE public.profiles 
SET country = 'United States' 
WHERE country IN ('US', 'USA', 'U.S.', 'U.S.A.');

UPDATE public.profiles 
SET country = 'United Kingdom' 
WHERE country IN ('UK', 'GB');

UPDATE public.profiles 
SET country = 'Canada' 
WHERE country = 'CA';
