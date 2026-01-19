# UI Cleanup Task List - Poker Manager

This document outlines all tasks needed to achieve theme consistency, responsive design, and UI best practices across the application.

---

## Summary Statistics

| Category | Files Affected | Occurrences | Priority |
|----------|---------------|-------------|----------|
| Hardcoded Colors | 27 | 223+ | CRITICAL |
| Hardcoded Font Sizes | 31 | 144 | HIGH |
| BorderRadius Inconsistency | 28 | 317 | MEDIUM |
| Text Overflow Handling | 15 | 31 (missing many) | MEDIUM |
| Opacity/Alpha Inconsistency | 20 | 128 | LOW |
| Responsive Layout (Expanded/Flexible) | 23 | 119 | MEDIUM |

---

## Completed Tasks

### [x] Task 1.1: Create App Colors Constants - COMPLETED
- Created `lib/core/constants/app_colors.dart` with centralized color definitions
- Includes game status colors, RSVP colors, role colors, payment method colors
- Helper methods for alpha values: `withAlpha10`, `withAlpha15`, `withAlpha20`, `withAlpha30`
- Helper methods: `getGameStatusColor()`, `getGameStatusIcon()`, `getGameStatusLabel()`

### [x] Task 3.1: Standardize Game Status Colors - COMPLETED
- Updated `game_header_card.dart` to use `AppColors`
- Updated `games_entry_screen.dart` to use `AppColors`
- Updated `stats_screen.dart` to use `AppColors` (both instances)
- Updated `settlement_summary.dart` PaymentMethod colors to use `AppColors`

**Standardized Color Scheme (source: games_entry_screen.dart):**
| Status | Color | Icon |
|--------|-------|------|
| scheduled | Orange | schedule |
| in_progress | Green | play_arrow |
| completed | Blue | check_circle |
| cancelled | Grey | cancel |

---

## Phase 1: Create Design System Constants (Foundation)

### Task 1.1: Create App Colors Constants
**Priority:** CRITICAL - COMPLETED
**File:** `lib/core/constants/app_colors.dart`

Create a centralized color system for semantic colors:

```dart
class AppColors {
  // Game Status Colors
  static const Color statusScheduled = Colors.orange;
  static const Color statusInProgress = Colors.green;
  static const Color statusCompleted = Colors.blue;
  static const Color statusCancelled = Colors.red;

  // RSVP Status Colors
  static const Color rsvpGoing = Colors.green;
  static const Color rsvpMaybe = Colors.orange;
  static const Color rsvpNotGoing = Colors.red;

  // Role Colors
  static const Color roleCreator = Colors.orange;
  static const Color roleAdmin = Colors.blue;
  static const Color roleMember = Colors.grey;

  // Settlement Colors
  static const Color settlementPending = Colors.orange;
  static const Color settlementCompleted = Colors.green;

  // Payment Method Colors (brand colors)
  static const Color paymentCash = Colors.green;
  static const Color paymentVenmo = Color(0xFF3D95CE);
  static const Color paymentPayPal = Color(0xFF003087);
  static const Color paymentZelle = Color(0xFF6D1ED4);

  // Semantic Colors
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;
  static const Color info = Colors.blue;

  // Helper for background colors with alpha
  static Color withAlpha15(Color color) => color.withValues(alpha: 0.15);
  static Color withAlpha10(Color color) => color.withValues(alpha: 0.10);
  static Color withAlpha20(Color color) => color.withValues(alpha: 0.20);
}
```

**Impact:** All 27 files with hardcoded colors

---

### Task 1.2: Create Spacing Constants
**Priority:** MEDIUM
**File to create:** `lib/core/constants/app_spacing.dart`

```dart
class AppSpacing {
  // Standard spacing scale
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // Standard EdgeInsets
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets dialogPadding = EdgeInsets.all(xl);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: lg, vertical: sm);
  static const EdgeInsets sectionGap = EdgeInsets.only(bottom: md);
}
```

---

