/// Centralized input validation utilities
/// Provides consistent validation logic across the application
library;

class InputValidators {
  InputValidators._();

  // ==================== EMAIL VALIDATION ====================
  
  /// RFC 5322 compliant email regex pattern
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
  );

  /// Validates email format
  /// Returns error message if invalid, null if valid
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    
    final email = value.trim();
    
    if (!_emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    if (email.length > 254) {
      return 'Email is too long';
    }
    
    return null;
  }

  // ==================== PHONE NUMBER VALIDATION ====================
  
  /// International phone number regex (relaxed for multiple formats)
  /// Accepts: +1234567890, (123) 456-7890, 123-456-7890, 123.456.7890, etc.
  static final RegExp _phoneRegex = RegExp(
    r'^[\+]?[(]?[0-9]{1,3}[)]?[-\s\.]?[(]?[0-9]{1,4}[)]?[-\s\.]?[0-9]{1,4}[-\s\.]?[0-9]{1,9}$',
  );

  /// Validates phone number format
  /// Returns error message if invalid, null if valid
  /// Allows optional field (returns null if empty)
  static String? validatePhoneNumber(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Phone number is required' : null;
    }
    
    final phone = value.trim();
    
    // Remove common formatting characters for length check
    final digitsOnly = phone.replaceAll(RegExp(r'[\s\-\.\(\)\+]'), '');
    
    if (digitsOnly.length < 7) {
      return 'Phone number is too short';
    }
    
    if (digitsOnly.length > 15) {
      return 'Phone number is too long';
    }
    
    if (!_phoneRegex.hasMatch(phone)) {
      return 'Please enter a valid phone number';
    }
    
    return null;
  }

  // ==================== PASSWORD VALIDATION ====================
  
  /// Validates password strength
  /// Returns error message if invalid, null if valid
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (value.length > 128) {
      return 'Password is too long';
    }
    
    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    
    // Check for at least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    
    // Check for at least one number
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    
    return null;
  }

  /// Validates password confirmation matches original
  static String? validatePasswordConfirmation(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != originalPassword) {
      return 'Passwords do not match';
    }
    
    return null;
  }

  // ==================== NAME VALIDATION ====================
  
  /// Validates name fields (first name, last name, username)
  static String? validateName(String? value, {required String fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $fieldName';
    }
    
    final name = value.trim();
    
    if (name.length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    
    if (name.length > 50) {
      return '$fieldName is too long';
    }
    
    // Allow letters, spaces, hyphens, and apostrophes
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(name)) {
      return '$fieldName contains invalid characters';
    }
    
    return null;
  }

  // ==================== USERNAME VALIDATION ====================
  
  /// Validates username (alphanumeric, underscores, dots, hyphens)
  static String? validateUsername(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Username is required' : null;
    }
    
    final username = value.trim();
    
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    
    if (username.length > 30) {
      return 'Username is too long';
    }
    
    // Allow alphanumeric, underscores, dots, and hyphens
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, dots, underscores, and hyphens';
    }
    
    // Cannot start or end with special characters
    if (RegExp(r'^[._-]|[._-]$').hasMatch(username)) {
      return 'Username cannot start or end with special characters';
    }
    
    return null;
  }

  // ==================== NUMERIC VALIDATION ====================
  
  /// Validates numeric amount (for buy-ins, cash-outs, etc.)
  static String? validateAmount(String? value, {
    required String fieldName,
    double? min,
    double? max,
    bool required = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Please enter $fieldName' : null;
    }
    
    final amount = double.tryParse(value.trim());
    
    if (amount == null) {
      return 'Please enter a valid number';
    }
    
    if (min != null && amount < min) {
      return '$fieldName must be at least \$${min.toStringAsFixed(2)}';
    }
    
    if (max != null && amount > max) {
      return '$fieldName cannot exceed \$${max.toStringAsFixed(2)}';
    }
    
    // Check for reasonable decimal places (max 2 for currency)
    if (amount.toStringAsFixed(2) != amount.toString() && 
        value.contains('.') && 
        value.split('.')[1].length > 2) {
      return '$fieldName can have at most 2 decimal places';
    }
    
    return null;
  }

  // ==================== TEXT SANITIZATION ====================
  
  /// Sanitizes input to prevent XSS attacks
  /// Removes potentially dangerous characters
  static String sanitizeInput(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse multiple spaces
        .replaceAll('<', '&lt;') // Escape HTML
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  // ==================== GENERAL VALIDATORS ====================
  
  /// Validates required field
  static String? validateRequired(String? value, {required String fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates max length
  static String? validateMaxLength(String? value, {
    required int maxLength,
    required String fieldName,
  }) {
    if (value != null && value.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters';
    }
    return null;
  }

  /// Validates min length
  static String? validateMinLength(String? value, {
    required int minLength,
    required String fieldName,
  }) {
    if (value != null && value.isNotEmpty && value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    return null;
  }

  // ==================== POSTAL CODE VALIDATION ====================
  
  /// Validates postal/zip code (relaxed international format)
  static String? validatePostalCode(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Postal code is required' : null;
    }
    
    final code = value.trim();
    
    // Allow alphanumeric, spaces, and hyphens
    if (!RegExp(r'^[a-zA-Z0-9\s\-]+$').hasMatch(code)) {
      return 'Invalid postal code format';
    }
    
    if (code.length > 10) {
      return 'Postal code is too long';
    }
    
    return null;
  }
}
