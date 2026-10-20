import os

path = 'D:/SMS 5/Mobile/Project/doctor_computer_flutter_fix/lib/providers/auth_provider.dart'

# Read current file
with open(path, 'r') as f:
    content = f.read()

# Write new content
new_content = '''import 'package:flutter/material.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  final supabase = Supabase.instance.client;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Login via Supabase Auth
      final authRes = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authRes.error != null) {
        debugPrint('Login error: ${authRes.error}');
        return false;
      }

      // Fetch user profile from users table
      final userRes = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .single();

      if ((userRes as dynamic).error != null) {
        debugPrint('User fetch error: ${(userRes as dynamic)?.error}');
        return false;
      }

      final data = (userRes as dynamic).data as Map<String, dynamic>;

      _currentUser = UserModel(
        id: data['id'] as String,
        fullName: data['full_name'] as String,
        email: data['email'] as String,
        phone: (data['phone'] as String? ?? '').toString(),
        address: (data['address'] as String? ?? '').toString(),
        city: (data['city'] as String? ?? '').toString(),
        membershipTier: _parseMembershipTier(data['membership_tier']),
        points: (data['points'] as num? ?? 0).toInt(),
        joinDate: _parseDateTime(data['join_date']),
      );

      _isLoggedIn = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login exception: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String name, String email, String phone, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Register via Supabase Auth
      final authRes = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authRes.error != null) {
        debugPrint('Auth register error: ${authRes.error}');
        return false;
      }

      // Get the user ID from auth response
      final userId = authRes.data?['user']?['id'];
      if (userId == null) {
        debugPrint('No user ID in auth response');
        return false;
      }

      // 2. Insert user profile into users table
      final profileRes = await supabase
          .from('users')
          .insert({
            'id': userId,
            'full_name': name,
            'email': email,
            'phone': phone,
            'address': '',
            'city': '',
            'membership_tier': 'bronze',
            'points': 0,
            'join_date': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      if ((profileRes as dynamic).error != null) {
        debugPrint('Profile insert error: ${(profileRes as dynamic)?.error}');
        // Don't fail completely - user is registered but profile insert may have failed
      }

      // 3. Fetch profile
      final fetchRes = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      if ((fetchRes as dynamic).error != null) {
        debugPrint('Profile fetch error: ${(fetchRes as dynamic)?.error}');
        return false;
      }

      final data = (fetchRes as dynamic).data as Map<String, dynamic>;

      _currentUser = UserModel(
        id: data['id'] as String,
        fullName: data['full_name'] as String,
        email: data['email'] as String,
        phone: (data['phone'] as String? ?? '').toString(),
        address: (data['address'] as String? ?? '').toString(),
        city: (data['city'] as String? ?? '').toString(),
        membershipTier: _parseMembershipTier(data['membership_tier']),
        points: (data['points'] as num? ?? 0).toInt(),
        joinDate: _parseDateTime(data['join_date']),
      );

      _isLoggedIn = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Register exception: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ... (keep the existing helper methods)
'''

with open(path, 'w') as f:
    f.write(new_content)
print(f'Updated: {path}')