### Task 1.3: Create Border Radius Constants
**Priority:** LOW
**File to create:** `lib/core/constants/app_borders.dart`

```dart
class AppBorders {
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;

  // Preset BorderRadius
  static final BorderRadius card = BorderRadius.circular(radiusMd);
  static final BorderRadius button = BorderRadius.circular(radiusSm);
  static final BorderRadius chip = BorderRadius.circular(radiusLg);
  static final BorderRadius bottomSheet = BorderRadius.vertical(top: Radius.circular(radiusXl));
  static final BorderRadius input = BorderRadius.circular(radiusSm);
}
```

---

## Phase 2: Create Reusable UI Components

### Task 2.1: Create Status Badge Widget
**Priority:** HIGH
**File to create:** `lib/core/widgets/status_badge.dart`

Create a unified status badge component used for:
- Game status (scheduled, in_progress, completed, cancelled)
- RSVP status (going, maybe, not_going)
- Settlement status (pending, completed)

This will replace ~30 instances of inline status styling.

**Files affected:**
- `lib/features/games/presentation/widgets/game_detail/game_header_card.dart` (lines 171-218)
- `lib/features/games/presentation/screens/games_entry_screen.dart` (lines 547-567)
- `lib/features/stats/presentation/screens/stats_screen.dart` (lines 330-355)
- `lib/features/games/presentation/widgets/game_detail/rsvp_widgets.dart`

---

### Task 2.2: Create Role Badge Widget
**Priority:** MEDIUM
**File to create:** `lib/core/widgets/role_badge.dart`

Unified role badge for group member roles.

**Files affected:**
- `lib/features/groups/presentation/screens/group_detail_screen.dart`
- `lib/features/groups/presentation/screens/manage_members_screen.dart`

---

### Task 2.3: Create Payment Method Badge Widget
**Priority:** LOW
**File to create:** `lib/core/widgets/payment_badge.dart`

Already partially exists in settlement_summary.dart but should be extracted.

---

## Phase 3: Fix Game Status Color Inconsistencies (CRITICAL)

### Task 3.1: Standardize Game Status Colors
**Priority:** CRITICAL

**Current inconsistency:**

| Status | game_header_card.dart | games_entry_screen.dart | Recommended |
|--------|----------------------|------------------------|-------------|
| scheduled | Blue | Orange | **Orange** |
| in_progress | Orange | Green | **Green** |
| completed | Green | Blue | **Blue** |
| cancelled | Red | Grey | **Grey** |

**Decision needed:** Choose ONE color scheme for all screens.

**Recommended standard (based on semantic meaning):**
- `scheduled` = Orange (future event, pending)
- `in_progress` = Green (active, live)
- `completed` = Blue (done, informational)
- `cancelled` = Grey (inactive)

**Files to update:**
1. `lib/features/games/presentation/widgets/game_detail/game_header_card.dart` - Change scheduled to Orange, in_progress to Green
2. `lib/features/stats/presentation/screens/stats_screen.dart` - Verify matches
3. `lib/features/games/presentation/screens/games_entry_screen.dart` - Already correct

---

## Phase 4: Replace Hardcoded Colors with AppColors

### Task 4.1: Update Games Feature (38+ occurrences)
**Priority:** HIGH

**Files:**
- [ ] `lib/features/games/presentation/widgets/game_detail/settlement_summary.dart` (38 occurrences)
- [ ] `lib/features/games/presentation/widgets/game_detail/participant_list.dart` (13 occurrences)
- [ ] `lib/features/games/presentation/widgets/game_detail/game_action_buttons.dart` (12 occurrences)
- [ ] `lib/features/games/presentation/widgets/cash_out_dialog.dart` (11 occurrences)
- [ ] `lib/features/games/presentation/widgets/game_detail/game_header_card.dart` (10 occurrences)
- [ ] `lib/features/games/presentation/widgets/game_detail/rsvp_widgets.dart` (9 occurrences)
- [ ] `lib/features/games/presentation/screens/game_detail_screen.dart` (9 occurrences)
- [ ] `lib/features/games/presentation/screens/games_entry_screen.dart` (8 occurrences)
- [ ] `lib/features/games/presentation/screens/games_group_selector_screen.dart` (6 occurrences)
- [ ] `lib/features/games/presentation/widgets/game_detail/game_totals_card.dart` (5 occurrences)
- [ ] `lib/features/games/presentation/widgets/game_detail/player_rankings.dart` (4 occurrences)

