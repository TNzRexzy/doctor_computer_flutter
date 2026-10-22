import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// Utility to initialize missing database columns and verify database tables.
/// Call this once at app startup.
class DatabaseMigration {
  static final supabase = Supabase.instance.client;

  /// Run all migrations - verifies tables and columns
  static Future<void> runMigrations() async {
    await _addMissingColumns();
    await _verifyTables();
  }

  /// Try to add missing columns to the users and other tables if needed.
  /// Uses RPC or direct queries. If columns already exist, errors are caught silently.
  static Future<void> _addMissingColumns() async {
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
        // Silently continue - columns already present or exec_sql not enabled
      }
    }
  }

  /// Verifies connectivity to the core database tables
  static Future<void> _verifyTables() async {
    final tables = [
      'categories',
      'products',
      'users',
      'pc_parts',
      'pc_builds',
      'orders',
      'order_items',
      'cart_items',
      'wishlist',
      'reviews',
      'brands',
      'product_subtypes',
      'membership_tiers',
    ];

    for (final table in tables) {
      try {
        await supabase.from(table).select().limit(1);
        debugPrint('DB Table check: $table is OK');
      } catch (e) {
        debugPrint('DB Table check notice for $table: $e');
      }
    }
  }
}
