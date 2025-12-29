import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/route_constants.dart';
import '../core/services/supabase_service.dart';
import '../features/auth/presentation/screens/sign_in_screen.dart';
import '../features/auth/presentation/screens/sign_up_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/groups/presentation/screens/groups_list_screen.dart';
import '../features/groups/presentation/screens/create_group_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteConstants.signIn,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthenticated = SupabaseService.isAuthenticated;
      
      // Allow auth routes
      if (location == RouteConstants.signIn || location == RouteConstants.signUp) {
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
    GroupsListScreen(),
    Center(child: Text('Games')),
    Center(child: Text('Statistics')),
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
            icon: Icon(Icons.group),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.casino),
            label: 'Games',
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
