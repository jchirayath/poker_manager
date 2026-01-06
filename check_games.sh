#!/bin/bash

# Extract env values
SUPABASE_ANON_KEY=$(grep "SUPABASE_ANON_KEY" env.json | sed 's/.*: "\(.*\)".*/\1/')

# Query games
curl -s "https://evmicivjkcspqpnbjcus.supabase.co/rest/v1/games?select=name,status" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY"
