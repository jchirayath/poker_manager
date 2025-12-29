# Poker Game Manager - Technical Specifications

## 1. Executive Summary

A cross-platform mobile application (iOS and Android) that streamlines poker game management including buy-ins, cash-outs, settlements, and player statistics across multiple poker groups.

## 2. System Architecture

### 2.1 Technology Stack
- **Frontend**: Flutter for cross-platform development
- **Backend**: Supabase (PostgreSQL database with built-in REST API)
- **Database**: PostgreSQL (via Supabase)
- **Authentication**: Supabase Auth (supports email/password and OAuth providers)
- **Cloud Infrastructure**: Supabase Cloud
- **Real-time Updates**: Supabase Realtime (PostgreSQL Change Data Capture)
- **Storage**: Supabase Storage for avatars and images
- **Push Notifications**: Firebase Cloud Messaging (FCM) integrated with Supabase
- **State Management**: Riverpod or Bloc pattern

### 2.2 Architecture Pattern
- **Client-Server Architecture** with Supabase's auto-generated REST API and Realtime subscriptions
- **Offline-first approach** using Flutter packages like `drift` or `hive` for local caching with Supabase sync
- **BLoC or Riverpod pattern** for state management in Flutter
- **Row Level Security (RLS)** policies in Supabase for data access control

## 3. Core Features & Functional Requirements

### 3.1 User Management

#### 3.1.1 User Registration & Authentication
- Email/password registration with Supabase Auth email verification
- Social login options (Google, Apple, GitHub) via Supabase Auth providers
- Password reset functionality using Supabase Auth
- Profile management stored in `profiles` table:
  - First name and last name (required)
  - Full address (street, city, state/province, postal code)
  - Country (required)
  - Phone number (optional)
  - Profile picture upload to Supabase Storage
- Users can update their own profile information and pictures
- User roles managed via custom claims or metadata

#### 3.1.2 Player Pool
- Global player registry accessible to all users
- Profile visibility settings (public/private)
- Search and filter players by name or username
- Player statistics viewable by authorized users

### 3.2 Group Management

#### 3.2.1 Create & Configure Groups
- Group name, description, and avatar
- **Group creator automatically becomes admin**
- **Admins can delegate additional admin roles to other members**
- Privacy settings: Private (invite-only) or Public (searchable)
- Default game settings:
  - Currency (USD, EUR, GBP, etc.)
  - Default buy-in amount (Decimal)
  - Additional buy-in increments as Decimal values (e.g., 50.00, 100.00, 200.50)
  - Rebuy rules and limits

#### 3.2.2 Member Management
- Add players to group (via search or invite link)
- Member roles: Admin, Member
- **Group creator is the initial admin**
- **Admins can promote members to admin role**
- **Admins can demote other admins (except the group creator)**
- Remove members (admin privilege)
- Member approval workflow for public groups
- View member statistics within group

#### 3.2.3 Group Settings Override
- Individual game settings can override group defaults
- Settings inheritance chain: Group Defaults → Game Settings

### 3.3 Game Scheduling

#### 3.3.1 Create Games
- Game name and date/time
- **Location selection via dropdown**:
  - List populated from addresses of all group members who have provided their address
  - Option to enter custom location text
  - Map integration for viewing selected location
- Maximum players limit
- Game-specific settings that can override group defaults:
  - Buy-in amount (Decimal)
  - Currency
  - Additional buy-in values (Decimal)

#### 3.3.2 Recurring Games
- Recurrence patterns:
  - Daily, Weekly, Bi-weekly, Monthly
  - Custom recurrence (e.g., every first Saturday)
  - End date or number of occurrences
- Auto-creation of recurring game instances
- Ability to edit single instance or entire series

#### 3.3.3 Game Invitations
- Automatic notification to all group members
- RSVP system (Going, Not Going, Maybe)
- Reminder notifications (24h, 1h before game)

### 3.4 Game Session Management

