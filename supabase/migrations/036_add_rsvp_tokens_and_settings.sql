-- Migration: Add RSVP token system and email settings
-- Created: 2026-01-18
-- Description: Adds RSVP token table for magic link authentication and group settings for auto-send RSVP emails

-- 1. Create rsvp_tokens table for magic link authentication
CREATE TABLE IF NOT EXISTS public.rsvp_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Ensure one active token per user per game
    CONSTRAINT unique_active_token UNIQUE (game_id, user_id)
);

-- 2. Add index for fast token lookup (only unused tokens)
-- Note: Cannot include expires_at > NOW() in partial index as NOW() is not IMMUTABLE
-- Expiration check must be done in application queries
CREATE INDEX idx_rsvp_tokens_token ON public.rsvp_tokens(token) WHERE used_at IS NULL;
CREATE INDEX idx_rsvp_tokens_game_id ON public.rsvp_tokens(game_id);
CREATE INDEX idx_rsvp_tokens_user_id ON public.rsvp_tokens(user_id);

-- 3. Add auto_send_rsvp_emails setting to groups table
ALTER TABLE public.groups
ADD COLUMN IF NOT EXISTS auto_send_rsvp_emails BOOLEAN NOT NULL DEFAULT true;

-- 4. Add comment for documentation
COMMENT ON TABLE public.rsvp_tokens IS 'Stores magic link tokens for RSVP functionality, allowing users to RSVP via email without authentication';
COMMENT ON COLUMN public.groups.auto_send_rsvp_emails IS 'When true, automatically sends RSVP emails to all group members when a new game is created';

-- 5. Enable Row Level Security on rsvp_tokens
ALTER TABLE public.rsvp_tokens ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies for rsvp_tokens
-- Service role can do anything (for Supabase Functions)
CREATE POLICY "Service role can manage all tokens"
    ON public.rsvp_tokens
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Authenticated users can view their own tokens (for debugging/UI)
CREATE POLICY "Users can view their own tokens"
    ON public.rsvp_tokens
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Anon users cannot directly access tokens (they use the token via Supabase Function)
-- This prevents token enumeration attacks

-- 7. Add function to clean up expired tokens (run periodically via cron)
CREATE OR REPLACE FUNCTION public.cleanup_expired_rsvp_tokens()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.rsvp_tokens
    WHERE expires_at < NOW() - INTERVAL '7 days'; -- Keep expired tokens for 7 days for audit

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

COMMENT ON FUNCTION public.cleanup_expired_rsvp_tokens IS 'Removes RSVP tokens that expired more than 7 days ago';

-- 8. Grant necessary permissions
GRANT SELECT ON public.rsvp_tokens TO authenticated;
GRANT ALL ON public.rsvp_tokens TO service_role;
