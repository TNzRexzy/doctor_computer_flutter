import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/services/profile_photo_service.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/screens/map/location_picker_screen.dart';
import 'package:doctor_computer/widgets/common/app_toast.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = user.phone;
      _addressController.text = user.address;
      _cityController.text = user.city;
      _latitude = user.latitude;
      _longitude = user.longitude;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  /// Dialog ubah foto: pilih file JPG/PNG/GIF dari perangkat lalu unggah.
  void _showPhotoUploadDialog() {
    PickedProfilePhoto? picked;
    String? error;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final user = this.context.read<AuthProvider>().currentUser;
          final currentUrl = user?.profileImageUrl;
          ImageProvider? preview;
          if (picked != null) {
            preview = MemoryImage(picked!.bytes);
          } else if (currentUrl != null && currentUrl.isNotEmpty) {
            preview = NetworkImage(currentUrl);
          }

          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary15,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ubah Foto Profil',
                    style: AppTextStyles.titleLarge,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.accentGradient,
                    ),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.surfaceLight,
                      backgroundImage: preview,
                      child: preview == null
                          ? Icon(
                              Icons.person_rounded,
                              size: 48,
                              color: AppColors.textTertiary,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              try {
                                final result = await ProfilePhotoService.pick();
                                if (result != null) {
                                  setDialogState(() {
                                    picked = result;
                                    error = null;
                                  });
                                }
                              } on FormatException catch (e) {
                                setDialogState(() => error = e.message);
                              } catch (e) {
                                setDialogState(
                                  () => error = 'Gagal membuka galeri.',
                                );
                              }
                            },
                      icon: const Icon(Icons.upload_rounded, size: 20),
                      label: const Text('Pilih Foto dari Perangkat'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Format JPG, PNG, atau GIF. Maksimal 5 MB.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              error!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.buttonText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: (picked == null || saving)
                    ? null
                    : () async {
                        final auth = this.context.read<AuthProvider>();
                        final messenger = AppToast.of(context);
                        final nav = Navigator.of(ctx);
                        final userId =
                            Supabase.instance.client.auth.currentUser?.id ??
                            auth.currentUser?.id;
                        if (userId == null) {
                          setDialogState(
                            () => error = 'Sesi login tidak ditemukan.',
                          );
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final oldUrl = auth.currentUser?.profileImageUrl;
                          final url = await ProfilePhotoService.upload(
                            picked!,
                            userId,
                          );
                          final success = await auth.updateProfileImage(url);
                          if (!success) {
                            await ProfilePhotoService.deleteByUrl(url);
                            setDialogState(() {
                              saving = false;
                              error = 'Gagal menyimpan foto profil.';
                            });
                            return;
                          }
                          await ProfilePhotoService.deleteByUrl(oldUrl);
                          nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Foto profil diperbarui'),
                            ),
                          );
                          if (mounted) setState(() {});
                        } catch (e) {
                          debugPrint('Upload profile photo failed: $e');
                          setDialogState(() {
                            saving = false;
                            error = 'Unggah gagal. Periksa koneksi Anda lalu coba lagi.';
                          });
                        }
                      },
                child: saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.buttonText,
                        ),
                      )
                    : const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openMapPicker() async {
    final result = await Navigator.pushNamed(
      context,
      AppRouter.locationPicker,
      arguments: {
        'lat': _latitude,
        'lng': _longitude,
        'address': _addressController.text,
      },
    );

    if (result is LocationPickerResult) {
      setState(() {
        _addressController.text = result.address;
        _cityController.text = result.city;
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
      if (mounted) {
        AppToast.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Alamat peta berhasil diterapkan dan disimpan ke database!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final messenger = AppToast.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final success = await auth.updateProfile(
      _nameController.text.trim(),
      _phoneController.text.trim(),
      _addressController.text.trim(),
      _cityController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );
    if (mounted) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Profil & Alamat berhasil disimpan ke Database'
                : 'Gagal memperbarui profil',
          ),
        ),
      );
      if (success) nav.pop();
    }
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Widget _buildHeader(
    String initials,
    String name,
    String email,
    String? imageUrl,
  ) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final onGold = AppColors.buttonText;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 28),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: onGold,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Edit Profil',
                    style: AppTextStyles.heading3.copyWith(color: onGold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.surfaceLight,
                      backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
                      child: hasImage
                          ? null
                          : Text(
                              initials,
                              style: AppTextStyles.heading2.copyWith(
                                color: AppColors.primaryDark,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: _showPhotoUploadDialog,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.buttonText,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: AppTextStyles.titleLarge.copyWith(color: onGold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: AppTextStyles.bodySmall.copyWith(
                  color: onGold.withValues(alpha: 0.75),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary15,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppTextStyles.titleSmall)),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required IconData icon,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: AppTextStyles.bodyLarge.copyWith(
          color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.bodyMedium,
          floatingLabelStyle: AppTextStyles.label.copyWith(
            color: AppColors.primary,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: maxLines > 1 ? 48 : 0),
            child: Icon(
              icon,
              size: 20,
              color: readOnly ? AppColors.textTertiary : AppColors.primary,
            ),
          ),
          suffixIcon: readOnly
              ? Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildCoordinateChip() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.accent.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pin_drop_rounded,
              color: AppColors.buttonText,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koordinat Peta (Tersimpan di DB)',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openMapPicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_rounded, size: 15, color: AppColors.buttonText),
              const SizedBox(width: 6),
              Text(
                'Pilih via Map',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.buttonText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Scaffold();

    final initials = user.fullName.isNotEmpty
        ? user.fullName[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(
                    initials,
                    user.fullName,
                    user.email,
                    user.profileImageUrl,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 24 * (1 - value)),
                          child: child,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GlassCard(
                            padding: const EdgeInsets.all(18),
                            borderRadius: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSectionTitle(
                                  Icons.person_rounded,
                                  'Informasi Pribadi',
                                ),
                                _buildField(
                                  controller: _nameController,
                                  label: 'Nama Lengkap',
                                  icon: Icons.badge_outlined,
                                ),
                                _buildField(
                                  initialValue: user.email,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  readOnly: true,
                                ),
                                _buildField(
                                  controller: _phoneController,
                                  label: 'Telepon',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          GlassCard(
                            padding: const EdgeInsets.all(18),
                            borderRadius: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSectionTitle(
                                  Icons.location_on_rounded,
                                  'Alamat & Lokasi',
                                  trailing: _buildMapButton(),
                                ),
                                if (_latitude != null && _longitude != null)
                                  _buildCoordinateChip(),
                                _buildField(
                                  controller: _addressController,
                                  label: 'Alamat Lengkap',
                                  icon: Icons.home_outlined,
                                  maxLines: 3,
                                ),
                                _buildField(
                                  controller: _cityController,
                                  label: 'Kota',
                                  icon: Icons.location_city_outlined,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tombol simpan menempel di bawah
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: GradientButton(
                label: 'Simpan ke Database',
                icon: Icons.save_rounded,
                width: double.infinity,
                isLoading: _saving,
                onPressed: _saveProfile,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
