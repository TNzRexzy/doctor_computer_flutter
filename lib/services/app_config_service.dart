import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads runtime configuration (e.g. the Gemini API key) from the Supabase
/// table `public.app_config` instead of hardcoding it in the app.
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  static const String geminiApiKeyName = 'GEMINI_API_KEY';

  /// How long a fetched value is reused before asking Supabase again.
  static const Duration _ttl = Duration(minutes: 30);

  /// Short retry delay after an empty/failed lookup (e.g. user not logged in yet).
  static const Duration _retryAfter = Duration(seconds: 30);

  final Map<String, String> _cache = {};
  final Map<String, DateTime> _expiresAt = {};

  /// Returns the config value for [key], or an empty string when it is not
  /// available (not logged in, row missing, network error).
  Future<String> get(String key, {bool forceRefresh = false}) async {
    final now = DateTime.now();
    final expires = _expiresAt[key];
    if (!forceRefresh && expires != null && expires.isAfter(now)) {
      return _cache[key] ?? '';
    }

    try {
      final rows = await Supabase.instance.client
          .from('app_config')
          .select('value')
          .eq('key', key)
          .limit(1);
      final value = rows.isEmpty
          ? ''
          : (rows.first['value']?.toString() ?? '').trim();
      _cache[key] = value;
      _expiresAt[key] = now.add(value.isEmpty ? _retryAfter : _ttl);
      return value;
    } catch (e) {
      debugPrint('AppConfigService: failed to load "$key": $e');
      _expiresAt[key] = now.add(_retryAfter);
      return _cache[key] ?? '';
    }
  }

  /// Gemini API key stored in Supabase (`app_config.GEMINI_API_KEY`).
  Future<String> getGeminiApiKey({bool forceRefresh = false}) =>
      get(geminiApiKeyName, forceRefresh: forceRefresh);

  /// Clears cached values (call on logout so the next user re-reads them).
  void clear() {
    _cache.clear();
    _expiresAt.clear();
  }
}
