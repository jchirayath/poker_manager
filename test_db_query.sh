#!/bin/bash

# Source the env file
source <(grep -E "SUPABASE_URL|SUPABASE_ANON_KEY|SUPABASE_SERVICE_ROLE_KEY" env.json | sed 's/[",]//g; s/: /=/g')

echo "Testing group_members query..."

# Get first user ID from profiles
USER_ID=$(curl -s -X GET \
  "https://evmicivjkcspqpnbjcus.supabase.co/rest/v1/profiles?select=id&limit=1" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" | jq -r '.[0].id // empty')

echo "Found user: $USER_ID"

# Query group_members for this user
curl -s -X GET \
  "https://evmicivjkcspqpnbjcus.supabase.co/rest/v1/group_members?user_id=eq.$USER_ID&select=*,groups(*)" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" | jq '.'
