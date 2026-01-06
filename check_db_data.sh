#!/bin/bash

# Extract env values  
SUPABASE_SERVICE_KEY=$(grep "SUPABASE_SERVICE_ROLE_KEY" env.json | sed 's/.*: "\(.*\)".*/\1/')

echo "Checking profiles..."
curl -s "https://evmicivjkcspqpnbjcus.supabase.co/rest/v1/profiles?select=id,first_name,last_name,email" \
  -H "apikey: $SUPABASE_SERVICE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY"

echo -e "\n\nChecking groups..."
curl -s "https://evmicivjkcspqpnbjcus.supabase.co/rest/v1/groups?select=id,name" \
  -H "apikey: $SUPABASE_SERVICE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY"

echo -e "\n\nChecking games..."
curl -s "https://evmicivjkcspqpnbjcus.supabase.co/rest/v1/games?select=id,name,status" \
  -H "apikey: $SUPABASE_SERVICE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY"