---

### Task 4.2: Update Stats Feature (34 occurrences)
**Priority:** HIGH

**File:**
- [ ] `lib/features/stats/presentation/screens/stats_screen.dart` (34 occurrences)

---

### Task 4.3: Update Groups Feature (29+ occurrences)
**Priority:** MEDIUM

**Files:**
- [ ] `lib/features/groups/presentation/screens/group_detail_screen.dart` (20 occurrences)
- [ ] `lib/features/groups/presentation/screens/invite_members_screen.dart` (7 occurrences)
- [ ] `lib/features/groups/presentation/screens/groups_list_screen.dart` (4 occurrences)
- [ ] `lib/features/groups/presentation/screens/manage_members_screen.dart` (3 occurrences)

---

### Task 4.4: Update Settlements Feature (11 occurrences)
**Priority:** MEDIUM

**File:**
- [ ] `lib/features/settlements/presentation/screens/settlement_screen.dart` (11 occurrences)

---

### Task 4.5: Update Auth & Profile Features
**Priority:** LOW

**Files:**
- [ ] `lib/features/profile/presentation/screens/edit_profile_screen.dart` (2 occurrences)
- [ ] `lib/features/common/screens/feedback_screen.dart` (4 occurrences)
- [ ] `lib/features/common/widgets/app_drawer.dart` (2 occurrences)

---

## Phase 5: Replace Hardcoded Font Sizes with Theme TextStyles

### Task 5.1: Audit and Document Font Size Usage
**Priority:** HIGH

Current hardcoded sizes found (144 occurrences):
- `fontSize: 10` - 3 occurrences
- `fontSize: 11` - 8 occurrences
- `fontSize: 12` - 45 occurrences (most common)
- `fontSize: 13` - 15 occurrences
- `fontSize: 14` - 20 occurrences
- `fontSize: 16` - 25 occurrences
- `fontSize: 18` - 12 occurrences
- `fontSize: 20` - 8 occurrences
- `fontSize: 24+` - 8 occurrences

**Mapping to Theme TextStyles:**
| Hardcoded Size | Replace With |
|----------------|--------------|
| 10-11 | `labelSmall` |
| 12 | `bodySmall` |
| 13-14 | `bodyMedium` |
| 16 | `bodyLarge` / `titleSmall` |
| 18 | `titleMedium` |
| 20 | `titleLarge` |
| 22-24 | `headlineSmall` |

---

### Task 5.2: Update High-Volume Files
**Priority:** HIGH

**Files with most hardcoded font sizes:**
- [ ] `lib/features/stats/presentation/screens/stats_screen.dart` (23 occurrences)
- [ ] `lib/features/games/presentation/widgets/game_detail/settlement_summary.dart` (16 occurrences)
- [ ] `lib/features/groups/presentation/screens/group_detail_screen.dart` (11 occurrences)
- [ ] `lib/features/groups/presentation/screens/manage_members_screen.dart` (10 occurrences)
- [ ] `lib/features/games/presentation/widgets/cash_out_dialog.dart` (9 occurrences)
- [ ] `lib/features/games/presentation/widgets/game_detail/rsvp_widgets.dart` (9 occurrences)

---

## Phase 6: Fix Responsive Layout Issues

### Task 6.1: Add Text Overflow Handling
**Priority:** MEDIUM

Files missing overflow handling (check each Text widget):
- [ ] `lib/features/stats/presentation/screens/stats_screen.dart`
- [ ] `lib/features/settlements/presentation/screens/settlement_screen.dart`
- [ ] `lib/features/groups/presentation/screens/group_detail_screen.dart`
- [ ] `lib/features/games/presentation/screens/create_game_screen.dart`
- [ ] `lib/features/games/presentation/screens/edit_game_screen.dart`