#### 3.4.1 Buy-in Tracking
- Record initial buy-in for each player
- **Support multiple buy-ins per player within a single game**:
  - Each buy-in tracked separately with timestamp
  - Running total displayed for each player's total buy-in
- Track additional buy-ins (rebuys) with timestamps and amounts
- Support multiple buy-in amounts from predefined Decimal values or custom amounts
- Cash buy-in or digital/app-based payment tracking
- Display individual buy-in history for each player during the game
- Calculate and display total buy-ins across all players

#### 3.4.2 Cash-out Process
- Record final chip count or cash-out amount for each player
- Support partial cash-outs during game
- **Pre-settlement validation**:
  - Calculate total buy-ins across all players
  - Calculate total cash-outs across all players
  - **System warns if totals don't match before allowing settlement**
  - Display discrepancy amount if mismatch detected
  - Require admin confirmation to proceed with settlement if mismatch exists
- Manual override capability with admin approval

#### 3.4.3 Game Closure
- Mark game as complete
- Finalize all buy-ins and cash-outs
- Generate settlement report
- Lock game data (with unlock option for admins)

### 3.5 Settlement System

#### 3.5.1 Settlement Calculation
- Calculate net profit/loss for each player
- **Smart Settlement Algorithm**: Minimize number of transactions
  - Use debt simplification algorithm (e.g., greedy approach or graph-based)
  - Example: If A owes B $50 and B owes C $50, simplify to A pays C $50
- Generate optimized payment list showing who pays whom and how much

#### 3.5.2 Settlement Features
- View detailed breakdown of each player's position
- Export settlement summary (PDF, text, or image)
- Share settlement via messaging apps
- Mark payments as completed
- Payment history and reminders

### 3.6 Statistics & Rankings

#### 3.6.1 Player Statistics (per Group)
- Total games played
- Total buy-ins and cash-outs
- Net profit/loss (all-time and time-period filtered)
- Win rate percentage
- Average profit per game
- Biggest win/loss
- Current streak (winning/losing)

#### 3.6.2 Group Rankings
- Leaderboard based on:
  - Total profit
  - Win rate
  - Games played
  - ROI (Return on Investment)
- Time-based rankings (monthly, yearly, all-time)
- Visual charts and graphs for trends

#### 3.6.3 Game History
- Complete game archive with filters
- Per-game detailed view with all transactions
- Search functionality by date, players, or amount

## 4. Data Models

### 4.1 User
```
- user_id (UUID, Primary Key)
- email (String, Unique)
- username (String, Unique)
- first_name (String, Required)
- last_name (String, Required)
- avatar_url (String)
- phone_number (String, Optional)
- street_address (String, Optional)
- city (String, Optional)
- state_province (String, Optional)
- postal_code (String, Optional)
- country (String, Required)
- created_at (Timestamp)
- updated_at (Timestamp)
```

### 4.2 Group
```
- group_id (UUID, Primary Key)
- name (String)
- description (Text)
- avatar_url (String)
- created_by (Foreign Key → User)
- privacy (Enum: private, public)
- default_currency (String)
- default_buyin (Decimal)
- additional_buyin_values (Array of Decimal)
- created_at (Timestamp)
- updated_at (Timestamp)
```

### 4.3 GroupMember
```
- membership_id (UUID, Primary Key)
- group_id (Foreign Key → Group)
- user_id (Foreign Key → User)
- role (Enum: admin, member)
- is_creator (Boolean, default: false)
- joined_at (Timestamp)
```

### 4.4 Game
```
- game_id (UUID, Primary Key)
- group_id (Foreign Key → Group)
- name (String)
- game_date (DateTime)
- location (String)
- location_host_user_id (Foreign Key → User, Optional)
- max_players (Integer, Optional)
- currency (String)
- buyin_amount (Decimal)
- additional_buyin_values (Array of Decimal)
- status (Enum: scheduled, in_progress, completed, cancelled)
- recurrence_pattern (JSON, Optional)
- parent_game_id (Foreign Key → Game, for recurring)
- created_at (Timestamp)
- updated_at (Timestamp)
```

