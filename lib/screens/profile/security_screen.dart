import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/services/biometric_service.dart';
import 'package:doctor_computer/widgets/common/custom_app_bar.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';

/// Menu Keamanan: daftarkan / hapus sidik jari untuk login.
/// Tersedia untuk semua peran (user, kasir, admin).
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _bio = BiometricService.instance;

  bool _isLoading = true;
  bool _isBusy = false;
  String? _loadError;
  BiometricStatus _status = BiometricStatus.notAvailable;
  List<Map<String, dynamic>> _registrations = [];
  BiometricCredential? _localCredential;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final status = await _bio.checkStatus();
    final local = await _bio.readCredential(user.id);
    List<Map<String, dynamic>> registrations = [];
    String? error;
    try {
      registrations = await _bio.fetchRegistrations(user.id);
    } on PostgrestException catch (e) {
      debugPrint('[Security] fetch registrations: ${e.code} ${e.message}');
      error = 'Gagal memuat data sidik jari dari database.';
    } catch (e) {
      debugPrint('[Security] fetch registrations: $e');
      error = 'Gagal memuat data sidik jari. Periksa koneksi Anda.';
    }

    // Kredensial lokal yang sudah dicabut dari database tidak berlaku lagi.
    if (error == null &&
        local != null &&
        !registrations.any((r) => r['biometric_token'] == local.token)) {
      await _bio.deleteCredential(user.id);
      if (!mounted) return;
      setState(() {
        _status = status;
        _registrations = registrations;
        _localCredential = null;
        _loadError = error;
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _status = status;
      _registrations = registrations;
      _localCredential = local;
      _loadError = error;
      _isLoading = false;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addFingerprint() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null || _isBusy) return;

    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (password == null || password.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      await _bio.registerFingerprint(
        userId: user.id,
        email: Supabase.instance.client.auth.currentUser?.email ?? user.email,
        password: password,
      );
      _showMessage(
        'Sidik jari berhasil didaftarkan. Setelah keluar, Anda bisa masuk '
        'dengan sidik jari.',
      );
    } on BiometricException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      debugPrint('[Security] register error: $e');
      _showMessage('Terjadi kesalahan saat mendaftarkan sidik jari.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
    await _refresh();
  }

  Future<void> _removeFingerprint(Map<String, dynamic> row) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || _isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Sidik Jari'),
        content: const Text(
          'Perangkat ini tidak akan bisa lagi login dengan sidik jari ini. '
          'Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      await _bio.removeRegistration(
        userId: user.id,
        rowId: row['id'].toString(),
        token: row['biometric_token']?.toString() ?? '',
      );
      _showMessage('Sidik jari dihapus.');
    } on BiometricException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
    await _refresh();
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    final hasLocal = _localCredential != null;
    final canAdd = _status == BiometricStatus.ready && !hasLocal;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Keamanan', transparent: false),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GlassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.fingerprint,
                            size: 40,
                            color: hasLocal ? AppColors.success : AppColors.primary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Login dengan Sidik Jari', style: AppTextStyles.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  hasLocal
                                      ? 'Aktif di perangkat ini. Setelah keluar, '
                                          'Anda bisa masuk dengan sidik jari.'
                                      : _bio.statusMessage(_status),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (canAdd)
                      GradientButton(
                        label: 'Tambah Sidik Jari',
                        icon: Icons.add,
                        isLoading: _isBusy,
                        onPressed: _addFingerprint,
                      ),
                    if (_status == BiometricStatus.ready && hasLocal)
                      Text(
                        'Sidik jari perangkat ini sudah terdaftar untuk akun ini.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                        textAlign: TextAlign.center,
                      ),
                    if (_loadError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _loadError!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text('Perangkat Terdaftar', style: AppTextStyles.titleSmall),
                    const SizedBox(height: 8),
                    if (_registrations.isEmpty)
                      Text(
                        'Belum ada sidik jari terdaftar.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      ..._registrations.map((row) {
                        final isThisDevice =
                            row['biometric_token'] == _localCredential?.token;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.fingerprint, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isThisDevice
                                            ? '${row['credential_name'] ?? 'Sidik jari'} • Perangkat ini'
                                            : '${row['credential_name'] ?? 'Sidik jari'}',
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                      Text(
                                        'Didaftarkan ${_formatDate(row['created_at'])}'
                                        '${row['last_used_at'] != null ? '\nTerakhir dipakai ${_formatDate(row['last_used_at'])}' : ''}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Hapus',
                                  icon: Icon(Icons.delete_outline, color: AppColors.error),
                                  onPressed: _isBusy ? null : () => _removeFingerprint(row),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Konfirmasi Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Masukkan password akun Anda, lalu pindai sidik jari pada '
            'langkah berikutnya.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Lanjut'),
        ),
      ],
    );
  }
}
