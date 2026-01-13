import 'dart:convert';
import 'package:flutter/services.dart';

class AppConstants {
  static late String supabaseUrl;
  static late String supabaseAnonKey;

  static Future<void> loadEnv() async {
    try {
      final jsonString = await rootBundle.loadString('env.json');
      final Map<String, dynamic> env = json.decode(jsonString);
      supabaseUrl = env['SUPABASE_URL'] ?? '';
      supabaseAnonKey = env['SUPABASE_ANON_KEY'] ?? '';
    } catch (e) {
      throw Exception('Failed to load environment variables: $e');
    }
  }

  // Currency options
  static const List<String> currencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY', 'CHF'];

  // Default buy-in values
  static const List<double> defaultBuyinValues = [
    25.00, 50.00, 100.00, 200.00, 500.00, 1000.00
  ];

  // Countries list
  static const List<String> countries = [
    'United States',
    'Canada',
    'United Kingdom',
    'Australia',
    'Germany',
    'France',
    'Spain',
    'Italy',
    'Netherlands',
    'Switzerland',
    'Japan',
    'China',
    'India',
    'Brazil',
    'Mexico',
    'Argentina',
    // Add more as needed
  ];

  // Validation
  static const int maxGroupNameLength = 50;
  static const int maxLocationLength = 200;
  static const double minBuyin = 1.0;
  static const double maxBuyin = 100000.0;
  static const double settlementTolerance = 0.01; // 1 cent tolerance

  // App Developer/Company Info
  static const String appName = 'Poker Manager';
  static const String appNameWithBeta = 'Poker Manager Beta';
  static const String companyName = 'Poker Manager Team';
  static const String developerEmail = 'support@pokermanager.app';
  static const String copyright = '© 2026 Poker Manager Team';
  static const String appTagline = 'Your Game, Your Way';
  static const String websiteUrl = 'https://pokermanager.app';

  // Feedback categories
  static const List<String> feedbackCategories = [
    'Feature Request',
    'Bug Report',
    'General Feedback',
  ];
}
