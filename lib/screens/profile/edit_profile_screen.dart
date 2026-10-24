import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
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

  void _showImageUrlDialog() {
    final urlController = TextEditingController(
      text: context.read<AuthProvider>().currentUser?.profileImageUrl ?? '',
    );
    final sampleAvatars = [
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&fit=crop',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&fit=crop',
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&fit=crop',
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&fit=crop',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ubah Foto Profil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Masukkan URL foto atau pilih avatar cepat:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL Gambar (JPG/PNG)',
                    hintText: 'https://example.com/photo.jpg',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Pilihan Avatar Instan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: sampleAvatars.map((url) {
                    final isSelected = urlController.text == url;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          urlController.text = url;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundImage: NetworkImage(url),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  final auth = context.read<AuthProvider>();
                  final nav = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await auth.updateProfileImage(url);
                  if (mounted) {
                    nav.pop();
                    messenger.showSnackBar(
                      SnackBar(content: Text(success ? 'Foto profil diperbarui' : 'Gagal memperbarui foto')),
                    );
                    setState(() {}); // Refresh UI
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
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
                          onTap: () => _showImageUrlDialog(),
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
