# Theme Consistency Guide - Poker Manager

## Overview
This document ensures consistent UI/UX design across all screens using Material 3 design system with green seed color.

## Verification Checklist

### AppBar Styling
- [x] All AppBars have `centerTitle: true`
- [x] All AppBars have `elevation: 0`
- [x] Title text uses Theme.of(context) text styles
- [x] Back button uses `Icons.arrow_back`
- [x] Consistent padding (16px for actions)

### Card & Container Styling
- [x] All Cards use `borderRadius: 12`
- [x] All Cards have `elevation: 2`
- [x] Card padding: `16px` (EdgeInsets.all(16))
- [x] Card margins: `12px bottom` for spacing
- [x] No hardcoded colors - use Theme.of(context).colorScheme

### Input Fields & Forms
- [x] All TextFormFields use OutlineInputBorder
- [x] Border radius: `8px` for inputs
- [x] `filled: true` for all input fields
- [x] Consistent label text styling
- [x] Error messages use Material error color

### Buttons & Interactive Elements
- [x] ElevatedButtons use centerTitle and consistent padding
- [x] Button padding: `24px horizontal, 12px vertical`
- [x] Button shape: RoundedRectangleBorder with 8px radius
- [x] Icon colors from Theme.of(context).colorScheme
- [x] All buttons use enabled/disabled states properly

### Table Styling
- [x] Use Material Table widget for structured data
- [x] Header cells use bold, Material textTheme.labelMedium
- [x] Data cells aligned appropriately (left: text, right: numbers)
- [x] Row alternating backgrounds (optional) for readability
- [x] Cell padding: vertical 4px, horizontal 8px
- [x] Use _cell helper function for consistent styling
- [x] Current user highlighting: secondaryContainer (0.35 opacity)
- [x] Current user text: bold (FontWeight.w700) with onSecondaryContainer color

### Color Usage

#### Semantic Colors
```dart
// Access colors from theme
final colorScheme = Theme.of(context).colorScheme;

// Primary actions and highlights
colorScheme.primary          // Green (default)
colorScheme.secondary        // Green variant
colorScheme.error            // Red for errors
colorScheme.surface          // Background
colorScheme.onSurface        // Text on background

// Highlights and selections
colorScheme.secondaryContainer   // Light green (0.35 opacity)
colorScheme.onSecondaryContainer // Dark green text

// Status colors
Colors.green    // Success, positive results, wins
Colors.red      // Errors, losses, deletion
Colors.orange   // Warning, pending, special status
Colors.blue     // Info, secondary action
```

#### Specific Color Applications

**Win/Loss Display**:
```dart
// Win: positive result
green = Colors.green (#4CAF50)

// Loss: negative result
red = Colors.red (#F44336)

// Neutral/Break-even
grey = Colors.grey[700]
```

**Role Indicators**:
```dart
// Creator (orange)
color: Colors.orange

// Admin (blue)
color: Colors.blue

// Member (default/grey)
color: null  // Use default text color
```

**Current User Highlighting**:
```dart
final bg = Theme.of(context)
    .colorScheme
    .secondaryContainer
    .withOpacity(0.35);
final fg = Theme.of(context)
    .colorScheme
    .onSecondaryContainer;
final weight = FontWeight.w700;
```

### Typography Standards

```dart
// Screen titles
Theme.of(context).textTheme.headlineSmall

// Section headers
Theme.of(context).textTheme.titleMedium

// Body text
Theme.of(context).textTheme.bodyMedium

// Small/helper text
Theme.of(context).textTheme.bodySmall

// Labels
Theme.of(context).textTheme.labelMedium

// Table headers
TextStyle(fontSize: 11, fontWeight: FontWeight.bold)

// Bold emphasis
FontWeight.w600 (semi-bold)
FontWeight.w700 (bold)
FontWeight.bold (very bold)
```

### Spacing Standards

```dart
// Page-level padding
EdgeInsets.all(16)              // 16px on all sides

// Section dividers
SizedBox(height: 12)             // 12px between sections

// Item spacing
SizedBox(height: 8)              // 8px between list items

// Component padding
EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 8,
)

// Table cell padding
EdgeInsets.symmetric(
  vertical: 4,
  horizontal: 8,
)
```

### Border Radius Standards

```dart
// Cards and large containers
BorderRadius.circular(12)        // 12px

// Input fields and buttons
BorderRadius.circular(8)         // 8px

// Small/chip elements
BorderRadius.circular(4)         // 4px
```

### Elevation Standards

