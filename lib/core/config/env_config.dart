import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized environment configuration and credential management.
class EnvConfig {
  EnvConfig._();

  static const String _defaultSupabaseUrl = 'https://nvipwcrydrnogrbsnhud.supabase.co';
  static const String _defaultSupabaseAnonKey = 'sb_publishable_2yyCD_Biu4JmoMiZqPcWag_ASc0KRXl';
  static const String _defaultStorageUrl = 'https://nvipwcrydrnogrbsnhud.storage.supabase.co/storage/v1/s3';
  static const String _defaultStorageBucket = 'assets';
  static const String _prefGeminiKey = 'gemini_api_key_override';

  static String _inMemoryGeminiKey = '';

  /// Safe helper to read environment variables without throwing
  static String? _getEnv(String key) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.maybeGet(key);
      }
    } catch (_) {}
    return null;
  }

  /// Initialize dotenv from `.env` file
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: ".env");
      debugPrint('[EnvConfig] Successfully loaded .env');
    } catch (e) {
      debugPrint('[EnvConfig] Notice: .env file ($e), using built-in configuration.');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _inMemoryGeminiKey = prefs.getString(_prefGeminiKey) ?? _getEnv('GEMINI_API_KEY') ?? '';
    } catch (e) {
      _inMemoryGeminiKey = _getEnv('GEMINI_API_KEY') ?? '';
    }
  }

  /// Supabase project URL
  static String get supabaseUrl {
    final url = _getEnv('SUPABASE_URL');
    return (url != null && url.isNotEmpty) ? url : _defaultSupabaseUrl;
  }

  /// Supabase public anonymous key
  static String get supabaseAnonKey {
    final key = _getEnv('SUPABASE_ANON_KEY');
    return (key != null && key.isNotEmpty) ? key : _defaultSupabaseAnonKey;
  }

  /// Supabase dedicated storage endpoint
  static String get storageUrl {
    final sUrl = _getEnv('SUPABASE_STORAGE_URL');
    return (sUrl != null && sUrl.isNotEmpty) ? sUrl : _defaultStorageUrl;
  }

  /// Supabase public storage bucket
  static String get storageBucket {
    final b = _getEnv('SUPABASE_STORAGE_BUCKET');
    return (b != null && b.isNotEmpty) ? b : _defaultStorageBucket;
  }

  /// Google Gemini API Key
  static String get geminiApiKey {
    if (_inMemoryGeminiKey.isNotEmpty) return _inMemoryGeminiKey;
    return _getEnv('GEMINI_API_KEY') ?? '';
  }

  /// Set Gemini API Key dynamically and persist to SharedPreferences
  static Future<void> setGeminiApiKey(String key) async {
    _inMemoryGeminiKey = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefGeminiKey, _inMemoryGeminiKey);
    } catch (e) {
      debugPrint('[EnvConfig] Failed to persist gemini key: $e');
    }
  }
}
