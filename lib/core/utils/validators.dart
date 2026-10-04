/// Validator utilities for forms.
class Validators {
  Validators._();

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email cannot be empty';
    }
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password cannot be empty';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number cannot be empty';
    }
    // simple indonesian phone format check
    final regex = RegExp(r'^(08|\+62)\d{8,11}$');
    if (!regex.hasMatch(value.replaceAll(' ', '').replaceAll('-', ''))) {
      return 'Enter a valid Indonesian phone number';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateConfirmPassword(String? password, String? confirm) {
    if (confirm == null || confirm.isEmpty) {
      return 'Confirm password is required';
    }
    if (password != confirm) {
      return 'Passwords do not match';
    }
    return null;
  }
}
