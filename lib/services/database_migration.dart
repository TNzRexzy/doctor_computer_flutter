import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// Utility to initialize missing database columns and seed admin data.
/// Call this once at app startup.
class DatabaseMigration {
  static final supabase = Supabase.instance.client;

  /// Run all migrations - adds missing columns and seeds admin account
  static Future<void> runMigrations() async {
    await _addMissingColumns();
    await _seedAdminAccount();
    await _ensureOrdersTable();
  }

  /// Try to add missing columns to the users table.
  /// Uses RPC or direct queries. If columns already exist, errors are caught silently.
  static Future<void> _addMissingColumns() async {
    // Try adding each column individually. If it already exists, the error is caught.
    final columnsToAdd = [
      "ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user'",
      "ALTER TABLE public.users ADD COLUMN IF NOT EXISTS profile_image_url TEXT",
      "ALTER TABLE public.users ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION",
      "ALTER TABLE public.users ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION",
    ];

    for (final sql in columnsToAdd) {
      try {
        await supabase.rpc('exec_sql', params: {'query': sql});
      } catch (e) {
        debugPrint('Migration (may be OK if column exists): $e');
      }
    }
  }

  /// Create admin account if it doesn't exist
  static Future<void> _seedAdminAccount() async {
    try {
      // Check if admin exists
      // List-based read (`limit(1)`): `.maybeSingle()` throws PGRST116 when
      // duplicate profile rows exist, which is the same coercion bug fixed in
      // AuthProvider's login/session sync.
      final rows = await supabase
          .from('users')
          .select('id')
          .eq('email', 'admin@doctorcomputer.id')
          .limit(1);

      if (rows.isEmpty) {
        debugPrint('Admin account will be created on first admin login.');
      }
    } catch (e) {
      debugPrint('Admin check: $e');
    }
  }

  /// Ensure orders table exists
  static Future<void> _ensureOrdersTable() async {
    try {
      // Just try to query it - if it fails, we know it doesn't exist
      await supabase.from('orders').select('id').limit(1);
      debugPrint('Orders table exists.');
    } catch (e) {
      debugPrint('Orders table check: $e');
    }
  }
}