**Pattern to apply:**
```dart
Text(
  text,
  overflow: TextOverflow.ellipsis,
  maxLines: 1, // or 2 for descriptions
)
```

---

### Task 6.2: Audit Row Widgets for Expanded/Flexible
**Priority:** MEDIUM

Check that all Row widgets with variable-length content use Expanded or Flexible:

**Files to audit:**
- [ ] `lib/features/games/presentation/screens/games_entry_screen.dart`
- [ ] `lib/features/settlements/presentation/screens/settlement_screen.dart`
- [ ] `lib/features/groups/presentation/screens/group_detail_screen.dart`
- [ ] `lib/features/stats/presentation/screens/stats_screen.dart`

---

### Task 6.3: Test on Various Screen Sizes
**Priority:** HIGH

Test all screens on:
- [ ] Small phone (320px width)
- [ ] Standard phone (375px width)
- [ ] Large phone (414px width)
- [ ] Tablet portrait (768px width)
- [ ] Tablet landscape (1024px width)

**Screens to test:**
1. Games Entry Screen
2. Game Detail Screen
3. Settlement Summary
4. Stats Screen
5. Group Detail Screen
6. Profile Screen

---

## Phase 7: Standardize Opacity/Alpha Values

### Task 7.1: Unify Alpha Value Usage
**Priority:** LOW

Current inconsistency:
- Some files use `withOpacity(0.1)`
- Some files use `withValues(alpha: 0.15)`
- Some files use `withValues(alpha: 0.2)`

**Standard to adopt:**
- Light backgrounds: `AppColors.withAlpha15(color)`
- Very light backgrounds: `AppColors.withAlpha10(color)`
- Medium backgrounds: `AppColors.withAlpha20(color)`

**Files to update:** All 20 files using withOpacity/withValues

---

## Phase 8: BorderRadius Standardization

### Task 8.1: Replace Hardcoded BorderRadius Values
**Priority:** LOW

Current values found (317 occurrences):
- `BorderRadius.circular(4)` - cards, containers
- `BorderRadius.circular(6)` - small elements
- `BorderRadius.circular(8)` - buttons, inputs (most common)
- `BorderRadius.circular(12)` - cards (most common)
- `BorderRadius.circular(16)` - chips, badges
- `BorderRadius.circular(20)` - bottom sheets

**Files with most occurrences:**
- [ ] `lib/features/games/presentation/screens/create_game_screen.dart` (42 occurrences)
- [ ] `lib/features/groups/presentation/screens/manage_members_screen.dart` (32 occurrences)
- [ ] `lib/features/games/presentation/widgets/game_detail/settlement_summary.dart` (26 occurrences)
- [ ] `lib/features/games/presentation/screens/edit_game_screen.dart` (26 occurrences)
- [ ] `lib/features/profile/presentation/screens/edit_profile_screen.dart` (26 occurrences)

---

## Testing Checklist

After each phase, verify:

- [ ] All screens render correctly in light mode
- [ ] All screens render correctly in dark mode
- [ ] No text overflow on any screen size
- [ ] Status colors are consistent across all views
- [ ] RSVP colors are consistent across all views
- [ ] All buttons and interactive elements are accessible
- [ ] No visual regressions in existing functionality

---

## Implementation Order

1. **Phase 1** - Create constants (no visual changes, safe)
2. **Phase 3** - Fix critical status color inconsistencies
3. **Phase 2** - Create reusable components
4. **Phase 4** - Replace hardcoded colors (use new constants)
5. **Phase 5** - Replace hardcoded font sizes
6. **Phase 6** - Fix responsive issues
7. **Phase 7 & 8** - Lower priority standardization

---

## Notes

- Always run `flutter analyze` after changes
- Test dark mode after color changes
- Keep backwards compatibility - don't change widget APIs
- Create feature branches for each phase
- Each task should be a separate commit for easy rollback
