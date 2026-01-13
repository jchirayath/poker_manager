import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How to Use')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'How to Use ${AppConstants.appNameWithBeta}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const Text(
            '1. Create or Join a Group\n'
            '   - Tap "+ Create Game" or use the Groups tab to create or join a poker group.\n'
            '\n'
            '2. Schedule or Start a Game\n'
            '   - In your group, tap "Create New Game" to schedule a poker night.\n'
            '\n'
            '3. Manage Games\n'
            '   - View active, scheduled, completed, and cancelled games from the Games tab.\n'
            '   - Tap a game for details, to edit, or to cancel.\n'
            '\n'
            '4. Track Stats\n'
            '   - Use the Stats tab to view your performance, recent games, and group rankings.\n'
            '\n'
            '5. Record Results\n'
            '   - After a game, enter results and payouts to keep group stats up to date.\n'
            '\n'
            '6. Feedback & Help\n'
            '   - Use the menu to send feedback or learn more about the app.',
          ),
        ],
      ),
    );
  }
}
