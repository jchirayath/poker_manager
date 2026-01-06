-- Create settlements table to track payment settlements between players
CREATE TABLE IF NOT EXISTS public.settlements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  game_id UUID NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,
  from_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  to_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
  payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('cash', 'paypal', 'venmo')),
  settled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  
  -- Ensure each settlement between two players is recorded once per game
  UNIQUE(game_id, from_user_id, to_user_id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_settlements_game_id ON public.settlements(game_id);
CREATE INDEX IF NOT EXISTS idx_settlements_users ON public.settlements(from_user_id, to_user_id);
CREATE INDEX IF NOT EXISTS idx_settlements_settled_at ON public.settlements(settled_at DESC);

-- Enable RLS
ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view settlements for games they participate in
CREATE POLICY "Users can view settlements for their games"
  ON public.settlements
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.game_participants
      WHERE game_participants.game_id = settlements.game_id
      AND game_participants.user_id = auth.uid()
    )
  );

-- RLS Policy: Users can insert settlements only if they are in the game
CREATE POLICY "Users can record settlements for games they participate in"
  ON public.settlements
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.game_participants
      WHERE game_participants.game_id = settlements.game_id
      AND game_participants.user_id = auth.uid()
    )
  );

-- RLS Policy: Users can update settlements for games they participate in
CREATE POLICY "Users can update settlements for games they participate in"
  ON public.settlements
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.game_participants
      WHERE game_participants.game_id = settlements.game_id
      AND game_participants.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.game_participants
      WHERE game_participants.game_id = settlements.game_id
      AND game_participants.user_id = auth.uid()
    )
  );
