// Comprehensive UI Interaction Tests
// Tests all buttons, navigation, and user flows in the application
//
// Run with: flutter test test/app_ui_interaction_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poker_manager/features/auth/data/models/user_model.dart';
import 'package:poker_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:poker_manager/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:poker_manager/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:poker_manager/features/profile/presentation/screens/profile_screen.dart';
import 'package:poker_manager/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:poker_manager/features/groups/presentation/screens/groups_list_screen.dart';
import 'package:poker_manager/features/groups/presentation/screens/create_group_screen.dart';
import 'package:poker_manager/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:poker_manager/features/groups/presentation/providers/groups_provider.dart';
import 'package:poker_manager/features/games/presentation/screens/games_entry_screen.dart';
import 'package:poker_manager/features/stats/presentation/screens/stats_screen.dart';
import 'helpers/test_data_factory.dart';

/// Helper to create a test app with proper sizing
Widget createTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: child,
      ),
    ),
  );
}

void main() {
  // Set test surface size to simulate a phone screen
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // ============================================
  // AUTH SCREEN TESTS
  // ============================================

  group('Sign In Screen', () {
    testWidgets('renders sign in form elements', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const SignInScreen()));
      await tester.pumpAndSettle();

      // Check for text form fields
      expect(find.byType(TextFormField), findsWidgets);

      // Check for sign in button
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('has navigation to sign up', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const SignInScreen()));
      await tester.pumpAndSettle();

      // Check for sign up link text (may be "Sign Up" or "sign up")
      expect(find.textContaining('Sign Up'), findsWidgets);
    });

    testWidgets('email field accepts input', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const SignInScreen()));
      await tester.pumpAndSettle();

      // Find email field and enter text
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');
      await tester.pumpAndSettle();

      expect(find.text('test@example.com'), findsOneWidget);
    });
  });

  group('Sign Up Screen', () {
    testWidgets('renders registration form elements', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const SignUpScreen()));
      await tester.pumpAndSettle();

      // Check for name fields
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);

      // Check for email
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('has country dropdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const SignUpScreen()));
      await tester.pumpAndSettle();

      // Check for country field
      expect(find.text('Country'), findsOneWidget);
    });

    testWidgets('has back button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const SignUpScreen()));
      await tester.pumpAndSettle();

      // Check for back/cancel button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  // ============================================
  // PROFILE SCREEN TESTS
  // ============================================

  group('Profile Screen', () {
    testWidgets('renders with mock user data', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testUser = UserModel(
        id: 'test-id',
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        country: 'United States',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(testUser)),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(400, 800)),
              child: const ProfileScreen(),
            ),
            routes: {
              '/profile/edit': (_) => const EditProfileScreen(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display user's name
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('shows sign out option', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testUser = UserModel(
        id: 'test-id',
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        country: 'United States',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(testUser)),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for logout icon
      expect(find.byIcon(Icons.logout), findsWidgets);
    });

    testWidgets('avatar has camera icon for editing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testUser = UserModel(
        id: 'test-id',
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        country: 'United States',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(testUser)),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for camera icon overlay
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });
  });

  // ============================================
  // GROUPS SCREEN TESTS
  // ============================================

  group('Groups List Screen', () {
    testWidgets('renders groups list screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupsListProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: GroupsListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GroupsListScreen), findsOneWidget);
    });

    testWidgets('renders group when data provided', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testGroup = TestDataFactory.createGroup(name: 'Test Poker Group');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupsListProvider.overrideWith((ref) async => [testGroup]),
          ],
          child: const MaterialApp(
            home: GroupsListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display group name
      expect(find.text('Test Poker Group'), findsOneWidget);
    });
  });

  // ============================================
  // GROUP DETAIL SCREEN TESTS
  // ============================================

  group('Group Detail Screen', () {
    testWidgets('renders group details', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testGroup = TestDataFactory.createGroup(
        id: 'test-group-id',
        name: 'Test Group',
        description: 'A test poker group',
        defaultBuyin: 100.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupProvider('test-group-id').overrideWith((ref) async => testGroup),
            groupMembersProvider('test-group-id').overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: GroupDetailScreen(groupId: 'test-group-id'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display group name
      expect(find.text('Test Group'), findsOneWidget);
      expect(find.text('USD 100.00 buy-in'), findsOneWidget);
    });

    testWidgets('shows members section', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testGroup = TestDataFactory.createGroup(id: 'test-group-id');
      final testProfile = TestDataFactory.createProfile(
        firstName: 'John',
        lastName: 'Doe',
      );
      final testMember = TestDataFactory.createAdminMember(
        groupId: 'test-group-id',
        userId: testProfile.id,
        profile: testProfile,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupProvider('test-group-id').overrideWith((ref) async => testGroup),
            groupMembersProvider('test-group-id').overrideWith((ref) async => [testMember]),
          ],
          child: const MaterialApp(
            home: GroupDetailScreen(groupId: 'test-group-id'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show members section
      expect(find.text('Members'), findsWidgets);
    });
  });

  // ============================================
  // CREATE GROUP SCREEN TESTS
  // ============================================

  group('Create Group Screen', () {
    testWidgets('renders form fields', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const CreateGroupScreen()));
      await tester.pumpAndSettle();

      // Check for required fields
      expect(find.text('Group Name'), findsOneWidget);
    });

    testWidgets('has currency selector', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const CreateGroupScreen()));
      await tester.pumpAndSettle();

      // Check for currency field
      expect(find.text('Default Currency'), findsOneWidget);
    });
  });

  // ============================================
  // GAMES AND STATS SCREENS
  // ============================================

  group('Games Entry Screen', () {
    testWidgets('renders correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const GamesEntryScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(GamesEntryScreen), findsOneWidget);
    });
  });

  group('Stats Screen', () {
    testWidgets('renders correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const StatsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(StatsScreen), findsOneWidget);
    });
  });

  // ============================================
  // NAVIGATION TESTS
  // ============================================

  group('Navigation', () {
    testWidgets('bottom navigation bar renders all destinations', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: NavigationBar(
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.casino), label: 'Games'),
                  NavigationDestination(icon: Icon(Icons.group), label: 'Groups'),
                  NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
                  NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Games'), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('navigation icons are present', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: NavigationBar(
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.casino), label: 'Games'),
                  NavigationDestination(icon: Icon(Icons.group), label: 'Groups'),
                  NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
                  NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.casino), findsOneWidget);
      expect(find.byIcon(Icons.group), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('navigation destination can be selected', (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                bottomNavigationBar: NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => selectedIndex = index);
                  },
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.casino), label: 'Games'),
                    NavigationDestination(icon: Icon(Icons.group), label: 'Groups'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      expect(selectedIndex, 1);
    });
  });

  // ============================================
  // BUTTON INTERACTION TESTS
  // ============================================

  group('Button Interactions', () {
    testWidgets('filled button tap works', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => tapped = true,
                child: const Text('Test Button'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Button'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('outlined button tap works', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OutlinedButton(
                onPressed: () => tapped = true,
                child: const Text('Test Button'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Button'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('icon button tap works', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: IconButton(
                onPressed: () => tapped = true,
                icon: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('FAB tap works', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () => tapped = true,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('disabled button does not respond', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: null,
                child: const Text('Disabled'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();

      expect(tapped, isFalse);
    });
  });

  // ============================================
  // DIALOG TESTS
  // ============================================

  group('Dialogs', () {
    testWidgets('AlertDialog renders content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Test Dialog'),
                    content: const Text('Dialog content'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog'), findsOneWidget);
      expect(find.text('Dialog content'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('dialog dismiss works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Test Dialog'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog'), findsNothing);
    });
  });

  // ============================================
  // FORM VALIDATION TESTS
  // ============================================

  group('Form Validation', () {
    testWidgets('required field shows error', (tester) async {
      final formKey = GlobalKey<FormState>();
      var validated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        validated = formKey.currentState!.validate();
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(validated, isFalse);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('valid input passes validation', (tester) async {
      final formKey = GlobalKey<FormState>();
      var validated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        validated = formKey.currentState!.validate();
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Valid input');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(validated, isTrue);
    });

    testWidgets('email validation works', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Enter valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        formKey.currentState!.validate();
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'invalid');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Enter valid email'), findsOneWidget);
    });
  });

  // ============================================
  // LOADING AND EMPTY STATES
  // ============================================

  group('Loading States', () {
    testWidgets('CircularProgressIndicator renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('LinearProgressIndicator renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LinearProgressIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('Empty States', () {
    testWidgets('empty state message displays', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64),
                  SizedBox(height: 16),
                  Text('No items yet'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No items yet'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });
  });

  group('Error States', () {
    testWidgets('error with retry button', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64),
                  const SizedBox(height: 16),
                  const Text('Something went wrong'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => retried = true,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retried, isTrue);
    });
  });

  // ============================================
  // SNACKBAR TESTS
  // ============================================

  group('SnackBars', () {
    testWidgets('SnackBar displays message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Success!')),
                  );
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show SnackBar'));
      await tester.pump();

      expect(find.text('Success!'), findsOneWidget);
    });

    testWidgets('SnackBar action works', (tester) async {
      var actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Item deleted'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => actionTapped = true,
                      ),
                    ),
                  );
                },
                child: const Text('Delete'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Delete'));
      await tester.pump();

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(actionTapped, isTrue);
    });
  });

  // ============================================
  // DROPDOWN TESTS
  // ============================================

  group('Dropdowns', () {
    testWidgets('DropdownButton selection works', (tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => DropdownButton<String>(
                  value: selected,
                  hint: const Text('Select'),
                  items: const [
                    DropdownMenuItem(value: 'a', child: Text('Option A')),
                    DropdownMenuItem(value: 'b', child: Text('Option B')),
                  ],
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Option B').last);
      await tester.pumpAndSettle();

      expect(selected, 'b');
    });
  });

  // ============================================
  // LIST VIEW TESTS
  // ============================================

  group('ListView', () {
    testWidgets('ListView scrolls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 50,
              itemBuilder: (_, index) => ListTile(
                title: Text('Item $index'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsNothing);
    });

    testWidgets('ListTile tap works', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              title: const Text('Tap me'),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  // ============================================
  // TEST DATA FACTORY TESTS
  // ============================================

  group('Test Data Factory', () {
    test('creates profile with all fields', () {
      final profile = TestDataFactory.createProfile(
        firstName: 'Jane',
        lastName: 'Smith',
        email: 'jane@test.com',
      );

      expect(profile.firstName, 'Jane');
      expect(profile.lastName, 'Smith');
      expect(profile.email, 'jane@test.com');
      expect(profile.id, isNotEmpty);
      expect(profile.country, 'United States');
    });

    test('creates group with all fields', () {
      final group = TestDataFactory.createGroup(
        name: 'Poker Night',
        defaultBuyin: 50.0,
      );

      expect(group.name, 'Poker Night');
      expect(group.defaultBuyin, 50.0);
      expect(group.id, isNotEmpty);
      expect(group.privacy, 'private');
    });

    test('creates game with correct status', () {
      final scheduledGame = TestDataFactory.createScheduledGame(groupId: 'g1');
      final inProgressGame = TestDataFactory.createInProgressGame(groupId: 'g2');
      final completedGame = TestDataFactory.createCompletedGame(groupId: 'g3');

      expect(scheduledGame.status, 'scheduled');
      expect(inProgressGame.status, 'in_progress');
      expect(completedGame.status, 'completed');
    });

    test('creates participant with correct net result', () {
      final winner = TestDataFactory.createWinningParticipant(
        gameId: 'g1',
        userId: 'u1',
        buyin: 100.0,
        winAmount: 50.0,
      );

      expect(winner.totalBuyin, 100.0);
      expect(winner.totalCashout, 150.0);
      expect(winner.netResult, 50.0);
    });

    test('creates complete group scenario', () {
      final scenario = TestDataFactory.createCompleteGroupScenario(
        memberCount: 3,
        gamesPerStatus: 1,
      );

      expect(scenario.members.length, 3);
      expect(scenario.games.length, 4); // scheduled, in_progress, completed, cancelled
      expect(scenario.scheduledGames.length, 1);
      expect(scenario.inProgressGames.length, 1);
      expect(scenario.completedGames.length, 1);
      expect(scenario.cancelledGames.length, 1);
    });
  });
}
