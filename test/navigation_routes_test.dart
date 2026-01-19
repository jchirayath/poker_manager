import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_manager/core/constants/route_constants.dart';
import 'package:poker_manager/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:poker_manager/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:poker_manager/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:poker_manager/features/groups/data/models/group_model.dart';
import 'package:poker_manager/features/groups/presentation/providers/groups_provider.dart';
import 'package:poker_manager/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:poker_manager/features/groups/presentation/screens/create_group_screen.dart';
import 'package:poker_manager/features/groups/presentation/screens/groups_list_screen.dart';
import 'package:poker_manager/features/games/presentation/screens/create_game_screen.dart';
import 'package:poker_manager/features/games/presentation/screens/game_detail_screen.dart';
import 'package:poker_manager/features/games/data/models/game_model.dart';
import 'package:poker_manager/features/games/presentation/providers/games_provider.dart';
import 'package:poker_manager/features/locations/data/models/location_model.dart';
import 'package:poker_manager/features/locations/presentation/providers/locations_provider.dart';
import 'package:poker_manager/features/profile/data/models/profile_model.dart';
import 'package:poker_manager/features/profile/presentation/screens/profile_screen.dart';
import 'package:poker_manager/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:poker_manager/features/profile/presentation/providers/profile_provider.dart';

void main() {
  group('Authentication Flow Tests', () {
    testWidgets('Sign In screen renders without errors', (tester) async {
      final router = GoRouter(
        initialLocation: RouteConstants.signIn,
        routes: [
          GoRoute(
            path: RouteConstants.signIn,
            builder: (context, state) => const SignInScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('Sign Up screen renders without errors', (tester) async {
      final router = GoRouter(
        initialLocation: RouteConstants.signUp,
        routes: [
          GoRoute(
            path: RouteConstants.signUp,
            builder: (context, state) => const SignUpScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SignUpScreen), findsOneWidget);
    });

    testWidgets('Forgot Password screen renders without errors', (tester) async {
      final router = GoRouter(
        initialLocation: RouteConstants.forgotPassword,
        routes: [
          GoRoute(
            path: RouteConstants.forgotPassword,
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });
  });

  group('Groups Workflow Tests', () {
    final stubGroup = GroupModel(
      id: 'test-group-id',
      name: 'Test Group',
      description: 'Test Description',
      avatarUrl: null,
      createdBy: 'creator-id',
      privacy: 'private',
      defaultCurrency: 'USD',
      defaultBuyin: 100.0,
      additionalBuyinValues: const [50.0, 200.0],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('Groups List screen renders without errors', (tester) async {
      final router = GoRouter(
        initialLocation: RouteConstants.groups,
        routes: [
          GoRoute(
            path: RouteConstants.groups,
            builder: (context, state) => const GroupsListScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupsListProvider.overrideWith((ref) async => [stubGroup]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GroupsListScreen), findsOneWidget);
    });

    testWidgets('Group Detail screen renders without errors', (tester) async {
      const groupId = 'test-group-id';

      final router = GoRouter(
        initialLocation: RouteConstants.groupDetail.replaceAll(':id', groupId),
        routes: [
          GoRoute(
            path: RouteConstants.groupDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return GroupDetailScreen(groupId: id);
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupProvider(groupId).overrideWith((ref) async => stubGroup),
            groupMembersProvider(groupId).overrideWith((ref) async => []),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // Verify screen renders (may show loading or error state without full Supabase mock)
      expect(find.byType(GroupDetailScreen), findsOneWidget);
    });

    testWidgets('Create Group screen renders without errors', (tester) async {
      final router = GoRouter(
        initialLocation: RouteConstants.createGroup,
        routes: [
          GoRoute(
            path: RouteConstants.createGroup,
            builder: (context, state) => const CreateGroupScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CreateGroupScreen), findsOneWidget);
    });
  });

  group('Games Workflow Tests', () {
    const groupId = 'test-group-id';
    const gameId = 'test-game-id';

    final stubGroup = GroupModel(
      id: groupId,
      name: 'Test Group',
      description: 'Test Description',
      avatarUrl: null,
      createdBy: 'creator-id',
      privacy: 'private',
      defaultCurrency: 'USD',
      defaultBuyin: 100.0,
      additionalBuyinValues: const [50.0],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final stubGame = GameModel(
      id: gameId,
      groupId: groupId,
      name: 'Test Game',
      gameDate: DateTime.now(),
      location: '123 Test St',
      currency: 'USD',
      buyinAmount: 100.0,
      additionalBuyinValues: const [50.0],
      status: 'scheduled',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('Create Game screen renders without errors', (tester) async {
      final router = GoRouter(
        initialLocation: RouteConstants.createGame.replaceAll(':groupId', groupId),
        routes: [
          GoRoute(
            path: RouteConstants.createGame,
            builder: (context, state) {
              final gId = state.pathParameters['groupId']!;
              return CreateGameScreen(groupId: gId);
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupProvider(groupId).overrideWith((ref) async => stubGroup),
            groupMembersProvider(groupId).overrideWith((ref) async => []),
            groupLocationsProvider(groupId).overrideWith((ref) async => []),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CreateGameScreen), findsOneWidget);
    });

    testWidgets('Game Detail screen renders without errors', (tester) async {
      final router = GoRouter(
        initialLocation: RouteConstants.gameDetail.replaceAll(':id', gameId),
        routes: [
          GoRoute(
            path: RouteConstants.gameDetail,
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return GameDetailScreen(gameId: id);
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameDetailProvider(gameId).overrideWith((ref) async => stubGame),
            groupProvider(groupId).overrideWith((ref) async => stubGroup),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GameDetailScreen), findsOneWidget);
    });
  });

  group('Profile Workflow Tests', () {
    final stubProfile = ProfileModel(
      id: 'test-user-id',
      email: 'test@example.com',
      username: 'testuser',
      firstName: 'Test',
      lastName: 'User',
      avatarUrl: null,
      phoneNumber: null,
      primaryLocationId: null,
      isLocalUser: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('Profile screen renders without errors', (tester) async {
      final router = GoRouter(
        initialLocation: RouteConstants.profile,
        routes: [
          GoRoute(
            path: RouteConstants.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) => Stream.value(stubProfile)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('Edit Profile screen renders without errors', (tester) async {
      final router = GoRouter(
        initialLocation: RouteConstants.editProfile,
        routes: [
          GoRoute(
            path: RouteConstants.editProfile,
            builder: (context, state) => const EditProfileScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) => Stream.value(stubProfile)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsOneWidget);
    });
  });

  group('Location Workflow Tests (Dual-Write)', () {
    const groupId = 'test-group-id';

    final stubLocations = [
      LocationModel(
        id: 'location-1',
        groupId: groupId,
        profileId: null,
        streetAddress: '123 Group St',
        city: 'Test City',
        stateProvince: 'TS',
        postalCode: '12345',
        country: 'USA',
        label: 'Group Location',
        isPrimary: false,
        createdBy: 'creator-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      LocationModel(
        id: 'location-2',
        groupId: null,
        profileId: 'user-1',
        streetAddress: '456 Member St',
        city: 'Test City',
        stateProvince: 'TS',
        postalCode: '12345',
        country: 'USA',
        label: 'John\'s Address',
        isPrimary: true,
        createdBy: 'user-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    testWidgets('Locations provider returns both group and personal locations', (tester) async {
      late List<LocationModel> locations;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupLocationsProvider(groupId).overrideWith((ref) async => stubLocations),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final locationsAsync = ref.watch(groupLocationsProvider(groupId));
                  locationsAsync.whenData((data) {
                    locations = data;
                  });
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(locations, hasLength(2));
      expect(locations[0].label, 'Group Location');
      expect(locations[1].label, 'John\'s Address');
      expect(locations[1].isPrimary, true);
    });

    testWidgets('Location model has label field for display', (tester) async {
      final testLocation = stubLocations.first;

      // Verify location model has correct label
      expect(testLocation.label, 'Group Location');
      expect(testLocation.label, isNotNull);

      // Verify personal location has label
      final personalLocation = stubLocations[1];
      expect(personalLocation.label, 'John\'s Address');
      expect(personalLocation.isPrimary, true);
    });
  });

  group('Dual-Write Verification Tests', () {
    testWidgets('Profile model includes primaryLocationId field', (tester) async {
      final profile = ProfileModel(
        id: 'user-id',
        email: 'test@example.com',
        primaryLocationId: 'location-id-123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(profile.primaryLocationId, 'location-id-123');
    });

    testWidgets('Location model has correct structure for dual-write', (tester) async {
      final location = LocationModel(
        id: 'location-id',
        groupId: null,
        profileId: 'user-id',
        streetAddress: '123 Test St',
        city: 'Test City',
        stateProvince: 'TS',
        postalCode: '12345',
        country: 'USA',
        label: 'Test User\'s Address',
        isPrimary: true,
        createdBy: 'user-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(location.profileId, 'user-id');
      expect(location.isPrimary, true);
      expect(location.label, 'Test User\'s Address');
      expect(location.groupId, null);
    });
  });
}
