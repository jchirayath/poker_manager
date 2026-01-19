# RSVP Feature Documentation

## Overview

The RSVP feature allows players to respond to game invitations via email or the mobile app. Admins can see who's attending, and players can update their status at any time.

## Features

### 1. Email Invitations with Magic Links
- Players receive email invitations when games are created
- One-click RSVP via magic links (no login required)
- Three response options: 👍 Going, 👌 Maybe, 👎 Can't Make It
- Emails include game details: date, time, location, buy-in

### 2. In-App RSVP Management
- Users can update their RSVP status from the game detail screen
- RSVP status badges appear next to player names
- Real-time RSVP count summary (Going/Maybe/Not Going)

### 3. Admin Controls
- Manual RSVP email trigger from game detail screen
- Group-level setting to auto-send emails on game creation
- View RSVP summary for all participants

### 4. Auto-Selection (Future Enhancement)
- When players RSVP "Going", they are automatically added as participants
- Admins can remove players if needed

## Database Schema

### New Table: `rsvp_tokens`
```sql
CREATE TABLE public.rsvp_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_active_token UNIQUE (game_id, user_id)
);
```

- Stores secure tokens for magic link authentication
- Tokens expire after 30 days
- One active token per user per game
- Indexes on `token`, `game_id`, `user_id` for fast lookups

### Updated: `groups` Table
```sql
ALTER TABLE public.groups
ADD COLUMN auto_send_rsvp_emails BOOLEAN NOT NULL DEFAULT true;
```

- Controls whether RSVP emails are sent automatically on game creation
- Defaults to `true` for new groups

### Existing: `game_participants` Table
The RSVP status is stored in the existing `game_participants` table:
- `rsvp_status`: 'going' | 'not_going' | 'maybe'
- Already supported in `GameParticipantModel`

## Supabase Functions

### 1. `send-rsvp-emails`
**Location:** `supabase/functions/send-rsvp-emails/index.ts`

**Purpose:** Sends RSVP email invitations to group members

**Request:**
```json
{
  "gameId": "uuid",
  "userId": "uuid" // Optional: if provided, sends to one user only
}
```

**Process:**
1. Fetches game details (name, date, location, buy-in)
2. Fetches group members (or specific user)
3. Generates unique tokens for each recipient
4. Inserts/updates tokens in `rsvp_tokens` table
5. Sends HTML emails via Resend API
6. Returns success/failure status for each email

