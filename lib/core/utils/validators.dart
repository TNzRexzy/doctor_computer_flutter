/// Validator utilities for forms (Indonesian).
class Validators {
  Validators._();

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email tidak boleh kosong';
    }
    final trimmed = value.trim().toLowerCase();
    // Allow username login for admin and cashier
    if (trimmed == 'admin' || trimmed == 'cashier') {
      return null;
    }
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nomor telepon tidak boleh kosong';
    }
    // simple indonesian phone format check
    final regex = RegExp(r'^(08|\+62)\d{8,11}$');
    if (!regex.hasMatch(value.replaceAll(' ', '').replaceAll('-', ''))) {
      return 'Nomor telepon tidak valid (contoh: 08123456789)';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }

  static String? validateConfirmPassword(String? password, String? confirm) {
    if (confirm == null || confirm.isEmpty) {
      return 'Konfirmasi password tidak boleh kosong';
    }
    if (password != confirm) {
      return 'Password tidak cocok';
    }
    return null;
  }
}
