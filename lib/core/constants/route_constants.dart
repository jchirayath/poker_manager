class RouteConstants {
  static const String splash = '/';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';

  static const String home = '/home';
  static const String groups = '/groups';
  static const String groupDetail = '/groups/:id';
  static const String createGroup = '/groups/create';
  static const String manageMembers = '/groups/:id/members';
  static const String localUserCreate = '/groups/:id/local-user';
  static const String localUserEdit = '/groups/:groupId/local-user/:userId';

  static const String games = '/games';
  static const String gameDetail = '/games/:id';
  static const String createGame = '/groups/:groupId/games/create';
  static const String activeGame = '/games/:id/active';
  static const String gameHistory = '/games/history';

  static const String settlement = '/games/:id/settlement';

  static const String statistics = '/statistics';
  static const String leaderboard = '/groups/:id/leaderboard';

  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
}
