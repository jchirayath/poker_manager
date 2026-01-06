# Poker Manager - Developer Quick Reference

## 🚀 Quick Start

### Installation
```bash
flutter clean
flutter pub get
flutter run --dart-define-from-file=env.json
```

### Project Structure
```
lib/
├── main.dart (app entry)
├── app/theme.dart (Material 3 theme)
├── features/ (feature modules)
│   ├── auth/
│   ├── games/
│   ├── groups/
│   ├── profile/
│   ├── settlements/
│   └── stats/
└── core/ (services, constants)
```

---

## 🎨 Theme Reference

### Always Use
```dart
// Colors
Theme.of(context).colorScheme.primary
Theme.of(context).colorScheme.secondary
Theme.of(context).colorScheme.error

// Typography
Theme.of(context).textTheme.headlineSmall
Theme.of(context).textTheme.bodyMedium
Theme.of(context).textTheme.labelSmall

// Never hardcode colors!
```

### Spacing Standards
```dart
EdgeInsets.all(16)              // Page padding
SizedBox(height: 12)             // Section gap
SizedBox(height: 8)              // Item gap
```

### Border Radius
```dart
BorderRadius.circular(12)        // Cards
BorderRadius.circular(8)         // Inputs/Buttons
BorderRadius.circular(4)         // Small items
```

### Role Colors
```dart
Colors.orange    // Creator
Colors.blue      // Admin
Colors.grey      // Member
```

### Status Colors
```dart
Colors.green     // Win, Success
Colors.red       // Loss, Error
Colors.orange    // Pending, Warning
```

### Current User Highlight
```dart
final bg = Theme.of(context)
    .colorScheme
    .secondaryContainer
    .withOpacity(0.35);
final fg = Theme.of(context).colorScheme.onSecondaryContainer;
final weight = FontWeight.w700;
```

---

## 📱 Screen Navigation

### Main Routes
```dart
context.push('/groups')                    // Groups list
context.push('/groups/:id')                // Group details
context.push('/groups/:id/members')        // Manage members
context.push('/games')                     // Games dashboard
```

### Navigation Patterns
```dart
context.push(path)                         // Push route
context.pushReplacementNamed(name)         // Replace route
Navigator.pop(context)                     // Pop route
```

---

## 🔧 Riverpod State Management

### Common Patterns
```dart
// Watch provider in build
final data = ref.watch(dataProvider);

// Use provider in action
final controller = ref.read(controllerProvider);

// Invalidate on change
ref.invalidate(dataProvider);

// Family providers (with parameters)
final data = ref.watch(dataProvider('param'));
```

---

## 📝 File Header Template

```dart
/// [ScreenName] - Brief description
/// 
/// Displays: What is shown
/// Features: Key features
/// Navigation: Routes and navigation
import 'package:flutter/material.dart';
// ... imports ...

/// Main widget description
class ScreenName extends ConsumerStatefulWidget {
  // ...
}
```

---

## 🎯 Common Helper Functions

### Format Date
```dart
String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}
```

### Table Cell
```dart
Widget _cell(
  String text, {
  TextAlign align = TextAlign.left,
  Color? color,
  Color? background,
  FontWeight? weight,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: Text(text, textAlign: align, style: TextStyle(color: color, fontWeight: weight)),
  );
}
```

### Avatar Widget
```dart
Widget _avatar(String? url, String fallback) {
  final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : '?';
  if ((url ?? '').isEmpty) {
    return CircleAvatar(
      backgroundColor: Colors.grey.shade200,
      child: Text(letter),
    );
  }
  return CircleAvatar(backgroundImage: NetworkImage(url!));
}
```

---

## 🚨 Error Handling

### Log Format
```dart
debugPrint('🔴 Error: message');      // Critical
debugPrint('🔵 Info: message');       // Information
debugPrint('✅ Success: message');    // Success
```

### User Feedback
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Message')),
);
```

---

## 📊 Stats Screen Features

### Recent Games
- Up to 4 games displayed
- Filters: Week, Month, Year, All
- Search by game name
- Current user highlighted

### Group Summary
- Game-by-game breakdown
- Player rankings per game
- Win/Loss status table
- Player record summary

### Highlighting Rules
- Same net result = Same rank
- Current user: secondary background + bold
- Green: Wins
- Red: Losses

---

## 👥 Group Details Features

### Member Actions
- Click name for details popup
- Details show: Email, Phone, Address, Role, Status, Join date
- Color-coded roles

### Admin Controls
- Toggle admin role
- Remove members
- Manage Games button
- Manage Members button

---

## 🧪 Testing Checklist

- [ ] Light theme display
- [ ] Dark theme display
- [ ] AppBar centered/styled
- [ ] Cards properly styled
- [ ] Buttons responsive
- [ ] Tables align correctly
- [ ] Colors use Theme.of()
- [ ] Spacing consistent
- [ ] No hardcoded colors
- [ ] Text readable

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| README_COMPREHENSIVE.md | Complete project guide |
| FEATURES.md | Feature-level details |
| THEME_CONSISTENCY.md | Theme standards |
| CODE_REVIEW_SUMMARY.md | Review findings |

---

## 🔍 Code Style Rules

1. **Always** use Theme.of(context) for colors
2. **Never** hardcode color values
3. **Always** add file header comments
4. **Always** use const constructors
5. **Always** handle loading/error states
6. **Always** test light and dark themes
7. **Never** ignore theme colors
8. **Never** use deprecated widgets

---

## 💡 Tips & Tricks

### Quick Theme Access
```dart
final colors = Theme.of(context).colorScheme;
final textStyles = Theme.of(context).textTheme;
```

### Conditional Colors
```dart
final isActive = status == 'active';
final color = isActive ? Colors.green : Colors.grey;
```

### Multi-Line Strings
```dart
final message = '''Line 1
Line 2
Line 3''';
```

### Safe Navigation
```dart
final value = data?.property ?? defaultValue;
```

---

## 🐛 Troubleshooting

### Build Issues
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Theme Not Applied
- Check Theme.of(context) usage
- Verify MaterialApp has theme set
- Check useMaterial3: true

### Navigation Problems
- Verify route constants match
- Check GoRouter configuration
- Test with `context.go()` vs `context.push()`

### Provider Errors
- Check provider initialization
- Verify invalidation strategy
- Review Riverpod docs

---

**Last Updated**: January 4, 2026
**Status**: ✅ COMPLETE & VERIFIED
