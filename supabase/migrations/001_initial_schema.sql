-- =============================================
-- Poker Manager Database Schema
-- Initial Migration
-- =============================================

-- Enable UUID/crypto extensions (gen_random_uuid comes from pgcrypto)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

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
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create a computed column for full address display
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

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

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
    COALESCE(NEW.raw_user_meta_data->>'country', 'US'),
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
  total_buyin DECIMAL(10,2) DEFAULT 0,
  total_cashout DECIMAL(10,2) DEFAULT 0,
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
  amount DECIMAL(10,2) NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT
);

-- =============================================
-- TABLE: settlements
-- =============================================
CREATE TABLE IF NOT EXISTS public.settlements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  game_id UUID REFERENCES games(id) ON DELETE CASCADE NOT NULL,
  payer_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  payee_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  status TEXT CHECK (status IN ('pending', 'completed')) DEFAULT 'pending',
  completed_at TIMESTAMPTZ
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
-- ROW LEVEL SECURITY POLICIES
-- =============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE games ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_statistics ENABLE ROW LEVEL SECURITY;

-- =============================================
-- RLS POLICIES: profiles
-- =============================================

-- Users can read all profiles (for player search)
CREATE POLICY "Profiles are viewable by everyone"
  ON profiles FOR SELECT
  USING (true);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can only update their own profile
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- =============================================
-- RLS POLICIES: groups
-- =============================================

-- Users can view groups they're members of
CREATE POLICY "Users can view their groups"
  ON groups FOR SELECT
  USING (
    id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

-- Users can create groups
CREATE POLICY "Users can create groups"
  ON groups FOR INSERT
  WITH CHECK (created_by = auth.uid());

-- Group admins can update groups
CREATE POLICY "Group admins can update groups"
  ON groups FOR UPDATE
  USING (
    id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- =============================================
-- RLS POLICIES: group_members
-- =============================================

-- Users can view members of their groups
CREATE POLICY "Users can view group members"
  ON group_members FOR SELECT
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

-- Group admins can add members
CREATE POLICY "Group admins can add members"
  ON group_members FOR INSERT
  WITH CHECK (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Allow the group creator to add themselves as a member
CREATE POLICY "Group creator can add self"
  ON group_members FOR INSERT
  WITH CHECK (
    is_creator = TRUE
    AND user_id = auth.uid()
    AND group_id IN (
      SELECT id FROM groups WHERE created_by = auth.uid()
    )
  );

-- Group admins can promote/demote members
CREATE POLICY "Group admins can update member roles"
  ON group_members FOR UPDATE
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    -- Cannot demote the creator
    (is_creator = FALSE OR role = 'admin')
  );

-- =============================================
-- RLS POLICIES: games
-- =============================================

-- Users can view games in their groups
CREATE POLICY "Users can view group games"
  ON games FOR SELECT
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

-- Group members can create games
CREATE POLICY "Group members can create games"
  ON games FOR INSERT
  WITH CHECK (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

-- Group admins can update/delete games
CREATE POLICY "Group admins can modify games"
  ON games FOR UPDATE
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- =============================================
-- RLS POLICIES: game_participants
-- =============================================

-- Users can view participants in games they have access to
CREATE POLICY "Users can view game participants"
  ON game_participants FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM games 
      WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid()
      )
    )
  );

-- Users can join games in their groups
CREATE POLICY "Users can join games"
  ON game_participants FOR INSERT
  WITH CHECK (
    game_id IN (
      SELECT id FROM games 
      WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid()
      )
    )
  );

-- Users can update their own participation
CREATE POLICY "Users can update own participation"
  ON game_participants FOR UPDATE
  USING (user_id = auth.uid());

-- =============================================
-- RLS POLICIES: transactions
-- =============================================

-- Users can view transactions in games they have access to
CREATE POLICY "Users can view game transactions"
  ON transactions FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM games 
      WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid()
      )
    )
  );

-- Users can create transactions for games they're participating in
CREATE POLICY "Users can create transactions"
  ON transactions FOR INSERT
  WITH CHECK (
    game_id IN (
      SELECT id FROM games 
      WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid()
      )
    )
  );

-- =============================================
-- RLS POLICIES: settlements
-- =============================================

-- Users can view settlements for games they have access to
CREATE POLICY "Users can view settlements"
  ON settlements FOR SELECT
  USING (
    game_id IN (
      SELECT id FROM games 
      WHERE group_id IN (
        SELECT group_id FROM group_members 
        WHERE user_id = auth.uid()
      )
    )
  );

-- Group admins can create settlements
CREATE POLICY "Admins can create settlements"
  ON settlements FOR INSERT
  WITH CHECK (
    game_id IN (
      SELECT g.id FROM games g
      JOIN group_members gm ON gm.group_id = g.group_id
      WHERE gm.user_id = auth.uid() AND gm.role = 'admin'
    )
  );

-- Users can mark their settlements as completed
CREATE POLICY "Users can update own settlements"
  ON settlements FOR UPDATE
  USING (payer_id = auth.uid() OR payee_id = auth.uid());

