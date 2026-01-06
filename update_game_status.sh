#!/bin/bash

# Extract env values
SUPABASE_ANON_KEY=$(grep "SUPABASE_ANON_KEY" env.json | sed 's/.*: "\(.*\)".*/\1/')

# Get the first 3 games
GAME_IDS=$(curl -s "https://evmicivjkcspqpnbjcus.supabase.co/rest/v1/games?select=id&order=created_at.desc&limit=3" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

echo "Found games:"
echo "$GAME_IDS"

# Update the first game to completed status
FIRST_GAME=$(echo "$GAME_IDS" | head -n 1)
echo ""
echo "Updating game $FIRST_GAME to completed status..."

curl -X PATCH "https://evmicivjkcspqpnbjcus.supabase.co/rest/v1/games?id=eq.$FIRST_GAME" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{"status": "completed"}'

echo ""
echo "Done! Check your app now."
