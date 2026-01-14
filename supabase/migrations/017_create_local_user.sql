CREATE OR REPLACE FUNCTION create_local_user(
  p_email TEXT,
  p_first_name TEXT,
  p_last_name TEXT,
  p_group_id UUID,
  p_created_by UUID
)
RETURNS UUID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := gen_random_uuid();
  INSERT INTO profiles (
    id,
    email,
    first_name,
    last_name,
    country,
    is_local_user,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    p_email,
    p_first_name,
    p_last_name,
    'United States',
    TRUE,
    NOW(),
    NOW()
  )
  ON CONFLICT (email) DO UPDATE
  SET is_local_user = TRUE
  RETURNING id INTO v_user_id;

  IF p_group_id IS NOT NULL THEN
    INSERT INTO group_members (
      group_id,
      user_id,
      role,
      joined_at
    ) VALUES (
      p_group_id,
      v_user_id,
      'member',
      NOW()
    )
    ON CONFLICT (group_id, user_id) DO NOTHING;
  END IF;

  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
