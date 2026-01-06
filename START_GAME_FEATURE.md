# Start Game Feature Documentation

## Overview
The "Start Game" feature allows users to quickly start a poker game by either selecting an existing scheduled game from their group or creating a new one on the fly. The feature includes a loading indicator (spinning wheel) while processing the game start.

## Features

### 1. **Default Games Display**
When users access the "Start Game" screen, they see:
- A list of all **scheduled games** for the selected group
- Each game card shows:
  - Game name
  - Date and time
  - Location (if set)
  - Buy-in amount and currency
  - A "Start" button for quick action

### 2. **Game Creation**
If no scheduled games are available, users can:
- Create a new game directly from the Start Game screen
- Option button: "Create New Game Instead" or "Create New Game"
- Seamlessly transitions to the full `CreateGameScreen` with all customization options

### 3. **Loading State**
When starting a game, users see:
- A centered circular progress indicator (spinning wheel)
- Status text: "Starting game..."
- This provides visual feedback while the game status is being updated to 'in_progress'

### 4. **Error Handling**
- Error states display clearly with retry option
- User-friendly error messages
- Automatic state recovery with retry button

## Implementation Details

### New Files Created
- **[lib/features/games/presentation/screens/start_game_screen.dart](lib/features/games/presentation/screens/start_game_screen.dart)** - Main screen for starting games

### Updated Files
1. **[lib/features/games/presentation/providers/games_provider.dart](lib/features/games/presentation/providers/games_provider.dart)**
   - Added `defaultGroupGamesProvider` - filters scheduled games for quick access
   - Added `startGameProvider` - Riverpod notifier for game start state management
   - Added `StartGameNotifier` class with two methods:
     - `startExistingGame()` - Changes game status to 'in_progress'
     - `createAndStartGame()` - Creates new game and starts it immediately

2. **[lib/features/games/data/repositories/games_repository.dart](lib/features/games/data/repositories/games_repository.dart)**
   - Added `updateGameStatus()` method - Updates any game's status in Supabase

3. **[lib/features/games/presentation/screens/games_list_screen.dart](lib/features/games/presentation/screens/games_list_screen.dart)**
   - Added import for `start_game_screen.dart`
   - Updated FAB to show menu with "Start Game" and "Create Game" options
   - Updated empty state to include "Start Game" button
   - Added `_showGameActionMenu()` method for bottom sheet menu

## Usage

### For Users
1. Navigate to a group's games
2. Tap the FAB (+) button
3. Select "Start Game" from the menu
4. Choose from available scheduled games OR create a new one
5. Tap "Start" button on selected game
6. See the spinning wheel while game status updates
7. Game automatically transitions to 'in_progress'

### For Developers

#### Navigating to Start Game Screen
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => StartGameScreen(groupId: groupId),
  ),
);
```

#### Starting an Existing Game
```dart
final startGameNotifier = ref.read(startGameProvider.notifier);
final result = await startGameNotifier.startExistingGame(gameId);
```

#### Creating and Starting a Game
```dart
final startGameNotifier = ref.read(startGameProvider.notifier);
final result = await startGameNotifier.createAndStartGame(
  groupId: groupId,
  name: 'Friday Night Poker',
  gameDate: DateTime.now(),
  currency: 'USD',
  buyinAmount: 50.0,
  additionalBuyinValues: [100.0, 200.0],
  participantUserIds: ['user1', 'user2'],
);
```

## State Management Flow

### Riverpod Providers
```
defaultGroupGamesProvider
  ├─ Watches: gamesRepositoryProvider
  └─ Returns: List<GameModel> (filtered by status='scheduled')

startGameProvider (Notifier)
  ├─ Manages: AsyncValue<GameModel?>
  ├─ Methods:
  │  ├─ startExistingGame(gameId) → updates status to 'in_progress'
  │  ├─ createAndStartGame(...) → creates new game
  │  └─ reset() → clears state
  └─ States: loading → data/error
```

## Database Updates
When a game is started, the Supabase `games` table is updated:
```dart
UPDATE games SET status = 'in_progress' WHERE id = '{gameId}'
```

The game model is refreshed and returned with updated status.

## UI/UX Flow Diagram
```
Games List Screen
    ↓
[FAB Button] → Bottom Sheet Menu
    ├─ Start Game → Start Game Screen
    │              ├─ Load Default Games (loading wheel)
    │              ├─ Show Game List (if available)
    │              │  └─ Click "Start" → Loading Wheel → Success/Error
    │              └─ "Create New Game" → Full Create Game Form
    │
    └─ Create Game → Create Game Screen (full form)
```

## Testing Checklist
- [ ] Verify default games load with loading indicator
- [ ] Test starting an existing game shows spinning wheel
- [ ] Verify game status updates to 'in_progress'
- [ ] Test creating new game from Start Game screen
- [ ] Verify error handling and retry functionality
- [ ] Test empty state when no games available
- [ ] Verify back navigation works properly
- [ ] Test with multiple games to verify filtering

## Future Enhancements
- Add game search/filter in Start Game screen
- Add quick setup defaults (buy-in, location) from group settings
- Add ability to edit game details before starting
- Add participant auto-selection based on group members
- Add game presets/templates for recurring games
