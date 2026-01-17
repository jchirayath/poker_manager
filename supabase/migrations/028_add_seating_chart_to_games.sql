-- =============================================
-- Add Seating Chart Feature to Games
-- Allows games to store randomized seating assignments
-- =============================================

-- =============================================
-- Add seating_chart column to games table
-- =============================================
ALTER TABLE public.games
ADD COLUMN IF NOT EXISTS seating_chart JSONB DEFAULT NULL;

COMMENT ON COLUMN public.games.seating_chart IS
  'Stores seating assignments as a JSON object mapping user_id to seat_number. Example: {"user-id-1": 1, "user-id-2": 2}';

-- =============================================
-- Create index for efficient querying
-- =============================================
CREATE INDEX IF NOT EXISTS idx_games_seating_chart
  ON public.games USING gin (seating_chart);
