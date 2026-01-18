import 'package:flutter/material.dart';

/// Centralized color definitions for consistent theming across the app.
///
/// This file provides semantic color constants for statuses, roles, payments,
/// and other UI elements. All widgets should use these colors instead of
/// hardcoding Material colors directly.
///
/// Color scheme is based on games_entry_screen.dart as the source of truth:
/// - scheduled = orange (future event, pending)
/// - in_progress = green (active, live)
/// - completed = blue (done, informational)
/// - cancelled = grey (inactive)
class AppColors {
  AppColors._();

  // ===========================================================================
  // GAME STATUS COLORS
  // ===========================================================================

  /// Color for scheduled games (future events)
  static const Color statusScheduled = Colors.orange;

  /// Color for in-progress games (active/live)
  static const Color statusInProgress = Colors.green;

  /// Color for completed games (finished)
  static const Color statusCompleted = Colors.blue;

  /// Color for cancelled games (inactive)
  static const Color statusCancelled = Colors.grey;

  /// Get status color by status string
  static Color getGameStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return statusScheduled;
      case 'in_progress':
        return statusInProgress;
      case 'completed':
        return statusCompleted;
      case 'cancelled':
        return statusCancelled;
      default:
        return statusScheduled;
    }
  }

  /// Get status icon by status string
  static IconData getGameStatusIcon(String status) {
    switch (status) {
      case 'scheduled':
        return Icons.schedule;
      case 'in_progress':
        return Icons.play_arrow;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  /// Get status display label by status string
  static String getGameStatusLabel(String status) {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  // ===========================================================================
  // RSVP STATUS COLORS
  // ===========================================================================

  /// Color for "going" RSVP status
  static const Color rsvpGoing = Colors.green;

  /// Color for "maybe" RSVP status
  static const Color rsvpMaybe = Colors.orange;

  /// Color for "not going" RSVP status
  static const Color rsvpNotGoing = Colors.red;

  /// Get RSVP color by status string
  static Color getRsvpStatusColor(String status) {
    switch (status) {
      case 'going':
        return rsvpGoing;
      case 'maybe':
        return rsvpMaybe;
      case 'not_going':
        return rsvpNotGoing;
      default:
        return rsvpMaybe;
    }
  }

  // ===========================================================================
  // GROUP ROLE COLORS
  // ===========================================================================

  /// Color for group creator role
  static const Color roleCreator = Colors.orange;

  /// Color for group admin role
  static const Color roleAdmin = Colors.blue;

  /// Color for regular group member role
  static const Color roleMember = Colors.grey;

  /// Color for local (non-registered) users
  static const Color userLocal = Colors.orange;

  /// Color for registered users
  static const Color userRegistered = Colors.green;

  /// Get role color by role string
  static Color getRoleColor(String role) {
    switch (role) {
      case 'creator':
        return roleCreator;
      case 'admin':
        return roleAdmin;
      case 'member':
        return roleMember;
      default:
        return roleMember;
    }
  }

  // ===========================================================================
  // SETTLEMENT COLORS
  // ===========================================================================

  /// Color for pending/unsettled payments
  static const Color settlementPending = Colors.orange;

  /// Color for completed/settled payments
  static const Color settlementCompleted = Colors.green;

  // ===========================================================================
  // PAYMENT METHOD COLORS (Brand Colors)
  // ===========================================================================

  /// Cash payment color
  static const Color paymentCash = Colors.green;

  /// Venmo brand color
  static const Color paymentVenmo = Color(0xFF3D95CE);

  /// PayPal brand color
  static const Color paymentPayPal = Color(0xFF003087);

  /// Zelle brand color
  static const Color paymentZelle = Color(0xFF6D1ED4);

  // ===========================================================================
  // SEMANTIC COLORS
  // ===========================================================================

  /// Success/positive color
  static const Color success = Colors.green;

  /// Warning/attention color
  static const Color warning = Colors.orange;

  /// Error/negative color
  static const Color error = Colors.red;

  /// Info/neutral color
  static const Color info = Colors.blue;

  // ===========================================================================
  // FINANCIAL COLORS
  // ===========================================================================

  /// Color for positive amounts (winnings, credits)
  static const Color positive = Colors.green;

  /// Color for negative amounts (losses, debits)
  static const Color negative = Colors.red;

  /// Color for neutral/zero amounts
  static const Color neutral = Colors.grey;

  // ===========================================================================
  // HELPER METHODS FOR ALPHA/OPACITY
  // ===========================================================================

  /// Returns color with 10% opacity (very light background)
  static Color withAlpha10(Color color) => color.withValues(alpha: 0.10);

  /// Returns color with 15% opacity (light background, standard for badges)
  static Color withAlpha15(Color color) => color.withValues(alpha: 0.15);

  /// Returns color with 20% opacity (medium background)
  static Color withAlpha20(Color color) => color.withValues(alpha: 0.20);

  /// Returns color with 30% opacity (darker background)
  static Color withAlpha30(Color color) => color.withValues(alpha: 0.30);
}
