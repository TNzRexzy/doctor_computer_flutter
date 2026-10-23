import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/core/utils/validators.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
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

  void _loginWithBiometric() async {
    final auth = context.read<AuthProvider>();
    final enrolledName = await auth.getBiometricEnrolledUserName();

    if (!mounted) return;

    if (enrolledName == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.fingerprint, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Biometrik Belum Aktif'),
            ],
          ),
          content: const Text(
            'Belum ada akun yang mengaktifkan login biometrik di perangkat ini.\n\nSilakan masuk menggunakan email & password, lalu aktifkan Sidik Jari di menu Profil > Keamanan & Privasi.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mengerti', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    _showBiometricPrompt(enrolledName);
  }

  void _showBiometricPrompt(String userName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Autentikasi Sensor HP',
                style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Akun: $userName',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fingerprint, color: AppColors.primary, size: 28),
                ),
                title: const Text('Scan Sidik Jari (Sensor Fisik HP)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Memicu sensor biometrik perangkat Anda'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _authenticateWithRealFingerprint();
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt, color: AppColors.accent, size: 28),
                ),
                title: const Text('Face ID (Buka Kamera Depan)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Buka kamera depan untuk memindai wajah'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _authenticateWithRealFaceCamera();
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal & Gunakan Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _authenticateWithRealFingerprint() async {
    final auth = context.read<AuthProvider>();

    // Trigger phone physical hardware sensor prompt
    final bool didAuthenticate = await BiometricService.authenticateWithHardware(
      localizedReason: 'Pindai sidik jari Anda pada sensor HP untuk masuk ke Doctor Computer',
    );

    if (!mounted) return;

    if (didAuthenticate) {
      final success = await auth.loginWithBiometrics();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: const Text('Sidik jari terverifikasi sensor! Berhasil masuk.'),
          ),
        );
        Navigator.pushReplacementNamed(context, AppRouter.mainNav);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.errorMessage ?? 'Gagal memulihkan sesi biometrik')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verifikasi sensor sidik jari HP dibatalkan atau tidak cocok.'),
        ),
      );
    }
  }

  Future<void> _authenticateWithRealFaceCamera() async {
    final auth = context.read<AuthProvider>();

    // Open actual front camera via image_picker
    final photo = await BiometricService.captureFaceFromCamera();

    if (!mounted) return;

    if (photo != null) {
      final success = await auth.loginWithBiometrics();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: const Text('Wajah terverifikasi kamera! Berhasil masuk.'),
          ),
        );
        Navigator.pushReplacementNamed(context, AppRouter.mainNav);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.errorMessage ?? 'Gagal login Face ID')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pemindaian wajah dibatalkan.'),
        ),
      );
    }
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
                      Row(
                        children: [
                          Expanded(
                            child: GradientButton(
                              label: 'Masuk',
                              onPressed: _login,
                              isLoading: isLoading,
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: isLoading ? null : _loginWithBiometric,
                            child: Container(
                              height: 50,
                              width: 52,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.fingerprint,
                                color: AppColors.primary,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
