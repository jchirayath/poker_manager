import 'dart:math';
import '../../../games/data/models/game_participant_model.dart';

/// Service for generating and managing seating charts for poker games
class SeatingChartService {
  /// Generates a random seating chart for the given participants
  /// Returns a Map with userId as key and seat number as value
  static Map<String, dynamic> generateSeatingChart(
    List<GameParticipantModel> participants,
  ) {
    if (participants.isEmpty) {
      return {};
    }

    // Filter to only include participants who are going
    final goingParticipants = participants
        .where((p) => p.rsvpStatus == 'going')
        .toList();

    if (goingParticipants.isEmpty) {
      return {};
    }

    // Create a shuffled list of seat numbers
    final random = Random();
    final seatNumbers = List.generate(goingParticipants.length, (i) => i + 1);
    seatNumbers.shuffle(random);

    // Create the seating chart map
    final seatingChart = <String, dynamic>{};
    for (var i = 0; i < goingParticipants.length; i++) {
      seatingChart[goingParticipants[i].userId] = seatNumbers[i];
    }

    return seatingChart;
  }

  /// Gets the seat number for a specific user from the seating chart
  static int? getSeatNumber(Map<String, dynamic>? seatingChart, String userId) {
    if (seatingChart == null) return null;
    final seatValue = seatingChart[userId];
    if (seatValue is int) return seatValue;
    if (seatValue is double) return seatValue.toInt();
    return null;
  }

  /// Gets a sorted list of participants by their seat numbers
  static List<MapEntry<String, int>> getSortedSeatingChart(
    Map<String, dynamic>? seatingChart,
  ) {
    if (seatingChart == null || seatingChart.isEmpty) {
      return [];
    }

    final entries = <MapEntry<String, int>>[];
    for (var entry in seatingChart.entries) {
      final seatNumber = entry.value is int
          ? entry.value as int
          : (entry.value as double).toInt();
      entries.add(MapEntry(entry.key, seatNumber));
    }

    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  /// Validates that a seating chart is properly formatted
  static bool isValidSeatingChart(Map<String, dynamic>? seatingChart) {
    if (seatingChart == null || seatingChart.isEmpty) {
      return false;
    }

    // Check that all values are valid integers
    for (var value in seatingChart.values) {
      if (value is! int && value is! double) {
        return false;
      }
    }

    // Check that seat numbers are sequential starting from 1
    final seatNumbers = seatingChart.values
        .map((v) => v is int ? v : (v as double).toInt())
        .toList()
      ..sort();

    for (var i = 0; i < seatNumbers.length; i++) {
      if (seatNumbers[i] != i + 1) {
        return false;
      }
    }

    return true;
  }
}
