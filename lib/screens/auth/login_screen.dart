import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/validators.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/services/biometric_service.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';

/// Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberEmail = false;
  BiometricCredential? _biometricCredential;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _loadBiometricCredential();
  }

  /// Tombol sidik jari hanya muncul jika akun yang terakhir login di
  /// perangkat ini sudah mendaftarkan sidik jari.
  Future<void> _loadBiometricCredential() async {
    final credential = await BiometricService.instance.lastUserCredential();
    if (!mounted) return;
    setState(() => _biometricCredential = credential);
  }

  void _loginWithFingerprint() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithBiometric();
    if (!mounted) return;
    if (success) {
      Navigator.pushReplacementNamed(context, AppRouter.mainNav);
    } else {
      final errorMsg = auth.errorMessage;
      if (errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
      // Kredensial bisa terhapus (password berubah / sidik jari dicabut).
      _loadBiometricCredential();
    }
  }

  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_login_email');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberEmail = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved email: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      final input = _emailController.text.trim();
      final auth = context.read<AuthProvider>();

      // Persist or clear remembered email
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberEmail) {
          await prefs.setString('saved_login_email', input);
        } else {
          await prefs.remove('saved_login_email');
        }
      } catch (e) {
        debugPrint('Error saving remembered email: $e');
      }

      String email = input;
      if (input.toLowerCase() == 'admin') {
        email = 'admin@doctorcomputer.id';
      } else if (input.toLowerCase() == 'cashier') {
        email = 'cashier@doctorcomputer.id';
      }

      final success = await auth.login(
        email,
        _passwordController.text,
      );
      if (!mounted) return;
      if (success) {
        if (auth.isOfflineSession) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Mode offline aktif. Perubahan data dinonaktifkan.',
              ),
            ),
          );
        } else if ((auth.currentUser?.role == UserRole.admin ||
                auth.currentUser?.role == UserRole.cashier) &&
            !auth.offlineCredentialSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Login online berhasil, tetapi kredensial offline tidak '
                'dapat disimpan di perangkat ini.',
              ),
            ),
          );
        }
        Navigator.pushReplacementNamed(context, AppRouter.mainNav);
      } else {
        final errorMsg = auth.errorMessage ?? 'Login gagal. Silakan periksa kredensial Anda.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Image.asset('assets/images/logo.png', height: 140),
              const SizedBox(height: 40),
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Masuk', style: AppTextStyles.heading3),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
                          hintText: 'Email atau Username',
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: Validators.validateEmail,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock, color: AppColors.textSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          hintText: 'Password',
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: Validators.validatePassword,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _rememberEmail,
                                  activeColor: AppColors.primary,
                                  checkColor: AppColors.buttonText,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _rememberEmail = val ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _rememberEmail = !_rememberEmail;
                                  });
                                },
                                child: Text(
                                  'Ingat email saya',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'Lupa Password?',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GradientButton(
                        label: 'Masuk',
                        onPressed: _login,
                        isLoading: isLoading,
                      ),
                    ],
                  ),
                ),
              ),
              if (_biometricCredential != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _loginWithFingerprint,
                  icon: Icon(Icons.fingerprint, size: 28, color: AppColors.primary),
                  label: Text('Masuk dengan Sidik Jari (${_biometricCredential!.email})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(double.infinity, 50),
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.surfaceLight)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('atau', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ),
                  Expanded(child: Divider(color: AppColors.surfaceLight)),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Login dengan Google akan segera hadir')),
                  );
                },
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Masuk dengan Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: AppColors.surfaceLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Login dengan Apple akan segera hadir')),
                  );
                },
                icon: const Icon(Icons.apple, size: 28),
                label: const Text('Masuk dengan Apple'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: AppColors.surfaceLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Belum punya akun? ', style: AppTextStyles.bodyMedium),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRouter.register);
                    },
                    child: Text('Daftar', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
