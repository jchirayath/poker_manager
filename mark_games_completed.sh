#!/bin/bash

# This script updates existing games to have varied statuses for testing

# Extract env values  
SUPABASE_SERVICE_KEY=$(grep "SUPABASE_SERVICE_ROLE_KEY" env.json | sed 's/.*: "\(.*\)".*/\1/')

echo "Fetching existing games..."
GAMES_JSON=$(curl -s "https://evmicivjkcspqpnbjcus.supabase.co/rest/v1/games?select=id,name,status,game_date&order=game_date.desc&limit=10" \
  -H "apikey: $SUPABASE_SERVICE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY")

echo "$GAMES_JSON" | python3 -c "
import sys, json
games = json.load(sys.stdin)
print(f'Found {len(games)} games')
for i, game in enumerate(games):
    print(f\"{i+1}. {game['name']} - {game['status']} - {game['game_date']}\")
"

if [ -z "$GAMES_JSON" ] || [ "$GAMES_JSON" = "[]" ]; then
  echo "No games found. Please create some games in the app first."
  exit 1
fi

echo ""
echo "Updating first 2 games to 'completed' status..."

# Get first 2 game IDs
GAME_IDS=$(echo "$GAMES_JSON" | python3 -c "import sys, json; games = json.load(sys.stdin); print('\n'.join([g['id'] for g in games[:2]]))")

COUNT=0
for GAME_ID in $GAME_IDS; do
  COUNT=$((COUNT + 1))
  echo "Updating game $COUNT ($GAME_ID) to completed..."
  
  curl -s -X PATCH "https://evmicivjkcspqpnbjcus.supabase.co/rest/v1/games?id=eq.$GAME_ID" \
    -H "apikey: $SUPABASE_SERVICE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" \
    -d '{"status": "completed"}' > /dev/null
done

echo ""
echo "✅ Done! $COUNT games updated to 'completed' status."
echo "Now refresh your app to see the Past Games section."
