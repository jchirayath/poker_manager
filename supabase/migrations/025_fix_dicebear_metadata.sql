-- =============================================
-- Fix DiceBear avatar URLs to exclude metadata
-- Migration 025
-- =============================================

-- Update profiles table - add excludeMetadata parameter to DiceBear URLs
UPDATE public.profiles
SET avatar_url = avatar_url || '&excludeMetadata=true'
WHERE avatar_url LIKE '%api.dicebear.com%'
  AND avatar_url NOT LIKE '%excludeMetadata=true%';

-- Update groups table - add excludeMetadata parameter to DiceBear URLs
UPDATE public.groups
SET avatar_url = avatar_url || '&excludeMetadata=true'
WHERE avatar_url LIKE '%api.dicebear.com%'
  AND avatar_url NOT LIKE '%excludeMetadata=true%';

-- Report results
DO $$
DECLARE
  profile_count INTEGER;
  group_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO profile_count 
  FROM public.profiles 
  WHERE avatar_url LIKE '%api.dicebear.com%excludeMetadata=true%';
  
  SELECT COUNT(*) INTO group_count 
  FROM public.groups 
  WHERE avatar_url LIKE '%api.dicebear.com%excludeMetadata=true%';
  
  RAISE NOTICE 'Fixed % profile avatars', profile_count;
  RAISE NOTICE 'Fixed % group avatars', group_count;
END $$;