-- =============================================
-- RLS POLICIES: player_statistics
-- =============================================

-- Users can view statistics for their groups
CREATE POLICY "Users can view group statistics"
  ON player_statistics FOR SELECT
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

-- System can insert/update statistics (handled by triggers)
CREATE POLICY "System can manage statistics"
  ON player_statistics FOR ALL
  USING (true)
  WITH CHECK (true);

-- =============================================
-- DATABASE FUNCTIONS
-- =============================================

-- Update Player Statistics (Trigger Function)
CREATE OR REPLACE FUNCTION update_player_statistics()
RETURNS TRIGGER AS $$
BEGIN
  -- Update statistics when game is completed
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    -- Update statistics for all participants
    INSERT INTO player_statistics (user_id, group_id, games_played, total_buyin, total_cashout, net_profit, biggest_win, biggest_loss)
    SELECT 
      gp.user_id,
      g.group_id,
      1,
      gp.total_buyin,
      gp.total_cashout,
      gp.net_result,
      CASE WHEN gp.net_result > 0 THEN gp.net_result ELSE 0 END,
      CASE WHEN gp.net_result < 0 THEN gp.net_result ELSE 0 END
    FROM game_participants gp
    JOIN games g ON g.id = gp.game_id
    WHERE gp.game_id = NEW.id
    ON CONFLICT (user_id, group_id) DO UPDATE SET
      games_played = player_statistics.games_played + 1,
      total_buyin = player_statistics.total_buyin + EXCLUDED.total_buyin,
      total_cashout = player_statistics.total_cashout + EXCLUDED.total_cashout,
      net_profit = player_statistics.net_profit + EXCLUDED.net_profit,
      biggest_win = GREATEST(player_statistics.biggest_win, EXCLUDED.biggest_win),
      biggest_loss = LEAST(player_statistics.biggest_loss, EXCLUDED.biggest_loss),
      updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_stats_on_game_complete
  AFTER UPDATE ON games
  FOR EACH ROW
  EXECUTE FUNCTION update_player_statistics();

-- Calculate Settlement (RPC Function)
CREATE OR REPLACE FUNCTION calculate_settlement(game_uuid UUID)
RETURNS TABLE(payer UUID, payee UUID, amount DECIMAL) AS $$
DECLARE
  participant RECORD;
  creditor RECORD;
  debtor RECORD;
  transfer_amount DECIMAL;
BEGIN
  -- Create temporary table for net positions
  CREATE TEMP TABLE IF NOT EXISTS net_positions AS
  SELECT 
    user_id,
    net_result
  FROM game_participants
  WHERE game_id = game_uuid
  ORDER BY net_result;

  -- Process settlements using greedy algorithm
  FOR debtor IN 
    SELECT user_id, net_result 
    FROM net_positions 
    WHERE net_result < 0 
    ORDER BY net_result ASC
  LOOP
    FOR creditor IN 
      SELECT user_id, net_result 
      FROM net_positions 
      WHERE net_result > 0 
      ORDER BY net_result DESC
    LOOP
      IF debtor.net_result >= 0 THEN
        EXIT;
      END IF;

      transfer_amount := LEAST(ABS(debtor.net_result), creditor.net_result);
      
      IF transfer_amount > 0 THEN
        payer := debtor.user_id;
        payee := creditor.user_id;
        amount := transfer_amount;
        
        -- Update temporary balances
        UPDATE net_positions 
        SET net_result = net_result + transfer_amount 
        WHERE user_id = debtor.user_id;
        
        UPDATE net_positions 
        SET net_result = net_result - transfer_amount 
        WHERE user_id = creditor.user_id;
        
        -- Update variables for next iteration
        debtor.net_result := debtor.net_result + transfer_amount;
        creditor.net_result := creditor.net_result - transfer_amount;
        
        RETURN NEXT;
      END IF;
    END LOOP;
  END LOOP;

  DROP TABLE IF EXISTS net_positions;
  RETURN;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- REALTIME SUBSCRIPTIONS
-- =============================================

-- Enable realtime for live updates
ALTER PUBLICATION supabase_realtime ADD TABLE game_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE settlements;

-- =============================================
-- INDEXES FOR PERFORMANCE
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
CREATE INDEX IF NOT EXISTS idx_player_statistics_user_id ON player_statistics(user_id);
CREATE INDEX IF NOT EXISTS idx_player_statistics_group_id ON player_statistics(group_id);

-- =============================================
-- STORAGE BUCKETS (run separately in Supabase dashboard)
-- =============================================

-- Note: Storage buckets and their policies need to be created via Supabase dashboard or CLI
-- Buckets needed:
-- 1. avatars (public)
-- 2. group-images (public)

-- Storage policy for avatars (apply after bucket creation):
-- CREATE POLICY "Users can upload own avatar"
--   ON storage.objects FOR INSERT
--   WITH CHECK (
--     bucket_id = 'avatars' AND 
--     auth.uid()::text = (storage.foldername(name))[1]
--   );
