import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/widgets/common/gradient_button.dart';
import 'package:doctor_computer/data/models/user_model.dart';

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

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _nameController.text = user.fullName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
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
                    Text('Edit Profil / Edit Profile', style: AppTextStyles.heading3),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.surface,
                        child: Text(initials, style: AppTextStyles.heading2),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                GlassCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                      ),
                      TextFormField(
                        initialValue: user.email,
                        readOnly: true,
                        style: const TextStyle(color: Colors.grey),
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Simpan / Save',
                  onPressed: () {
                    final updatedUser = UserModel(
                      id: user.id,
                      email: user.email,
                      fullName: _nameController.text,
                      phone: user.phone,
                      avatarUrl: user.avatarUrl,
                      address: user.address,
                      city: _cityController.text,
                      membershipTier: user.membershipTier,
                      points: user.points,
                      joinDate: user.joinDate,
                    );
                    context.read<AuthProvider>().updateProfile(updatedUser);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profil diperbarui / Profile updated')),
                    );
                    Navigator.pop(context);
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