### 4.5 GameParticipant
```
- participant_id (UUID, Primary Key)
- game_id (Foreign Key → Game)
- user_id (Foreign Key → User)
- rsvp_status (Enum: going, not_going, maybe)
- total_buyin (Decimal)
- total_cashout (Decimal)
- net_result (Decimal, Calculated)
- created_at (Timestamp)
```

### 4.6 Transaction
```
- transaction_id (UUID, Primary Key)
- game_id (Foreign Key → Game)
- user_id (Foreign Key → User)
- type (Enum: buyin, cashout)
- amount (Decimal)
- timestamp (DateTime)
- notes (Text, Optional)
```

### 4.7 Settlement
```
- settlement_id (UUID, Primary Key)
- game_id (Foreign Key → Game)
- payer_id (Foreign Key → User)
- payee_id (Foreign Key → User)
- amount (Decimal)
- status (Enum: pending, completed)
- completed_at (Timestamp, Optional)
```

### 4.8 PlayerStatistics
```
- stat_id (UUID, Primary Key)
- user_id (Foreign Key → User)
- group_id (Foreign Key → Group)
- games_played (Integer)
- total_buyin (Decimal)
- total_cashout (Decimal)
- net_profit (Decimal)
- biggest_win (Decimal)
- biggest_loss (Decimal)
- current_streak (Integer)
- updated_at (Timestamp)
```

## 5. Supabase Schema & Row Level Security

### 5.1 Database Tables

All tables include automatic `created_at` and `updated_at` timestamps via Supabase.

#### 5.1.1 profiles
```sql
CREATE TABLE profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  avatar_url TEXT,
  phone_number TEXT,
  street_address TEXT,
  city TEXT,
  state_province TEXT,
  postal_code TEXT,
  country TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create a computed column for full address display
CREATE OR REPLACE FUNCTION get_full_address(p profiles)
RETURNS TEXT AS $
BEGIN
  RETURN CONCAT_WS(', ',
    NULLIF(p.street_address, ''),
    NULLIF(p.city, ''),
    NULLIF(p.state_province, ''),
    NULLIF(p.postal_code, ''),
    NULLIF(p.country, '')
  );
END;
$ LANGUAGE plpgsql STABLE;
```

#### 5.1.2 groups
```sql
CREATE TABLE groups (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  privacy TEXT CHECK (privacy IN ('private', 'public')) DEFAULT 'private',
  default_currency TEXT DEFAULT 'USD',
  default_buyin DECIMAL(10,2),
  additional_buyin_values DECIMAL(10,2)[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 5.1.3 group_members
```sql
CREATE TABLE group_members (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  role TEXT CHECK (role IN ('admin', 'member')) DEFAULT 'member',
  is_creator BOOLEAN DEFAULT FALSE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(group_id, user_id)
);

-- Trigger to set creator as admin
CREATE OR REPLACE FUNCTION set_creator_as_admin()
RETURNS TRIGGER AS $
BEGIN
  IF NEW.is_creator = TRUE THEN
    NEW.role := 'admin';
  END IF;
  RETURN NEW;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER ensure_creator_is_admin
  BEFORE INSERT OR UPDATE ON group_members
  FOR EACH ROW
  EXECUTE FUNCTION set_creator_as_admin();
