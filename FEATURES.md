# Feature Documentation - Poker Manager

## Table of Contents
1. [Games Management](#games-management)
2. [Groups Management](#groups-management)
3. [Statistics & Analytics](#statistics--analytics)
4. [Settlements](#settlements)
5. [Profile Management](#profile-management)

---

## Games Management

### Overview
The Games feature enables creation, tracking, and management of poker games within groups.

### Key Screens

#### Games Entry Screen (`games_entry_screen.dart`)
**Purpose**: Main dashboard for game management
- Shows all games organized by status
- Sections: Active, Scheduled, Completed, Cancelled games
- Quick access to create new games
- Date and time display with formatters

**Theme Consistency**: 
- Uses Theme.of(context) for colors
- Cards with Material 3 styling
- Consistent spacing (16px padding)

#### Games List Screen (`games_list_screen.dart`)
**Purpose**: Group-specific game management
- Displays all games for a selected group
- Filtered view of games by status
- Floating action button for creating new games
- Pull-to-refresh functionality

**Entry Point**: "Manage Games" button on Group Details screen

#### Create Game Screen (`create_game_screen.dart`)
**Purpose**: Game creation and configuration
- Add game name and description
- Set up players and buy-in amounts
- Configure game date and time
- Select group association

#### Game Detail Screen (`game_detail_screen.dart`)
**Purpose**: Individual game information
- Display game results
- Show player standings
- Display buy-in/cashout amounts
- Calculate net results for each player

#### Start Game Screen (`start_game_screen.dart`)
**Purpose**: Initialize and begin a poker game
- Player entry and verification
- Initial chip stack distribution
- Game setup and start confirmation

### Data Models
- `GameModel`: Core game data structure
  - id, name, description
  - group_id, game_date, status
  - created_at, updated_at

- `GameParticipantModel`: Individual player participation
  - game_id, profile_id
  - total_buyin, total_cashout
  - net_result

### Theme Standards
- **Cards**: 12px border radius, 2pt elevation
- **Text**: Use textTheme.bodyMedium for descriptions
- **Status Colors**: 
  - Active: Green (primary)
  - Scheduled: Blue (secondary)
  - Completed: Grey (disabled)
  - Cancelled: Red (error)

---

## Groups Management

### Overview
Groups organize players and games into cohesive units with member and admin roles.

### Key Screens

#### Groups List Screen (`groups_list_screen.dart`)
**Purpose**: View and manage all user's poker groups
- Displays all groups user belongs to
- Shows member count and default buy-in
- Quick access to create new group
- Tap to view group details

**Theme Consistency**:
- List tiles with Material 3 styling
- Trailing icons for navigation
- Consistent subtitle styling

#### Group Detail Screen (`group_detail_screen.dart`)
**Purpose**: Comprehensive group information and management
- **Header**: Group name, currency, default buy-in
- **Members List**: All group members with:
  - Avatar (circle with initials)
  - Full name (clickable for details)
  - Role indicator (Creator/Admin/Member)
  - Admin controls (if user is admin)
  - Local player indicator
  - Remove/promote options
- **Action Buttons**:
  - "Manage Games": Navigate to games list
  - "Manage Members": Access member management

**Member Detail Popup**:
When clicking a member's name, shows AlertDialog with:
- Member avatar and full name
- Email address
- Phone number
- Full address (street, city, state, postal code, country)
- User ID
- Role (with color coding)
- Status (Local Player or Registered Player)
- Join date

**Theme Consistency**:
- Uses Theme.of(context).colorScheme for colors
- Secondary container with 0.35 opacity for highlights
- Color-coded roles:
  - Orange: Creator
  - Blue: Admin
  - Grey: Member

#### Create Group Screen (`create_group_screen.dart`)
**Purpose**: Create new poker group
- Group name (required)
- Description (optional)
- Privacy setting (private/public)
- Default currency and buy-in amount
- Additional buy-in options
- Member invitation

#### Edit Group Screen (`edit_group_screen.dart`)
**Purpose**: Update group settings
- Modify name, description, settings
- Upload/change group avatar
- Adjust default buy-in and currency
- Delete group (admin only)

**Danger Zone**: Red-colored delete button section

#### Manage Members Screen (`manage_members_screen.dart`)
**Purpose**: Administer group members
- View all members with roles
- Add new members
- Change member roles
- Remove members
- Promote to admin

#### Invite Members Screen (`invite_members_screen.dart`)
**Purpose**: Invite users to group
- Search for users
- Send invitations
- Track invitation status

### Data Models
- `GroupModel`: Group information
  - id, name, description
  - privacy, created_by
  - default_currency, default_buyin
  - created_at, updated_at

- `GroupMemberModel`: Member participation
  - id, group_id, user_id
  - role (admin/member)
  - is_creator, joined_at

### Providers
- `groupsListProvider`: Fetch user's groups
- `groupProvider(groupId)`: Fetch single group
- `groupMembersProvider(groupId)`: Fetch group members
- `groupControllerProvider`: Handle group operations

### Theme Standards
- **Member Highlighting**: Secondary container (0.35 opacity) for selected
- **Role Colors**: Orange (creator), Blue (admin), Grey (member)
- **Cards**: 12px radius for member cards
- **Buttons**: "Manage Games" and "Manage Members" with consistent spacing

---

## Statistics & Analytics

### Overview
Comprehensive analytics and statistics for player performance and game results.

### Key Screen

#### Stats Screen (`stats_screen.dart`)
**Purpose**: Display detailed player statistics and game analytics

**Two Modes**:

1. **Recent Games Mode**
   - Shows up to 4 most recent games
   - Time filter chips: Week, Month, Year, All
   - Game name search field
   - Game cards display:
     - Game name and date
     - Player count
     - Tap to view details
   - Current user highlighting with secondary color background

2. **Group Summary Mode**
   - Group selector dropdown
   - Summary card with:
     - Total games count
     - Total players count
     - Player win-loss record table showing each player's wins/losses
   - Game-by-game breakdown cards showing:
     - Game name and date
     - Player rankings table with:
       - Rank #
       - Player name
       - Net result (colored: green for positive, red for negative)
     - Win/Loss status table for each player:
       - Green text for "Win"
       - Red text for "Loss"

### Features

**Time Filtering**:
- Week: Last 7 days
- Month: Last 30 days
- Year: Last 365 days
- All: All-time games

**Game Search**:
- Filter games by name
- Case-insensitive matching
- Real-time filtering

**Player Highlighting**:
- Current user indicated with secondary container background (0.35 opacity)
- Bold text for current user in tables
- Applied to all ranking tables

**Ranking Logic**:
- Ranked by net result (highest to lowest)
- Tied players (same net result) get same rank number
- Subsequent players skip numbers (e.g., 1, 1, 3)

**Win/Loss Tracking**:
- Win: net_result > 0
- Loss: net_result ≤ 0
- Displayed in group summary table
- Shown per-game in breakdown

### Data Models
- `RankingRow`: Player ranking with totals
  - userId, name, net, wins, losses
  - breakdown: List<GameBreakdown>

- `GameBreakdown`: Individual game performance
  - gameId, gameName, gameDate
  - net, wins (if won), losses (if lost)

### Providers
- `recentGameStatsProvider`: Fetch recent games across groups
- `groupStatsProvider(groupId)`: Fetch group statistics with rankings

### Theme Standards
- **Tables**: Material 3 table styling with 12px radius cells
- **Highlight Color**: secondaryContainer with 0.35 opacity
- **Highlight Text**: onSecondaryContainer color
- **Net Results**: Green (#4CAF50) for positive, Red (#F44336) for negative
- **Win/Loss Colors**: Green for win, Red for loss
- **Font Weight**: Bold (w700) for current user
- **Spacing**: 12px between sections, 8px between cards

---

## Settlements

### Overview
Automatic calculation and tracking of payment settlements between players.

### Key Screen

#### Settlement Screen (`settlement_screen.dart`)
**Purpose**: Display and manage payment settlements
- Show debts and credits between players
- Mark settlements as paid
- Generate payment instructions
- Track settlement history

### Features
- Automatic settlement calculation after game completion
- Individual settlement tracking (who owes whom)
- Payment status tracking (pending/completed)
- Settlement consolidation (combine multiple debts)

### Data Models
- `SettlementModel`: Payment obligation
  - id, game_id
  - payer_id, payee_id
  - amount, status
  - created_at, settled_at

### Theme Standards
- **Pending Settlements**: Orange/warning color
- **Settled**: Green/success color
- **Overdue**: Red/error color

---

## Profile Management

### Overview
User profile management including personal information and avatar.

### Key Screens

#### Profile Screen (`profile_screen.dart`)
**Purpose**: View user profile information
- Display user details
- Show profile avatar
- Quick access to edit profile
- Logout functionality

**Theme Consistency**:
- Uses Theme.of(context) for styling
- Avatar with initials fallback
- Consistent card styling

#### Edit Profile Screen (`edit_profile_screen.dart`)
**Purpose**: Update user profile information
- Edit name, email, phone
- Add/change address information
- Upload profile avatar
- Save changes

### Data Models
- `ProfileModel`: User profile
  - id, email, username
  - firstName, lastName
  - avatarUrl
  - phoneNumber
  - streetAddress, city, stateProvince, postalCode, country
  - isLocalUser
  - createdAt, updatedAt
  - Computed: fullName, fullAddress

### Theme Standards
- **Avatar**: Circle with initials on grey background
- **Forms**: Material 3 input decoration
- **Image Upload**: Standard Material file picker
- **Buttons**: Elevated buttons for actions

---

## Color & Style Reference

### Material 3 Color Scheme
Based on green seed color with automatic light/dark generation

### Semantic Colors
- **Primary**: Actions, highlights (green-based)
- **Secondary**: Alternative actions, selections
- **Error**: Errors, warnings, deletions (red)
- **Success**: Completed, positive results (green)
- **Warning**: Warnings, pending actions (orange/yellow)

### Component Styling
- **AppBar**: Centered title, no elevation
- **Cards**: 12px radius, 2pt elevation, 16px padding
- **Buttons**: 8px radius, 24px horizontal padding
- **Input Fields**: 8px radius outline border
- **Text Fields**: Filled background, consistent styling

### Spacing Standards
- **Page Padding**: 16px
- **Section Spacing**: 12px
- **Item Spacing**: 8px
- **Icon Padding**: 4-8px

---

## Error Handling & Logging

### Log Format
- 🔴 Error: Critical errors
- 🔵 Info: Informational messages
- ✅ Success: Successful operations
- ⚠️ Warning: Warning conditions

### User Feedback
- Errors show SnackBar messages
- Loading states show CircularProgressIndicator
- Empty states show informative text
- Long operations show progress indicators

---

## Best Practices

### Code Guidelines
1. Always use Theme.of(context) for colors
2. Add file header comments explaining purpose
3. Use meaningful variable and function names
4. Comment complex logic and helper methods
5. Group related UI elements with comments

### UI/UX Guidelines
1. Maintain consistent spacing and typography
2. Use Material 3 components
3. Provide clear feedback for all actions
4. Handle loading and error states
5. Support both light and dark themes

### Performance
1. Use const constructors where possible
2. Implement ListViews with proper builders
3. Cache expensive computations
4. Use appropriate provider invalidation strategies
5. Lazy load data where applicable

---

## Last Updated
January 4, 2026
