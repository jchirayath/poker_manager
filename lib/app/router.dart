import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/route_constants.dart';
import '../core/services/supabase_service.dart';
import '../features/auth/presentation/screens/sign_in_screen.dart';
import '../features/auth/presentation/screens/sign_up_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/groups/presentation/screens/groups_list_screen.dart';
import '../features/groups/presentation/screens/create_group_screen.dart';
import '../features/groups/presentation/screens/group_detail_screen.dart';
import '../features/groups/presentation/screens/manage_members_screen.dart';
import '../features/groups/presentation/screens/invite_members_screen.dart';
import '../features/groups/presentation/screens/edit_group_screen.dart';
import '../features/groups/presentation/screens/local_user_form_screen.dart';
import '../features/games/presentation/screens/games_entry_screen.dart';
import '../features/profile/data/models/profile_model.dart';
import '../features/stats/presentation/screens/stats_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteConstants.signIn,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthenticated = SupabaseService.isAuthenticated;
      
      // Allow auth routes
      if (location == RouteConstants.signIn ||
          location == RouteConstants.signUp ||
          location == RouteConstants.forgotPassword) {
        // If authenticated, redirect to home
        if (isAuthenticated) {
          return RouteConstants.home;
        }
        // Otherwise, stay on auth route
        return null;
      }

      // For all other routes, require authentication
      if (!isAuthenticated) {
        return RouteConstants.signIn;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteConstants.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: RouteConstants.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: RouteConstants.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteConstants.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RouteConstants.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: RouteConstants.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RouteConstants.groups,
        builder: (context, state) => const GroupsListScreen(),
      ),
      GoRoute(
        path: RouteConstants.createGroup,
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: RouteConstants.groupDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          if (id.isEmpty) {
            return const Scaffold(body: Center(child: Text('Invalid group ID')));
          }
          return GroupDetailScreen(groupId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.manageMembers,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          if (id.isEmpty) {
            return const Scaffold(body: Center(child: Text('Invalid group ID')));
          }
          return ManageMembersScreen(groupId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.localUserCreate,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          if (id.isEmpty) {
            return const Scaffold(body: Center(child: Text('Invalid group ID')));
          }
          return LocalUserFormScreen(groupId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.localUserEdit,
        builder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          final userId = state.pathParameters['userId'] ?? '';
          if (groupId.isEmpty || userId.isEmpty) {
            return const Scaffold(body: Center(child: Text('Invalid parameters')));
          }
          final profile = state.extra is ProfileModel ? state.extra as ProfileModel : null;
          return LocalUserFormScreen(groupId: groupId, userId: userId, initialProfile: profile);
        },
      ),
      GoRoute(
        path: RouteConstants.inviteMembers,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          if (id.isEmpty) {
            return const Scaffold(body: Center(child: Text('Invalid group ID')));
          }
          return InviteMembersScreen(groupId: id);
        },
      ),
      GoRoute(
        path: RouteConstants.editGroup,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          if (id.isEmpty) {
            return const Scaffold(body: Center(child: Text('Invalid group ID')));
          }
          final extra = state.extra;
          final extraMap = extra is Map<String, dynamic> ? extra : <String, dynamic>{};
          return EditGroupScreen(
            groupId: id,
            name: extraMap['name'] as String? ?? '',
            description: extraMap['description'] as String?,
            avatarUrl: extraMap['avatarUrl'] as String?,
            privacy: extraMap['privacy'] as String? ?? 'private',
            currency: extraMap['currency'] as String? ?? 'USD',
            defaultBuyin: (extraMap['defaultBuyin'] as num?)?.toDouble() ?? 100.0,
            additionalBuyins: extraMap['additionalBuyins'] is List
                ? List<double>.from((extraMap['additionalBuyins'] as List).map((e) => (e as num).toDouble()))
                : <double>[],
          );
        },
      ),
    ],
  );
});

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    GamesEntryScreen(),
    GroupsListScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.casino),
            label: 'Games',
          ),
          NavigationDestination(
            icon: Icon(Icons.group),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