```dart
// Cards
elevation: 2                     // Subtle shadow

// App bars
elevation: 0                     // No shadow (flat design)

// Dialogs
elevation: default (Material)
```

## Screen-by-Screen Verification

### Group Detail Screen ✅
- [x] AppBar centered with back button
- [x] Group info card with 16px padding
- [x] Members list with Material cards
- [x] Member name: blue, clickable, no underline
- [x] Member detail popup: AlertDialog with avatar, color-coded role
- [x] "Manage Games" & "Manage Members" buttons: elevated with icons
- [x] Action buttons in bottom navigation bar (16px padding)
- [x] Role indicators: orange (creator), blue (admin), grey (member)
- [x] Local player badge: grey background
- [x] Current user highlight: secondaryContainer (0.35 opacity)

### Stats Screen ✅
- [x] Segmented button selector: Recent game / Group summary
- [x] Time filter chips: Material Chip styling
- [x] Game search: Material TextField
- [x] Game cards: 12px radius, 2pt elevation, 16px padding
- [x] Rankings table: Material Table styling
- [x] Table headers: bold, consistent styling
- [x] Current user highlighting: secondary container background + bold text
- [x] Win/Loss colors: green (win), red (loss)
- [x] Summary card: Material Card, 16px padding
- [x] Game-by-game breakdown: Cards with 12px radius
- [x] Per-game rankings: Table with rank, name, net result
- [x] Win/Loss summary: Table with colored text

### Games Entry Screen
- [x] Date/time display: consistent formatting
- [x] Game status cards: colored appropriately
- [x] Floating action button: standard Material FAB
- [x] Game list items: Material ListTiles
- [x] Status badges: semantic colors

### Profile Screen
- [x] Avatar: circle with initials
- [x] Profile info: organized cards
- [x] Edit button: consistent styling
- [x] Logout: error color button

## Non-Compliance Issues Found

### Status: ✅ ALL CLEAR
All screens reviewed for consistency:
- Theme colors properly used from Theme.of(context)
- Spacing follows 16px/12px/8px standards
- Border radius standards applied (12px cards, 8px inputs)
- AppBar styling consistent (centered, no elevation)
- Typography uses Material textTheme appropriately

## Implementation Standards

### When Adding New Screens

1. **Always** import `Theme.of(context)` for colors
2. **Never** hardcode colors unless absolutely necessary
3. **Always** use Cards with `borderRadius: BorderRadius.circular(12)`
4. **Always** use OutlineInputBorder for TextFormFields
5. **Always** add comments to major sections
6. **Always** maintain 16px padding for page content
7. **Always** use 12px spacing between sections
8. **Always** test in both light and dark theme modes

### Helper Functions Pattern

Use consistent helper functions for repeated UI elements:

```dart
/// Render a table cell with optional styling
Widget _cell(
  String text, {
  TextAlign align = TextAlign.left,
  Color? color,
  Color? background,
  FontWeight? weight,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: Text(
      text,
      textAlign: align,
      style: TextStyle(
        color: color,
        fontWeight: weight,
      ),
    ),
  );
}

/// Format date for display
String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}

/// Build avatar widget
Widget _avatar(String? url, String fallback) {
  final letter = fallback.isNotEmpty ? fallback[0].toUpperCase() : '?';
  // Avatar implementation
}
```

## Testing Guidelines

### Visual Consistency Testing

1. **Run app in light theme**: `flutter run --dart-define-from-file=env.json`
2. **Run app in dark theme**: Change system theme settings
3. **Check each screen**:
   - AppBar centered and styled correctly
   - Cards have proper spacing and elevation
   - Colors readable in both themes
   - Text sizes proportional
   - Icons visible and appropriately sized

### Theme Switching Testing

```bash
# Test theme switching by changing system settings
# iOS: Settings > Developer > Appearance
# Android: Settings > Display > Theme

# Or use Flutter DevTools theme switcher
```

## References

### Material 3 Design
- https://m3.material.io/
- ColorScheme generation from seed: https://m3.material.io/styles/color/the-color-system/color-roles

### Flutter Theme
- Theme.of(context): https://api.flutter.dev/flutter/material/Theme/of.html
- Material 3 TextTheme: https://api.flutter.dev/flutter/material/TextTheme-class.html

### Poker Manager Theme
- Light Theme: `lib/app/theme.dart` - lightTheme getter
- Dark Theme: `lib/app/theme.dart` - darkTheme getter

---

**Last Updated**: January 4, 2026
**Status**: ✅ COMPLIANT - All screens follow Material 3 theme standards
