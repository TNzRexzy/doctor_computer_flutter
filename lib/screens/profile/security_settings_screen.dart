import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/providers/security_provider.dart';
import 'package:doctor_computer/providers/auth_provider.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final secProvider = context.watch<SecurityProvider>();
    final authProvider = context.watch<AuthProvider>();
    final settings = secProvider.settings;
    final biometrics = secProvider.biometrics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keamanan & Privasi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: secProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _buildPaymentSecurityBanner(context, secProvider),
                const SizedBox(height: 20),

                // SECTION 1: BIOMETRIC
                _buildSectionTitle('Autentikasi Biometrik Fisik'),
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Icon(Icons.fingerprint, color: AppColors.primary),
                        title: Text('Login dengan Biometrik', style: AppTextStyles.bodyMedium),
                        subtitle: Text(
                          'Masuk ke akun menggunakan sensor sidik jari perangkat',
                          style: AppTextStyles.caption,
                        ),
                        value: settings.biometricEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (val) async {
                          if (val && biometrics.isEmpty) {
                            // If no biometrics registered yet, guide to register first
                            _showAddBiometricSheet(context, secProvider, authProvider);
                          } else if (val) {
                            // Sudah punya sidik jari terdaftar: aktifkan lagi di perangkat ini
                            // (wajib verifikasi password + scan sensor)
                            await _enableBiometricWithPassword(context, secProvider, authProvider);
                          } else {
                            await secProvider.setBiometricEnabled(false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Biometrik dinonaktifkan'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: Icon(Icons.verified_user_outlined, color: AppColors.primary),
                        title: Text('Biometrik untuk Pembayaran', style: AppTextStyles.bodyMedium),
                        subtitle: Text(
                          'Verifikasi sensor biometrik sebelum konfirmasi checkout & bayar',
                          style: AppTextStyles.caption,
                        ),
                        value: settings.biometricForPayment && settings.biometricEnabled,
                        activeColor: AppColors.primary,
                        onChanged: settings.biometricEnabled
                            ? (val) async {
                                await secProvider.setBiometricForPayment(val);
                              }
                            : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.add_circle_outline, color: AppColors.primary),
                        title: Text('Daftarkan Sensor Biometrik Baru', style: AppTextStyles.bodyMedium),
                        subtitle: Text('Scan sidik jari pada sensor fisik perangkat', style: AppTextStyles.caption),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showAddBiometricSheet(context, secProvider, authProvider),
                      ),
                      if (biometrics.isNotEmpty) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sensor Terdaftar di Akun & Database (${biometrics.length}):',
                                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...biometrics.map((bio) {
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.fingerprint,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(bio.credentialName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                                            Text(
                                              bio.deviceModel ?? 'Sensor Sidik Jari',
                                              style: AppTextStyles.caption.copyWith(fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                        onPressed: () async {
                                          await secProvider.deleteBiometricCredential(bio.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('${bio.credentialName} telah dihapus')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // SECTION 2: PIN
                _buildSectionTitle('PIN Keamanan'),
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Icon(Icons.pin, color: AppColors.primary),
                        title: Text('Gunakan PIN Keamanan', style: AppTextStyles.bodyMedium),
                        subtitle: Text(
                          settings.pinEnabled
                              ? 'PIN 6 digit aktif'
                              : 'Amankan transaksi dan akun dengan PIN 6 digit',
                          style: AppTextStyles.caption,
                        ),
                        value: settings.pinEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          if (val) {
                            _showPinSetupDialog(context, secProvider);
                          } else {
                            _showDisablePinDialog(context, secProvider);
                          }
                        },
                      ),
                      if (settings.pinEnabled) ...[
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: Icon(Icons.payment, color: AppColors.primary),
                          title: Text('PIN untuk Pembayaran', style: AppTextStyles.bodyMedium),
                          subtitle: Text(
                            'Meminta PIN setiap transaksi/checkout',
                            style: AppTextStyles.caption,
                          ),
                          value: settings.pinForPayment,
                          activeColor: AppColors.primary,
                          onChanged: (val) async {
                            await secProvider.setPinForPayment(val);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.password, color: AppColors.primary),
                          title: Text('Ubah PIN', style: AppTextStyles.bodyMedium),
                          subtitle: Text('Ganti kombinasi 6 digit PIN Anda', style: AppTextStyles.caption),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showPinSetupDialog(context, secProvider, isChange: true),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // SECTION 3: PRIVACY & 2FA
                _buildSectionTitle('Keamanan Tambahan & Privasi'),
                const SizedBox(height: 8),
                GlassCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Icon(Icons.security, color: AppColors.primary),
                        title: Text('Autentikasi 2 Langkah (2FA)', style: AppTextStyles.bodyMedium),
                        subtitle: Text(
                          'Verifikasi kode OTP saat login dari perangkat baru',
                          style: AppTextStyles.caption,
                        ),
                        value: settings.twoFactorEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (val) async {
                          await secProvider.setTwoFactorEnabled(val);
                        },
                      ),
                      if (settings.twoFactorEnabled) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.phonelink_lock, color: AppColors.primary),
                          title: Text('Metode 2FA', style: AppTextStyles.bodyMedium),
                          trailing: DropdownButton<String>(
                            value: settings.twoFactorMethod ?? 'email',
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'email', child: Text('Email OTP')),
                              DropdownMenuItem(value: 'sms', child: Text('SMS / WhatsApp')),
                            ],
                            onChanged: (val) {
                              if (val != null) secProvider.setTwoFactorMethod(val);
                            },
                          ),
                        ),
                      ],
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.lock_clock, color: AppColors.primary),
                        title: Text('Kunci Otomatis (Auto-Lock)', style: AppTextStyles.bodyMedium),
                        trailing: DropdownButton<int>(
                          value: settings.autoLockMinutes,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Nonaktif')),
                            DropdownMenuItem(value: 1, child: Text('1 Menit')),
                            DropdownMenuItem(value: 5, child: Text('5 Menit')),
                            DropdownMenuItem(value: 15, child: Text('15 Menit')),
                            DropdownMenuItem(value: 30, child: Text('30 Menit')),
                          ],
                          onChanged: (val) {
                            if (val != null) secProvider.setAutoLockMinutes(val);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                        title: Text('Notifikasi Login', style: AppTextStyles.bodyMedium),
                        subtitle: Text(
                          'Dapatkan pemberitahuan jika ada aktivitas login mencurigakan',
                          style: AppTextStyles.caption,
                        ),
                        value: settings.loginNotification,
                        activeColor: AppColors.primary,
                        onChanged: (val) async {
                          await secProvider.setLoginNotification(val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPaymentSecurityBanner(BuildContext context, SecurityProvider provider) {
    final hasAuth = provider.requiresAuthForPayment;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasAuth
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAuth
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasAuth ? Icons.shield : Icons.gpp_maybe,
            color: hasAuth ? AppColors.success : AppColors.warning,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAuth ? 'Keamanan Pembayaran Aktif' : 'Pembayaran Belum Terlindungi',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hasAuth ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAuth
                      ? 'Transaksi dilindungi oleh verifikasi ${provider.settings.biometricForPayment ? "Biometrik" : ""}${provider.settings.biometricForPayment && provider.settings.pinForPayment ? " & " : ""}${provider.settings.pinForPayment ? "PIN" : ""}.'
                      : 'Aktifkan Biometrik atau PIN untuk mengamankan transaksi checkout Anda.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBiometricSheet(
    BuildContext context,
    SecurityProvider secProvider,
    AuthProvider authProvider,
  ) {
    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu untuk mendaftarkan biometrik')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daftarkan Sidik Jari',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Sambungkan ke sensor sidik jari fisik HP Anda:',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fingerprint, color: AppColors.primary),
                ),
                title: const Text('Sensor Sidik Jari HP (Fingerprint)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Membuka dialog sensor fisik HP untuk scan jari Anda'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  Navigator.pop(ctx);
                  _startRealFingerprintEnrollment(context, secProvider, authProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startRealFingerprintEnrollment(
    BuildContext context,
    SecurityProvider secProvider,
    AuthProvider authProvider,
  ) async {
    final nameController = TextEditingController(
      text: 'Sidik Jari ${secProvider.biometrics.length + 1}',
    );
    final passwordController = TextEditingController();

    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.fingerprint, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Scan Sensor HP'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aplikasi akan memicu sensor sidik jari perangkat HP Anda. Pastikan jari Anda ditempelkan ke sensor fisik saat dialog muncul.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Label Sidik Jari',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password akun Anda',
                  helperText: 'Diperlukan untuk memverifikasi bahwa ini akun Anda',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('Buka Sensor HP', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (proceed != true || !context.mounted) return;

    final user = authProvider.currentUser;
    if (user == null) return;

    final password = passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password wajib diisi untuk mendaftarkan sidik jari')),
      );
      return;
    }

    // Verifikasi password akun SEBELUM memicu sensor
    final verified = await authProvider.verifyCurrentPassword(password);
    if (!context.mounted) return;
    if (!verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password salah. Pendaftaran sidik jari dibatalkan.')),
      );
      return;
    }

    final success = await secProvider.enrollFingerprintHardware(
      user: user,
      credentialName: nameController.text.trim(),
      password: password,
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Sidik Jari "${nameController.text.trim()}" berhasil diverifikasi sensor HP dan disimpan ke database!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pemindaian sensor fisik sidik jari dibatalkan atau perangkat tidak mendukung sensor.'),
        ),
      );
    }
  }


  /// Dialog input password. Mengembalikan null jika dibatalkan.
  Future<String?> _askPassword(BuildContext context, {required String message}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Verifikasi Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password akun Anda',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(dlgCtx, controller.text),
            child: const Text('Lanjut', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Mengaktifkan kembali login biometrik untuk akun yang sudah punya
  /// sidik jari terdaftar: verifikasi password -> scan sensor -> simpan kredensial.
  Future<void> _enableBiometricWithPassword(
    BuildContext context,
    SecurityProvider secProvider,
    AuthProvider authProvider,
  ) async {
    final user = authProvider.currentUser;
    if (user == null) return;

    final password = await _askPassword(
      context,
      message: 'Masukkan password akun Anda untuk mengaktifkan login sidik jari di perangkat ini.',
    );
    if (password == null || password.isEmpty || !context.mounted) return;

    final verified = await authProvider.verifyCurrentPassword(password);
    if (!context.mounted) return;
    if (!verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password salah.')),
      );
      return;
    }

    final ok = await secProvider.enableBiometricLogin(user: user, password: password);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Biometrik diaktifkan' : 'Pemindaian sidik jari dibatalkan',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showPinSetupDialog(BuildContext context, SecurityProvider secProvider, {bool isChange = false}) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isChange ? 'Ubah PIN Keamanan' : 'Pasang PIN Baru'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Masukkan 6 digit angka rahasia untuk PIN Anda.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'PIN Baru (6 digit)',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Konfirmasi PIN Baru',
                      prefixIcon: Icon(Icons.check_circle_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();

                  if (pin.length != 6) {
                    setState(() => errorMessage = 'PIN harus tepat 6 digit');
                    return;
                  }
                  if (pin != confirm) {
                    setState(() => errorMessage = 'Konfirmasi PIN tidak cocok');
                    return;
                  }

                  final success = await secProvider.setPin(pin);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isChange ? 'PIN berhasil diperbarui' : 'PIN berhasil dibuat & diaktifkan'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Simpan PIN', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDisablePinDialog(BuildContext context, SecurityProvider secProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan PIN?'),
        content: const Text(
          'Menonaktifkan PIN akan menghapus proteksi PIN pada pembayaran dan login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await secProvider.removePin();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN keamanan dinonaktifkan')),
                );
              }
            },
            child: Text('Nonaktifkan', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
