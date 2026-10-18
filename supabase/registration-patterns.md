---
# Supabase Registration & Auth Patterns

Patterns for user registration, login, and session management with Supabase Flutter SDK v2.

## Registration Flow with Success Feedback

### Pattern: Signup → Success Popup → Welcome Page → Main App

When registering a user with Supabase Auth, follow this flow for better UX:

```dart
// In auth_provider.dart
Future<bool> register(String name, String email, String phone, String password) async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    // 1. Register via Supabase Auth
    final authRes = await supabase.auth.signUp(
      email: email,
      password: password,
    );

    // SDK v2: Cast to dynamic for .error access
    final authError = (authRes as dynamic)?.error;
    if (authError != null) {
      _errorMessage = authError.message;
      return false;
    }

    final userId = authRes.user?.id;
    if (userId == null) {
      _errorMessage = 'Registrasi gagal: Tidak ada user ID';
      return false;
    }

    // 2. Insert user profile to users table
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

    // 3. Fetch and set user
    final data = ((profileRes as dynamic)?.data) as Map<String, dynamic>;
    _currentUser = _mapToUserModel(data);
    _isLoggedIn = true;
    return true;

  } on AuthException catch (e) {
    _errorMessage = e.message;
    return false;
  } on PostgrestException catch (e) {
    _errorMessage = e.message;
    return false;
  } catch (e) {
    _errorMessage = e.toString();
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

### RegisterScreen with Success Feedback

```dart
void _register() async {
  if (_formKey.currentState?.validate() ?? false) {
    final success = await context.read<AuthProvider>().register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
      _passwordController.text,
    );
    
    if (!mounted) return;
    final errorMessage = context.read<AuthProvider>().errorMessage;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Registrasi berhasil!')),
      );
      // Redirect to Welcome Page
      Navigator.pushReplacementNamed(context, AppRouter.welcome);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage ?? 'Registration failed.')),
      );
    }
  }
}
```

### WelcomeScreen After Registration

```dart
class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final name = user?.fullName ?? 'Pengguna';
    final email = user?.email ?? 'Pengguna';

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, size: 120, color: primaryColor),
            Text('Selamat datang, $name!'),
            Text('Email: $email'),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, AppRouter.mainNav),
              child: Text('Mulai Pakai Aplikasi'),
            ),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, AppRouter.login),
              child: Text('Sudah punya akun? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## SDK v2 Response Handling

### Critical Rule: Cast to Dynamic First

Supabase SDK v2 returns typed responses (`AuthResponse`, `PostgrestResponse`) that don't expose `.error` or `.data` directly in Dart's type system.

**Always use this pattern:**

```dart
// CORRECT
final error = (res as dynamic)?.error;
final data = (res as dynamic)?.data;

// WRONG - causes NoSuchMethodError
final error = res.error;  // NoSuchMethodError: Class 'AuthResponse' has no instance getter 'error'
final data = res.data;
```

### Common Error Pattern

```
NoSuchMethodError: Class 'AuthResponse' has no instance getter 'error'.
Receiver: Instance of 'AuthResponse'
Tried calling: error
```

**Cause**: Using `response.error` instead of `(response as dynamic).error`

## Login Pattern

```dart
Future<bool> login(String email, String password) async {
  try {
    final authRes = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Check error via dynamic cast
    final authError = (authRes as dynamic)?.error;
    if (authError != null) {
      _errorMessage = authError.message;
      debugPrint('Login error: ${authError.message} (code: ${authError.code})');
      return false;
    }

    final userId = authRes.user?.id;
    if (userId == null) {
      _errorMessage = 'Login failed: No user ID returned';
      return false;
    }

    // Fetch user profile
    final profileRes = await supabase
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    final data = ((profileRes as dynamic)?.data) as Map<String, dynamic>;
    _currentUser = _mapToUserModel(data);
    _isLoggedIn = true;
    return true;

  } on AuthException catch (e) {
    _errorMessage = e.message;
    return false;
  }
}
```

## Error Debugging

Always log error details for debugging:

```dart
final error = (res as dynamic)?.error;
if (error != null) {
  debugPrint('Error type: ${error.code}');
  debugPrint('Error message: ${error.message}');
  _errorMessage = error.message;
}
```

## URL Format

Supabase URL must be:
```
https://project-ref.supabase.co
```

**NOT**:
```
https://project-ref.supabase.co/rest/v1/
```