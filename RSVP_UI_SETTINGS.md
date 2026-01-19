# RSVP Email Settings UI

## Overview

Added UI controls for managing RSVP email settings at the group level, allowing admins to control when RSVP emails are sent.

## What Was Added

### 1. Group Settings Toggle

**Location:** Edit Group Screen ([edit_group_screen.dart](lib/features/groups/presentation/screens/edit_group_screen.dart))

**Feature:** "Auto-send RSVP emails" toggle switch

**Description:**
- Appears in the Edit Group screen as a new settings card
- Located above the "Save Changes" button
- Includes helpful subtitle: "Automatically send RSVP invitation emails when a new game is created"
- Default value: `true` (enabled)

**Visual Design:**
- Card with secondary container background
- Email icon in primary color
- Clean switch toggle interface
- Consistent with app design system

### 2. Database Support

The setting is stored in the `groups` table:
- Column: `auto_send_rsvp_emails`
- Type: `BOOLEAN`
- Default: `true`
- Added in migration: `036_add_rsvp_tokens_and_settings.sql`

### 3. Implementation Details

**Updated Files:**

1. **[group_model.dart](lib/features/groups/data/models/group_model.dart:18)**
   - Added `autoSendRsvpEmails` field with `@Default(true)`

2. **[groups_repository.dart](lib/features/groups/data/repositories/groups_repository.dart:130)**
   - Added `autoSendRsvpEmails` parameter to `updateGroup()` method

3. **[groups_provider.dart](lib/features/groups/presentation/providers/groups_provider.dart:82)**
   - Added `autoSendRsvpEmails` parameter to provider's `updateGroup()` method

4. **[edit_group_screen.dart](lib/features/groups/presentation/screens/edit_group_screen.dart:711)**
   - Added UI toggle card for RSVP email settings
   - Added state variable `_autoSendRsvpEmails`
   - Pass value to `updateGroup()` call

5. **[group_detail_screen.dart](lib/features/groups/presentation/screens/group_detail_screen.dart:458)**
   - Pass `autoSendRsvpEmails` when navigating to edit screen

6. **[router.dart](lib/app/router.dart:154)**
   - Extract `autoSendRsvpEmails` from route params

## How It Works

### User Flow

1. **Admin opens group settings:**
   - Navigate to group detail screen
   - Tap edit icon (top right)
   - Scroll to "RSVP Email Settings" card

2. **Toggle auto-send:**
   - Switch is ON by default (green)
   - Tap to disable (switch turns grey)
   - Setting is saved when "Save Changes" is clicked

3. **Effect on game creation:**
   - **When ENABLED**: RSVP emails sent automatically when game is created
   - **When DISABLED**: RSVP emails must be sent manually from game detail screen

### Technical Flow

```
User toggles switch
   ↓
setState() updates _autoSendRsvpEmails
   ↓
User clicks "Save Changes"
   ↓
controller.updateGroup(autoSendRsvpEmails: value)
   ↓
repository.updateGroup() updates database
   ↓
groups.auto_send_rsvp_emails column updated
   ↓
createGameScreen checks group.autoSendRsvpEmails
   ↓
Conditionally sends RSVP emails
```

## Future Enhancements

### Per-Game Override (Planned)

Add a checkbox in Create/Edit Game screens:
- "Send RSVP emails for this game"
- Allows overriding group-level setting for individual games
- Useful for special games that need different handling

**Implementation:**
1. Add `send_rsvp_emails` boolean to game creation
2. Check this flag instead of (or in addition to) group setting
3. Add UI checkbox in create_game_screen.dart

### Additional Settings (Ideas)

- **Email reminder timing**: "Send reminder 24 hours before game"
- **Auto-close RSVP**: "Stop accepting RSVPs X hours before game"
- **Require RSVP**: "Players must RSVP to see game details"
- **RSVP deadline**: Custom cutoff time for responses

## Testing

### Manual Test Steps

1. **Enable auto-send:**
   ```
   1. Open any group
   2. Tap edit icon
   3. Scroll to RSVP Email Settings
   4. Ensure toggle is ON (should be by default)
   5. Tap "Save Changes"
   6. Create a new game
   7. Verify RSVP emails are sent
   ```

2. **Disable auto-send:**
   ```
   1. Open same group
   2. Tap edit icon
   3. Toggle RSVP emails to OFF
   4. Tap "Save Changes"
   5. Create a new game
   6. Verify NO emails are sent automatically
   7. Go to game detail screen
   8. Tap "Send Invites" manually
   9. Verify emails are sent
   ```

### Database Verification

Check current setting for a group:
```sql
SELECT id, name, auto_send_rsvp_emails
FROM groups
WHERE id = 'your-group-id';
```

Update setting manually:
```sql
UPDATE groups
SET auto_send_rsvp_emails = false
WHERE id = 'your-group-id';
```

## Screenshots

### Edit Group Screen - RSVP Settings Card

```
┌─────────────────────────────────────────┐
│  📧  RSVP Email Settings                │
│                                         │
│  Auto-send RSVP emails          [ON]   │
│  Automatically send RSVP invitation    │
│  emails when a new game is created     │
└─────────────────────────────────────────┘
```

## Related Documentation

- [RSVP_FEATURE.md](RSVP_FEATURE.md) - Complete RSVP feature documentation
- [RSVP_QUICK_START.md](RSVP_QUICK_START.md) - Setup guide
- [EMAIL_SERVICE_OPTIONS.md](EMAIL_SERVICE_OPTIONS.md) - Email provider options

## Notes

- The setting is **group-level**, not user-level
- Only group admins can change this setting
- Default is `true` for backwards compatibility
- Existing groups will have auto-send enabled by default
- The setting can be changed at any time
- Changes take effect immediately for new games
