import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_manager/core/constants/route_constants.dart';
import 'package:poker_manager/features/groups/data/models/group_model.dart';
import 'package:poker_manager/features/groups/presentation/providers/groups_provider.dart';
import 'package:poker_manager/features/groups/presentation/screens/group_detail_screen.dart';

void main() {
  testWidgets('Navigates to group detail and renders content', (tester) async {
    const groupId = 'test-group-id';

    // Stub group data
    final stubGroup = GroupModel(
      id: groupId,
      name: 'Test Group',
      description: 'Desc',
      avatarUrl: null,
      createdBy: 'creator-id',
      privacy: 'private',
      defaultCurrency: 'USD',
      defaultBuyin: 100.0,
      additionalBuyinValues: const [50.0],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Build a router that uses the same path
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
          // Override groupProvider and groupMembersProvider for this id
          groupProvider(groupId).overrideWith((ref) async => stubGroup),
          groupMembersProvider(groupId).overrideWith((ref) async => []),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    // Let futures resolve
    await tester.pumpAndSettle();

    expect(find.text('Group Details'), findsOneWidget);
    expect(find.text('Test Group'), findsOneWidget);
    expect(find.text('USD 100.00 buy-in'), findsOneWidget);
  });
}