```

#### 5.1.4 games
```sql
CREATE TABLE games (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  game_date TIMESTAMPTZ NOT NULL,
  location TEXT,
  location_host_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  max_players INTEGER,
  currency TEXT,
  buyin_amount DECIMAL(10,2),
  additional_buyin_values DECIMAL(10,2)[] DEFAULT '{}',
  status TEXT CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')) DEFAULT 'scheduled',
  recurrence_pattern JSONB,
  parent_game_id UUID REFERENCES games(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 5.1.5 game_participants
```sql
CREATE TABLE game_participants (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  game_id UUID REFERENCES games(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  rsvp_status TEXT CHECK (rsvp_status IN ('going', 'not_going', 'maybe')) DEFAULT 'maybe',
  total_buyin DECIMAL(10,2) DEFAULT 0,
  total_cashout DECIMAL(10,2) DEFAULT 0,
  net_result DECIMAL(10,2) GENERATED ALWAYS AS (total_cashout - total_buyin) STORED,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(game_id, user_id)
);
```

#### 5.1.6 transactions
```sql
CREATE TABLE transactions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  game_id UUID REFERENCES games(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT CHECK (type IN ('buyin', 'cashout')) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT
);
```

#### 5.1.7 settlements
```sql
CREATE TABLE settlements (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  game_id UUID REFERENCES games(id) ON DELETE CASCADE NOT NULL,
  payer_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  payee_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  status TEXT CHECK (status IN ('pending', 'completed')) DEFAULT 'pending',
  completed_at TIMESTAMPTZ
);
```

#### 5.1.8 player_statistics
```sql
CREATE TABLE player_statistics (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE NOT NULL,
  games_played INTEGER DEFAULT 0,
  total_buyin DECIMAL(10,2) DEFAULT 0,
  total_cashout DECIMAL(10,2) DEFAULT 0,
  net_profit DECIMAL(10,2) DEFAULT 0,
  biggest_win DECIMAL(10,2) DEFAULT 0,
  biggest_loss DECIMAL(10,2) DEFAULT 0,
  current_streak INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, group_id)
);
```

### 5.2 Row Level Security (RLS) Policies

#### 5.2.1 profiles
```sql
-- Users can read all profiles (for player search)
CREATE POLICY "Profiles are viewable by everyone"
  ON profiles FOR SELECT
  USING (true);

-- Users can only update their own profile
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);
```

#### 5.2.2 groups
```sql
-- Users can view groups they're members of
CREATE POLICY "Users can view their groups"
  ON groups FOR SELECT
  USING (
    id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

-- Users can create groups
CREATE POLICY "Users can create groups"
  ON groups FOR INSERT
  WITH CHECK (created_by = auth.uid());

-- Group admins can update groups
CREATE POLICY "Group admins can update groups"
  ON groups FOR UPDATE
  USING (
    id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );
```

#### 5.2.3 group_members
```sql
-- Users can view members of their groups
CREATE POLICY "Users can view group members"
  ON group_members FOR SELECT
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

-- Group admins can add members
CREATE POLICY "Group admins can add members"
  ON group_members FOR INSERT
  WITH CHECK (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Group admins can promote/demote members
CREATE POLICY "Group admins can update member roles"
  ON group_members FOR UPDATE
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    -- Cannot demote the creator
    (is_creator = FALSE OR role = 'admin')
  );
```

#### 5.2.4 games
```sql
-- Users can view games in their groups
CREATE POLICY "Users can view group games"
  ON games FOR SELECT
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

-- Group members can create games
CREATE POLICY "Group members can create games"
  ON games FOR INSERT
  WITH CHECK (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid()
    )
  );

-- Group admins can update/delete games
CREATE POLICY "Group admins can modify games"
  ON games FOR UPDATE
  USING (
    group_id IN (
      SELECT group_id FROM group_members 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );
```

### 5.3 Database Functions

#### 5.3.1 Update Player Statistics (Trigger Function)
```sql
CREATE OR REPLACE FUNCTION update_player_statistics()
RETURNS TRIGGER AS $
BEGIN
  -- Update statistics when game is completed
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Logic to update player_statistics table
    -- This would aggregate data from game_participants
  END IF;
  RETURN NEW;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER update_stats_on_game_complete
  AFTER UPDATE ON games
  FOR EACH ROW
  EXECUTE FUNCTION update_player_statistics();
```

#### 5.3.2 Calculate Settlement (RPC Function)
```sql
CREATE OR REPLACE FUNCTION calculate_settlement(game_uuid UUID)
RETURNS TABLE(payer UUID, payee UUID, amount DECIMAL) AS $
BEGIN
  -- Implementation of settlement algorithm
  -- Returns optimized payment list
END;
$ LANGUAGE plpgsql;
```

### 5.4 Supabase Realtime Subscriptions

Enable realtime for live updates:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE game_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE settlements;
```

### 5.5 Storage Buckets

Create storage buckets for:
- **avatars**: User profile pictures (public)
- **group-images**: Group avatars (public)

Storage policies:
```sql
-- Users can upload their own avatars
CREATE POLICY "Users can upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

## 6. Flutter Implementation Details

### 6.1 Project Structure
```
lib/
├── main.dart
├── app/
│   ├── router.dart
│   └── theme.dart
├── core/
│   ├── constants/
│   ├── utils/
│   └── widgets/
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── groups/
│   ├── games/
│   ├── settlements/
│   └── statistics/
└── services/
    ├── supabase_service.dart
    ├── storage_service.dart
    └── notification_service.dart
```

### 6.2 Key Flutter Packages
```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  riverpod: ^2.4.0  # or flutter_bloc
  go_router: ^12.0.0
  drift: ^2.14.0  # For offline storage
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  firebase_messaging: ^14.7.0
  fl_chart: ^0.65.0  # For statistics charts
  intl: ^0.18.0
  image_picker: ^1.0.4
  cached_network_image: ^3.3.0

dev_dependencies:
  build_runner: ^2.4.6
  freezed: ^2.4.5
  json_serializable: ^6.7.1
  flutter_test:
    sdk: flutter
```

### 6.3 Supabase Client Setup
```dart
// lib/main.dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;
```

### 6.8 Profile Management Screen
```dart
// lib/features/profile/presentation/profile_edit_screen.dart
class ProfileEditScreen extends ConsumerStatefulWidget {
  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;
  String? _selectedCountry;
  File? _imageFile;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  Future<void> _uploadAvatar() async {
    if (_imageFile == null) return;
    
    final userId = supabase.auth.currentUser!.id;
    final fileName = 'avatar_$userId.jpg';
    
    await supabase.storage
        .from('avatars')
        .upload('$userId/$fileName', _imageFile!);
    
    final avatarUrl = supabase.storage
        .from('avatars')
        .getPublicUrl('$userId/$fileName');
    
    await supabase
        .from('profiles')
        .update({'avatar_url': avatarUrl})
        .eq('id', userId);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    await _uploadAvatar();
    
    await supabase.from('profiles').update({
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'street_address': _streetController.text,
      'city': _cityController.text,
      'state_province': _stateController.text,
      'postal_code': _postalCodeController.text,
      'country': _selectedCountry,
    }).eq('id', supabase.auth.currentUser!.id);
  }
}
```
```dart
// lib/features/groups/providers/groups_provider.dart
@riverpod
class Groups extends _$Groups {
  @override
  FutureOr<List<Group>> build() async {
    return _fetchGroups();
  }

  Future<List<Group>> _fetchGroups() async {
    final response = await supabase
        .from('groups')
        .select('*, group_members!inner(*)')
        .eq('group_members.user_id', supabase.auth.currentUser!.id);
    
    return (response as List)
        .map((json) => Group.fromJson(json))
        .toList();
  }

  Future<void> createGroup(GroupInput input) async {
    await supabase.from('groups').insert(input.toJson());
    ref.invalidateSelf();
  }
}
```

### 6.9 Location Selection for Games
```dart
// lib/features/games/presentation/widgets/location_selector.dart
class LocationSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupMembers = ref.watch(groupMembersProvider);
    
    return groupMembers.when(
      data: (members) {
        // Filter members who have addresses
        final membersWithAddresses = members
            .where((m) => m.streetAddress != null && m.streetAddress!.isNotEmpty)
            .toList();
        
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: 'Game Location'),
          items: [
            DropdownMenuItem(
              value: 'custom',
              child: Text('Custom Location'),
            ),
            ...membersWithAddresses.map((member) {
              final fullAddress = [
                member.streetAddress,
                member.city,
                member.stateProvince,
                member.postalCode,
                member.country
              ].where((s) => s != null && s.isNotEmpty).join(', ');
              
              return DropdownMenuItem(
                value: member.userId,
                child: Text('${member.firstName} ${member.lastName} - $fullAddress'),
              );
            }),
          ],
          onChanged: (value) {
            if (value == 'custom') {
              // Show custom location text field
            } else {
              // Use selected member's address
            }
          },
        );
      },
      loading: () => CircularProgressIndicator(),
      error: (e, s) => Text('Error loading locations'),
    );
  }
}
```
```dart
// lib/features/games/providers/game_provider.dart
class GameNotifier extends StateNotifier<AsyncValue<Game>> {
  final String gameId;
  RealtimeChannel? _channel;

  GameNotifier(this.gameId) : super(const AsyncValue.loading()) {
    _loadGame();
    _subscribeToChanges();
  }

  void _subscribeToChanges() {
    _channel = supabase
        .channel('game:$gameId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'game_id',
            value: gameId,
          ),
          callback: (payload) {
            _loadGame(); // Refresh game data
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
```

### 6.10 Multiple Buy-ins Tracking
```dart
// lib/features/games/presentation/widgets/buyin_tracker.dart
class BuyinTracker extends ConsumerStatefulWidget {
  final String gameId;
  final String userId;
  
  const BuyinTracker({required this.gameId, required this.userId});
  
  @override
  _BuyinTrackerState createState() => _BuyinTrackerState();
}

class _BuyinTrackerState extends ConsumerState<BuyinTracker> {
  Future<void> _addBuyin(double amount) async {
    await supabase.from('transactions').insert({
      'game_id': widget.gameId,
      'user_id': widget.userId,
      'type': 'buyin',
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Update total in game_participants
    final currentTotal = await supabase
        .from('game_participants')
        .select('total_buyin')
        .eq('game_id', widget.gameId)
        .eq('user_id', widget.userId)
        .single();
    
    await supabase.from('game_participants').update({
      'total_buyin': (currentTotal['total_buyin'] ?? 0) + amount,
    }).match({
      'game_id': widget.gameId,
      'user_id': widget.userId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(
      transactionsProvider(widget.gameId, widget.userId)
    );
    
    return transactions.when(
      data: (txns) {
        final buyins = txns.where((t) => t.type == 'buyin').toList();
        final total = buyins.fold<double>(
          0, (sum, t) => sum + t.amount
        );
        
        return Column(
          children: [
            Text('Total Buy-in: \${total.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Buy-in History:', style: TextStyle(fontSize: 16)),
            ...buyins.map((buyin) => ListTile(
              title: Text('\${buyin.amount.toStringAsFixed(2)}'),
              subtitle: Text(
                DateFormat('MMM d, y - h:mm a').format(buyin.timestamp)
              ),
            )),
          ],
        );
      },
      loading: () => CircularProgressIndicator(),
      error: (e, s) => Text('Error loading buy-ins'),
    );
  }
}
```
```dart
// lib/services/local_database.dart
@DriftDatabase(tables: [Groups, Games, GameParticipants])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(path.join(dbFolder.path, 'poker_app.db'));
      return NativeDatabase(file);
    });
  }
}
```

### 6.11 Settlement Validation
```dart
// lib/features/settlements/presentation/settlement_validator.dart
class SettlementValidator {
  static Future<ValidationResult> validateBeforeSettlement(String gameId) async {
    // Get all participants
    final participants = await supabase
        .from('game_participants')
        .select('total_buyin, total_cashout')
        .eq('game_id', gameId);
    
    double totalBuyins = 0;
    double totalCashouts = 0;
    
    for (var p in participants) {
      totalBuyins += (p['total_buyin'] ?? 0) as double;
      totalCashouts += (p['total_cashout'] ?? 0) as double;
    }
    
    final difference = totalBuyins - totalCashouts;
    final tolerance = 0.01; // Allow 1 cent difference for rounding
    
    if (difference.abs() > tolerance) {
      return ValidationResult(
        isValid: false,
        totalBuyins: totalBuyins,
        totalCashouts: totalCashouts,
        difference: difference,
        message: 'Warning: Buy-ins (\${totalBuyins.toStringAsFixed(2)}) '
                 'do not match cash-outs (\${totalCashouts.toStringAsFixed(2)}). '
                 'Difference: \${difference.toStringAsFixed(2)}',
      );
    }
    
    return ValidationResult(
      isValid: true,
      totalBuyins: totalBuyins,
      totalCashouts: totalCashouts,
      difference: 0,
      message: 'Buy-ins and cash-outs match perfectly!',
    );
  }
}

class ValidationResult {
  final bool isValid;
  final double totalBuyins;
  final double totalCashouts;
  final double difference;
  final String message;
  
  ValidationResult({
    required this.isValid,
    required this.totalBuyins,
    required this.totalCashouts,
    required this.difference,
    required this.message,
  });
}

// Usage in settlement screen
Future<void> _initiateSettlement() async {
  final validation = await SettlementValidator.validateBeforeSettlement(gameId);
  
  if (!validation.isValid) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settlement Warning'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(validation.message),
            SizedBox(height: 16),
            Text('Do you want to proceed with settlement anyway?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Proceed Anyway'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (proceed != true) return;
  }
  
  // Proceed with settlement calculation
  _calculateSettlement();
}
```
```dart
// lib/features/auth/presentation/auth_controller.dart
class AuthController {
  final supabase = Supabase.instance.client;

  Future<void> signUp(String email, String password) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
    );
    
    if (response.user != null) {
      // Create profile entry
      await supabase.from('profiles').insert({
        'id': response.user!.id,
        'email': email,
      });
    }
  }

  Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.pokerapp://login-callback/',
    );
  }

  Stream<AuthState> get authStateChanges => 
      supabase.auth.onAuthStateChange;
}
```

### 7.1 Performance
- App launch time: < 2 seconds
- API response time: < 500ms for 95th percentile
- Support for offline mode with data sync
- Handle up to 100 players per group
- Handle up to 50 concurrent games per group

### 7.2 Security
- Supabase RLS policies for all data access control
- Supabase Auth JWT tokens with configurable expiration
- HTTPS enforced for all Supabase API communications
- Rate limiting via Supabase Edge Functions
- Input validation on both client and database level
- GDPR and data privacy compliance via Supabase features

### 7.3 Reliability
- 99.9% uptime SLA (Supabase managed)
- Automated backups via Supabase (point-in-time recovery)
- Data redundancy across multiple regions (Supabase managed)
- Graceful error handling and user feedback in Flutter app

### 7.4 Scalability
- Supabase auto-scaling for database connections
- Supabase Edge Functions for custom backend logic
- Supabase CDN for Storage assets
- Database indexing on foreign keys and frequently queried columns

### 7.5 Usability
- Intuitive UI/UX following platform guidelines (iOS Human Interface, Material Design)
- Accessibility compliance (WCAG 2.1 Level AA)
- Multi-language support (i18n)
- Dark mode support

## 8. Settlement Algorithm Details

### 8.1 Algorithm: Minimum Transaction Debt Simplification

**Objective**: Reduce the number of payments needed to settle all debts.

**Algorithm Steps**:
1. Calculate each player's net position (total cash-out minus total buy-in)
2. Create two lists: creditors (net positive) and debtors (net negative)
3. Sort creditors in descending order and debtors in ascending order
4. While both lists are non-empty:
   - Take the largest creditor and largest debtor
   - Transfer min(creditor_amount, abs(debtor_amount))
   - Remove settled parties from lists
5. Generate payment instructions

**Example**:
- Player A: -$100 (owes)
- Player B: +$150 (owed)
- Player C: -$50 (owes)

Simplified Settlement:
- A pays B: $100
- C pays B: $50

**Complexity**: O(n log n) where n is number of players

### 8.2 Edge Cases
- Handle zero-sum validation
- Rounding errors (handle cents)
- Partial settlements
- Multi-currency games (convert to base currency)

## 9. UI/UX Wireframe Descriptions

### 9.1 Key Screens
1. **Home/Dashboard**: List of groups, upcoming games, quick stats
2. **Group Details**: Members, scheduled games, rankings, settings
3. **Game Details**: Participants, RSVP, buy-in tracking, settlement
4. **Active Game Session**: Real-time buy-in/cash-out entry interface
5. **Settlement View**: Visual payment network, payment checklist
6. **Statistics**: Charts, leaderboards, filters
7. **Profile**: User settings, payment methods, notifications

### 9.2 Navigation Pattern
- Bottom tab navigation (Groups, Games, Stats, Profile)
- Stack navigation within each section
- Floating action button for quick game creation

## 10. Testing Strategy

### 10.1 Testing Types
- **Unit Tests**: 80% code coverage minimum using Flutter's test framework
- **Widget Tests**: Test individual Flutter widgets and screens
- **Integration Tests**: Test complete user flows with `integration_test` package
- **Supabase Function Tests**: Test database functions and RLS policies
- **Performance Tests**: Flutter Driver for performance profiling

### 10.2 Test Scenarios
- Complete game flow (create → buy-in → cash-out → settle)
- Recurring game generation and modification
- Settlement algorithm validation
- Offline mode and sync
- Multi-device synchronization

## 11. Deployment & DevOps

### 11.1 CI/CD Pipeline
- GitHub Actions or Codemagic for Flutter builds
- Automated testing on PR
- Automated builds for iOS and Android
- Fastlane for app store deployment automation

### 11.2 Monitoring & Logging
- Supabase Dashboard for database monitoring
- Firebase Crashlytics for crash reporting
- Sentry for error tracking
- Firebase Analytics or Mixpanel for user analytics
- Supabase logs for backend debugging

### 11.3 App Store Deployment
- iOS: Apple App Store Connect
- Android: Google Play Console
- Beta testing via TestFlight and Google Play Beta

## 12. Future Enhancements (Post-MVP)

- Integration with payment gateways (Venmo, PayPal, Stripe)
- In-app messaging and chat
- Tournament mode with brackets
- Live game streaming or updates
- AI-powered game recommendations
- Poker hand tracking and analysis
- Integration with smart chips/RFID readers
- Social features (achievements, challenges)
- Web application version
- Admin dashboard for analytics

## 13. Development Timeline Estimate

### Phase 1: MVP (2.5-3 months)
- Flutter project setup and Supabase integration (1 week)
- User authentication with Supabase Auth (1 week)
- Database schema and RLS policies setup (1 week)
- Group management UI and logic (2 weeks)
- Game scheduling and basic recurrence (2 weeks)
- Buy-in/cash-out tracking with realtime updates (2 weeks)
- Settlement calculation algorithm (1.5 weeks)
- Basic statistics and rankings (1.5 weeks)
- Testing and bug fixes (2 weeks)

### Phase 2: Enhancement (1.5-2 months)
- Advanced recurrence patterns
- Offline mode with Drift
- Push notifications with FCM
- Enhanced statistics with fl_chart
- UI/UX refinements and animations
- Performance optimization

### Phase 3: Polish & Launch (1 month)
- Beta testing
- App store submission
- Marketing materials
- User documentation

## 14. Success Metrics

- **User Acquisition**: 10,000+ downloads in first 6 months
- **User Engagement**: 60% DAU/MAU ratio
- **Retention**: 40% 30-day retention
- **App Rating**: 4.5+ stars on both platforms
- **Performance**: < 1% crash rate
- **Settlement Accuracy**: 99.99% calculation accuracy

## 15. Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Algorithm complexity in settlement | High | Thorough testing, manual override option |
| Data synchronization conflicts | Medium | Last-write-wins with conflict resolution UI |
| Regulatory compliance (gambling) | High | Legal review, clear terms of service |
| Platform approval rejection | Medium | Follow app store guidelines strictly |
| Low user adoption | High | Beta testing with real poker groups, iterative feedback |

---

**Document Version**: 1.0  
**Last Updated**: December 2025  
**Author**: Technical Specifications Team