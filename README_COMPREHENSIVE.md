# Poker Manager - Comprehensive Application Guide

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Theme & UI Consistency](#theme--ui-consistency)
4. [Feature Modules](#feature-modules)
5. [Screen Navigation](#screen-navigation)
6. [Development Guidelines](#development-guidelines)
7. [Build & Run](#build--run)

---

## Project Overview

**Poker Manager** is a Flutter-based poker group management application built with Supabase backend. It enables users to create poker groups, manage games, track player statistics, and settle payments between players.

### Key Features
- 🎮 **Game Management**: Create, track, and manage poker games
- 👥 **Group Management**: Organize poker groups with member management
- 📊 **Statistics**: View player performance, win/loss records, and game analytics
- 💰 **Settlements**: Automatic calculation and tracking of debt/credit between players
- 👤 **User Profiles**: Member profiles with detailed information and address tracking
- 🎯 **Role-Based Access**: Admin and member roles for group control

---

## Architecture

### Project Structure
```
lib/
├── main.dart                    # Application entry point
├── app/
│   ├── theme.dart             # Centralized theme configuration (Material 3)
│   └── router.dart            # GoRouter configuration
├── core/
│   ├── constants/             # App-wide constants
│   ├── services/              # Core services (Supabase, Auth)
│   └── utils/                 # Utility functions
├── features/
│   ├── auth/                  # Authentication feature
│   ├── games/                 # Games management feature
│   ├── groups/                # Groups management feature
│   ├── profile/               # User profile feature
│   ├── settlements/           # Payment settlements feature
│   └── stats/                 # Statistics & analytics feature
└── shared/
    ├── models/                # Shared data models
    └── widgets/               # Shared UI components
```

### Technology Stack
- **Framework**: Flutter 3.29+
- **State Management**: Riverpod
- **Backend**: Supabase (PostgreSQL)
- **Routing**: GoRouter
- **Design System**: Material 3
- **Data Serialization**: Freezed, JSON Serializable

---

## Theme & UI Consistency

### Material 3 Design System
The application uses Material 3 design with a consistent theme defined in `lib/app/theme.dart`.

#### Color Scheme
- **Seed Color**: Green (ColorScheme.fromSeed)
- **Light Theme**: Green-based light color scheme
- **Dark Theme**: Green-based dark color scheme
- **Automatic Theme Detection**: System theme preference

#### Consistent UI Elements

##### AppBar
- **Center Title**: All AppBars have centered titles
- **No Elevation**: AppBars have 0 elevation for clean appearance
- **Consistent Padding**: 16px standard padding

##### Cards
- **Border Radius**: 12px rounded corners (CardTheme)
- **Elevation**: 2pt shadow elevation
- **Spacing**: 16px padding for content

##### Input Fields
- **Border Style**: OutlineInputBorder with 8px radius
- **Filled Background**: All input fields have filled background
- **Error Handling**: Standard Material error display

##### Buttons
- **Elevated Buttons**: 24px horizontal, 12px vertical padding
- **Border Radius**: 8px rounded corners
- **Icon Buttons**: Use Icons from Material Icons

##### Tables
- **Cell Styling**: Consistent padding with _cell helper function
- **Text Alignment**: Right-aligned for numeric values
- **Highlight Colors**: Secondary container with 0.35 opacity for active/selected items

#### Typography
- **Headline**: Material textTheme.headlineSmall for screen titles
- **Body**: Material textTheme.bodyMedium for content
- **Labels**: Material textTheme.labelMedium for helper text

#### Spacing Standards
- **Padding**: 16px for content containers
- **Margin**: 12px between sections
- **Gap**: 8px between list items

---

## Feature Modules

### Authentication (`features/auth/`)
- Sign in / Sign up screens
- Session management
- User state tracking

### Games (`features/games/`)
**Key Screens:**
- `games_entry_screen.dart`: Main dashboard showing all games by status
- `games_list_screen.dart`: Group-specific game list with create/manage options
- `create_game_screen.dart`: Create new game with players and buy-in amounts
- `game_detail_screen.dart`: Individual game details and results
- `active_games_screen.dart`: Currently playing games
- `start_game_screen.dart`: Game initialization and player entry

### Groups (`features/groups/`)
**Key Screens:**
- `groups_list_screen.dart`: All user's groups with member count
- `group_detail_screen.dart`: Group information, members, and "Manage Games" button
- `create_group_screen.dart`: Create new poker group
- `manage_members_screen.dart`: Add/remove/manage group members
- `invite_members_screen.dart`: Invite new members to group
- `edit_group_screen.dart`: Update group settings

**Features:**
- Clickable member names show details in popup
- Member details include: Email, Phone, Address, User ID, Role, Status, Join date
- Role-based access control (Creator/Admin/Member)

### Statistics (`features/stats/`)
**Key Screens:**
- `stats_screen.dart`: Comprehensive player statistics and game breakdowns

**Features:**
- Recent games display (up to 4) with filters
- Time filters: Week, Month, Year, All
- Game name search/filtering
- Current user highlighting with secondary color background
- Group summary with:
  - Game-by-game player rankings
  - Win/Loss tables for each game
  - Player record summary (Wins/Losses)
- Tied ranking logic (same net result = same rank)

### Settlements (`features/settlements/`)
- Payment settlement calculations
- Debt/credit tracking between players

### Profile (`features/profile/`)
- User profile management
- Profile editing with avatar upload

---

## Screen Navigation

### Navigation Structure
Routes are centrally defined in `lib/app/router.dart` using GoRouter.

#### Main Navigation (HomeScreen Bottom Navigation)
1. **Games Entry** (Default) - Games dashboard
2. **Groups** - Groups list and management
3. **Stats** - Player statistics
4. **Profile** - User profile

#### Common Navigation Patterns
- **Push Route**: `context.push('/route-path')`
- **Replace Route**: `context.pushReplacementNamed('routeName')`
- **Pop**: `Navigator.pop(context)`

#### Key Routes
- `/` - Sign in (or home if authenticated)
- `/home` - Main dashboard (4-tab bottom navigation)
- `/groups` - Groups list
- `/groups/:id` - Group details with "Manage Games" button
- `/groups/:id/members` - Manage members
- `/groups/:id/edit` - Edit group
- `/games` - Games management
- `/stats` - Statistics dashboard
- `/profile` - User profile

---

## Development Guidelines

### Code Style & Comments

#### File Headers
All screen and provider files should start with a descriptive comment:
```dart
/// [ScreenName] - Brief description of functionality
/// 
/// Handles: List of key responsibilities
/// Dependencies: Any external dependencies or providers
/// Routes: Related navigation routes
```

#### Widget Comments
Major widgets and sections should have comments:
```dart
// Section header or descriptive comment
// Details about what this section does
Widget _buildSection() {
  return Container(
    // Specific component details
  );
}
```

#### Helper Method Comments
All helper methods should be documented:
```dart
/// Formats a date for display
/// 
/// [date] - DateTime to format
/// Returns formatted string in M/D/YYYY format
String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}
```

### Provider Pattern
- Use Riverpod for all state management
- Providers should be in `presentation/providers/` directory
- Data providers should be separated from UI providers
- Use `.family` for parameterized providers

### Error Handling
- Always show user-friendly SnackBars for errors
- Log errors to console with emoji prefixes (🔴 Error, 🔵 Info, ✅ Success)
- Wrap async operations in try-catch blocks

### UI/UX Standards
- Use theme colors from `Theme.of(context).colorScheme`
- Leverage Material 3 components
- Maintain consistent spacing: 16px (content), 12px (sections), 8px (items)
- Use cards for grouped content
- Always provide loading/error states

---

## Build & Run

### Prerequisites
```bash
flutter --version  # 3.29+
```

### Installation
```bash
flutter clean
flutter pub get
```

### Environment Setup
Create `env.json` in project root:
```json
{
  "SUPABASE_URL": "your_supabase_url",
  "SUPABASE_ANON_KEY": "your_anon_key",
  "SUPABASE_SERVICE_ROLE_KEY": "your_service_role_key"
}
```

### Running the App
```bash
# Development
flutter run --dart-define-from-file=env.json

# Release
flutter build apk --release --dart-define-from-file=env.json
flutter build ios --release --dart-define-from-file=env.json
```

### Running Tests
```bash
flutter test
```

---

## Key Implementation Details

### Group Details Screen
The Group Details screen showcases several advanced Flutter patterns:

**Manage Games Button** - Replaced "Edit Group" button
- Navigates to GamesListScreen with groupId
- Displays all games for the selected group
- Allows creating new games for the group

**Member Details Popup** - Click member name
- Shows member details in AlertDialog
- Displays: Email, Phone, Address, User ID, Role, Status, Join Date
- First/Last Name removed in favor of full name + address
- Color-coded role (Orange: Creator, Blue: Admin, Grey: Member)

### Stats Screen Features
The comprehensive stats implementation includes:

**Recent Games Section**
- Displays up to 4 most recent games
- TimeFilter enum: week, month, year, all
- Game name search filtering
- Current user highlighting

**Group Summary**
- Summary card with total games and players
- Player win-loss record table
- Game-by-game breakdown with:
  - Per-game player rankings (rank, name, net result)
  - Win/Loss status for each player
  - Tied ranking logic (same net = same rank)

---

## Troubleshooting

### Common Issues

**Build Errors**
- Run `flutter clean && flutter pub get`
- Ensure `env.json` is properly configured
- Check Flutter version compatibility

**Provider Errors**
- Verify provider initialization in main.dart
- Check provider dependencies and invalidation
- Review Riverpod observer logs

**Navigation Issues**
- Ensure route constants match GoRouter definitions
- Check context.push() vs context.go() usage
- Verify extra data passing for routes

**Theme Issues**
- AppTheme uses Material 3 (useMaterial3: true)
- ColorScheme generation from seedColor
- Override Theme.of(context) for local theme access

---

## Contributing

When adding new features:
1. Create feature module in `lib/features/[feature_name]/`
2. Follow existing folder structure (data, presentation, domain if complex)
3. Add comprehensive file header comments
4. Update this README with new features
5. Ensure theme consistency using Theme.of(context)
6. Add proper error handling and user feedback
7. Test on both light and dark themes

---

## Contact & Support

For issues or questions, please refer to project documentation or contact the development team.

**Last Updated**: January 4, 2026
