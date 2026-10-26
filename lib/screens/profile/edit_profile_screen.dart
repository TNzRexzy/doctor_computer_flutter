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
            title: const Text('Ubah Foto Profil'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.surface,
                    backgroundImage: preview,
                    child: preview == null
                        ? Icon(Icons.person, size: 44, color: AppColors.textTertiary)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
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
                              setDialogState(() => error = 'Gagal membuka galeri.');
                            }
                          },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Pilih Foto dari Perangkat'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Format JPG, PNG, atau GIF. Maksimal 5 MB.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: (picked == null || saving)
                    ? null
                    : () async {
                        final auth = this.context.read<AuthProvider>();
                        final messenger = ScaffoldMessenger.of(this.context);
                        final nav = Navigator.of(ctx);
                        final userId =
                            Supabase.instance.client.auth.currentUser?.id ??
                                auth.currentUser?.id;
                        if (userId == null) {
                          setDialogState(() => error = 'Sesi login tidak ditemukan.');
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final oldUrl = auth.currentUser?.profileImageUrl;
                          final url = await ProfilePhotoService.upload(picked!, userId);
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
                            const SnackBar(content: Text('Foto profil diperbarui')),
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
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Alamat peta berhasil diterapkan dan disimpan ke database!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Scaffold();

    final initials = user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text('Edit Profil', style: AppTextStyles.heading3),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.surface,
                        backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                            ? NetworkImage(user.profileImageUrl!)
                            : null,
                        child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
                            ? Text(initials, style: AppTextStyles.heading2)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _showPhotoUploadDialog(),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary,
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                      ),
                      TextFormField(
                        initialValue: user.email,
                        readOnly: true,
                        style: TextStyle(color: AppColors.textSecondary),
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Telepon'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Alamat & Lokasi', style: TextStyle(fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _openMapPicker,
                            icon: const Icon(Icons.map, size: 14),
                            label: const Text('Pilih via Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_latitude != null && _longitude != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.pin_drop, color: AppColors.primary, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Koordinat Peta: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)} (Tersimpan di DB)',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Alamat Lengkap'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'Kota'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Simpan ke Database',
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    final success = await auth.updateProfile(
                      _nameController.text.trim(),
                      _phoneController.text.trim(),
                      _addressController.text.trim(),
                      _cityController.text.trim(),
                      latitude: _latitude,
                      longitude: _longitude,
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(success ? 'Profil & Alamat berhasil disimpan ke Database' : 'Gagal memperbarui profil')),
                      );
                      if (success) nav.pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