**Environment Variables Required:**
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RESEND_API_KEY`

### 2. `handle-rsvp`
**Location:** `supabase/functions/handle-rsvp/index.ts`

**Purpose:** Processes RSVP via magic link

**Request:**
```
GET /handle-rsvp?token=<token>&status=<going|maybe|not_going>
```

**Process:**
1. Validates token (checks expiration, existence)
2. Upserts `game_participants` record with new RSVP status
3. Marks token as used
4. Returns HTML success/error page

**Response:** HTML page confirming RSVP or showing error

## Flutter Implementation

### Models

#### Updated: `GroupModel`
**Location:** `lib/features/groups/data/models/group_model.dart`

Added field:
```dart
@JsonKey(name: 'auto_send_rsvp_emails') @Default(true) bool autoSendRsvpEmails
```

#### Existing: `GameParticipantModel`
**Location:** `lib/features/games/data/models/game_participant_model.dart`

Already includes:
```dart
String rsvpStatus; // 'going' | 'not_going' | 'maybe'
bool get isGoing => rsvpStatus == rsvpGoing;
bool get isNotGoing => rsvpStatus == rsvpNotGoing;
bool get isMaybe => rsvpStatus == rsvpMaybe;
String get displayRsvpStatus => ...
```

### Repository Methods

#### `GamesRepository`
**Location:** `lib/features/games/data/repositories/games_repository.dart`

**New Method:**
```dart
Future<Result<void>> sendRsvpEmails({
  required String gameId,
  String? userId, // If null, sends to all group members
})
```
- Calls Supabase Function `send-rsvp-emails`
- Returns `Result<void>` (Success/Failure)

**Existing Method:**
```dart
Future<Result<void>> updateRSVP({
  required String gameId,
  required String userId,
  required String rsvpStatus,
})
```
- Upserts `game_participants` record
- Used by in-app RSVP updates

### UI Components

#### `RsvpStatusBadge`
**Location:** `lib/features/games/presentation/widgets/game_detail/rsvp_widgets.dart`

Displays RSVP status with icon and text:
- 👍 Going (Green)
- 👌 Maybe (Orange)
- 👎 Not Going (Red)

**Props:**
- `rsvpStatus`: Current RSVP status
- `compact`: If true, shows icon only

#### `RsvpSelectorButton`
**Location:** `lib/features/games/presentation/widgets/game_detail/rsvp_widgets.dart`

Interactive button to change RSVP status:
- Opens dialog with three options
- Updates status via repository
- Shows loading state during update
- Displays success/error messages

**Props:**
- `gameId`: Game ID
- `userId`: User ID
- `currentStatus`: Current RSVP status
- `onChanged`: Callback after status update

#### `RsvpSummaryCard`
**Location:** `lib/features/games/presentation/widgets/game_detail/rsvp_widgets.dart`

Summary card showing RSVP counts:
- Going count (green)
- Maybe count (orange)
- Not Going count (red)
- "Send Invites" button for admins

**Props:**
- `participants`: List of game participants
- `onSendEmails`: Callback to send emails (admin only)
- `canSendEmails`: Whether user can send emails

### Screen Updates

#### `GameDetailScreen`
**Location:** `lib/features/games/presentation/screens/game_detail_screen.dart`

**Changes:**
1. Added `RsvpSummaryCard` (visible for scheduled games)
2. Added user's own RSVP selector card
3. Added `_sendRsvpEmails()` method for manual email trigger

#### `ParticipantList`
**Location:** `lib/features/games/presentation/widgets/game_detail/participant_list.dart`

**Changes:**
- Added `RsvpStatusBadge` next to participant names
- Badge shows compact icon for quick visual reference

#### `CreateGameScreen`
**Location:** `lib/features/games/presentation/screens/create_game_screen.dart`

**Changes:**
- Auto-sends RSVP emails after game creation if `group.autoSendRsvpEmails` is true
- Only sends for single games (not recurring)

## User Flows

### Flow 1: Create Game with Auto-Send
1. Admin creates a new game
2. System checks `group.autoSendRsvpEmails` setting
3. If enabled, automatically calls `sendRsvpEmails()`
4. All group members receive email invitations
5. Players click RSVP buttons in email
6. System processes RSVP and updates database
7. Confirmation page shown to user

### Flow 2: Manual RSVP Email Trigger
1. Admin opens game detail screen
2. Clicks "Send Invites" button in RSVP Summary card
3. Confirms in dialog
4. System calls `sendRsvpEmails(gameId)`
5. All group members receive email invitations

### Flow 3: In-App RSVP Update
1. User opens game detail screen
2. Sees "Your RSVP" card
3. Clicks on current RSVP status badge
4. Dialog opens with three options
5. User selects new status
6. System calls `updateRSVP()`
7. Badge updates, summary refreshes

### Flow 4: Email Magic Link RSVP
1. User receives email invitation
2. Clicks on RSVP button (👍/👌/👎)
3. Browser opens `handle-rsvp` function URL
4. System validates token
5. System updates `game_participants` record
6. Success page shown with game details
7. User can change RSVP by clicking different button in original email

## Configuration

### 1. Database Migration
Run migration to add RSVP tables and settings:
```bash
supabase db push
```

Migration file: `supabase/migrations/036_add_rsvp_tokens_and_settings.sql`

### 2. Supabase Functions Setup

Deploy functions:
```bash
supabase functions deploy send-rsvp-emails
supabase functions deploy handle-rsvp
```

Set secrets:
```bash
supabase secrets set RESEND_API_KEY=your_resend_api_key
```

### 3. Email Service Setup

**Quick Start (Recommended):**
1. Sign up at [resend.com](https://resend.com) - free account, no credit card
2. Get API key from dashboard
3. Set the secret:
   ```bash
   supabase secrets set RESEND_API_KEY=re_your_key_here
   ```
4. Done! Use default address: `onboarding@resend.dev`

**Custom Domain (Optional):**
- Add your domain in Resend dashboard
- Verify DNS records
- Update "from" address in [send-rsvp-emails/index.ts:259](supabase/functions/send-rsvp-emails/index.ts#L259)

**Alternative Email Providers:**
See [EMAIL_SERVICE_OPTIONS.md](EMAIL_SERVICE_OPTIONS.md) for other options (SendGrid, AWS SES, Mailgun, SMTP).

**Why not use Supabase's email?**
Supabase's built-in email only handles auth emails (signup, password reset). For custom RSVP emails with game details and magic links, you need an external transactional email service. See [EMAIL_SERVICE_OPTIONS.md](EMAIL_SERVICE_OPTIONS.md) for details.

### 4. Group Settings

To disable auto-send for a specific group:
```sql
UPDATE groups SET auto_send_rsvp_emails = false WHERE id = 'group-id';
```

## Future Enhancements

### WhatsApp Integration
The RSVP system is designed to support WhatsApp in the future:

1. **Create Supabase Function: `handle-whatsapp-rsvp`**
   - Webhook to receive WhatsApp messages
   - Parse message for game ID and RSVP response
   - Call `updateRSVP()` to update status
   - Send confirmation message back to user

2. **WhatsApp Business API Setup**
   - Register for WhatsApp Business API
   - Configure webhook URL to point to `handle-whatsapp-rsvp`
   - Set up message templates for game invitations

3. **Database Changes**
   - Add `phone_number` to profiles (already exists)
   - Add `whatsapp_enabled` to groups table
   - Track RSVP source (email/whatsapp/app)

4. **Message Flow**
   ```
   Bot: 🃏 Poker game on Friday, Jan 20 at 7:00 PM
        Reply with:
        1 - I'm going 👍
        2 - Maybe 👌
        3 - Can't make it 👎

   User: 1

   Bot: ✅ Great! You're confirmed for Friday's game.
   ```

### Other Enhancements
- Email reminders 24 hours before game
- Push notifications for RSVP updates
- RSVP deadline setting
- Waitlist when max players reached
- Auto-cancel game if not enough RSVPs

## Testing Checklist

### Database
- [ ] Run migration successfully
- [ ] Verify `rsvp_tokens` table created
- [ ] Verify `auto_send_rsvp_emails` column added to groups
- [ ] Test cleanup function for expired tokens

### Supabase Functions
- [ ] Deploy `send-rsvp-emails` function
- [ ] Deploy `handle-rsvp` function
- [ ] Test email sending with Resend API
- [ ] Test magic link token validation
- [ ] Test expired token handling
- [ ] Test RSVP status update

### Flutter App
- [ ] Run `flutter pub run build_runner build`
- [ ] Verify no compilation errors
- [ ] Test RSVP badge display in participant list
- [ ] Test RSVP selector button interaction
- [ ] Test RSVP summary card display
- [ ] Test admin "Send Invites" button
- [ ] Test auto-send on game creation
- [ ] Test manual RSVP email trigger

### UI/UX
- [ ] No pixel overflows on different screen sizes
- [ ] Icons display correctly (👍👌👎)
- [ ] Colors match RSVP status (green/orange/red)
- [ ] Loading states show during updates
- [ ] Success/error messages display correctly
- [ ] Dialog interactions work smoothly

### End-to-End
- [ ] Create game with auto-send enabled
- [ ] Verify email received
- [ ] Click RSVP button in email
- [ ] Verify status updated in app
- [ ] Change RSVP via app
- [ ] Verify status syncs correctly
- [ ] Test admin manual email trigger
- [ ] Test with multiple users

## Troubleshooting

### Emails Not Sending
1. Check Resend API key is set: `supabase secrets list`
2. Verify domain is verified in Resend dashboard
3. Check function logs: `supabase functions logs send-rsvp-emails`
4. Ensure `SUPABASE_SERVICE_ROLE_KEY` is set

### Magic Links Not Working
1. Verify token in database: `SELECT * FROM rsvp_tokens WHERE token = 'xxx'`
2. Check token expiration: `expires_at` should be in future
3. Check function logs: `supabase functions logs handle-rsvp`
4. Ensure RLS policies allow service role access

### RSVP Status Not Updating
1. Check `game_participants` table for record
2. Verify user ID matches authenticated user
3. Check network requests in browser dev tools
4. Ensure repository method returns success

### Build Runner Errors
1. Clean build cache: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Run build runner: `flutter pub run build_runner build --delete-conflicting-outputs`

## File Reference

### Database Migrations
- `supabase/migrations/036_add_rsvp_tokens_and_settings.sql`

### Supabase Functions
- `supabase/functions/send-rsvp-emails/index.ts`
- `supabase/functions/handle-rsvp/index.ts`

### Models
- `lib/features/groups/data/models/group_model.dart`
- `lib/features/games/data/models/game_participant_model.dart`

### Repositories
- `lib/features/games/data/repositories/games_repository.dart`

### Widgets
- `lib/features/games/presentation/widgets/game_detail/rsvp_widgets.dart`
- `lib/features/games/presentation/widgets/game_detail/participant_list.dart`

### Screens
- `lib/features/games/presentation/screens/game_detail_screen.dart`
- `lib/features/games/presentation/screens/create_game_screen.dart`

## License
This feature is part of the Poker Manager application.
