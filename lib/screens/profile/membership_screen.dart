import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/data/models/membership_model.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  List<MembershipModel> _dbTiers = [];

  @override
  void initState() {
    super.initState();
    _fetchMembershipTiers();
  }

  Future<void> _fetchMembershipTiers() async {
    try {
      final List res = await Supabase.instance.client
          .from('membership_tiers')
          .select()
          .order('required_points', ascending: true);
      if (res.isNotEmpty && mounted) {
        setState(() {
          _dbTiers = res.map((t) => MembershipModel.fromMap(t as Map<String, dynamic>)).toList();
        });
        return;
      }
    } catch (e) {
      debugPrint('Notice fetching membership tiers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Scaffold();

    final isAdmin = user.role == UserRole.admin;
    final tierName = isAdmin ? 'Platinum' : user.membershipTier.name;
    final pointsText = isAdmin ? '999,999 Points (MAX)' : '${user.points} Points';

    // Find active tier from DB if available
    MembershipModel? currentDbTier;
    if (_dbTiers.isNotEmpty) {
      try {
        currentDbTier = _dbTiers.firstWhere(
          (t) => t.tier.name.toLowerCase() == tierName.toLowerCase(),
        );
      } catch (_) {}
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text('Membership', style: AppTextStyles.heading3),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('DOCTOR COMPUTER', style: AppTextStyles.label.copyWith(color: Colors.black87)),
                          const Spacer(),
                          const Icon(Icons.diamond, color: Colors.black87),
                        ],
                      ),
                      const Spacer(),
                      Text(user.fullName, style: AppTextStyles.heading3.copyWith(color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(
                        isAdmin ? 'Status: Super Administrator (Hak Akses Maksimal)' : 'Member Resmi Doctor Computer',
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            isAdmin ? 'PLATINUM (MAX)' : tierName.toUpperCase(),
                            style: AppTextStyles.titleLarge.copyWith(color: Colors.black87, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(pointsText, style: AppTextStyles.bodyMedium.copyWith(color: Colors.black87, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Progres Tingkatan Tier', style: AppTextStyles.titleMedium),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTierCircle('Bronze', AppColors.bronze, true),
                    Expanded(child: Container(height: 2, color: AppColors.silver)),
                    _buildTierCircle('Silver', AppColors.silver, isAdmin || user.points >= (_getRequiredPoints('silver') ?? 100)),
                    Expanded(child: Container(height: 2, color: AppColors.surface)),
                    _buildTierCircle('Gold', AppColors.gold, isAdmin || user.points >= (_getRequiredPoints('gold') ?? 500)),
                    Expanded(child: Container(height: 2, color: AppColors.surface)),
                    _buildTierCircle('Platinum', AppColors.platinum, isAdmin || user.points >= (_getRequiredPoints('platinum') ?? 1000)),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('Keuntungan $tierName', style: AppTextStyles.titleMedium),
                    if (currentDbTier != null && currentDbTier.discountPercent > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Diskon ${currentDbTier.discountPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _buildBenefits(tierName, currentDbTier),
                const SizedBox(height: 24),
                Text('Riwayat Poin & EXP', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    children: [
                      if (isAdmin)
                        _buildHistoryItem('+999,999 pts', 'Inisialisasi Administrator Master', 'Aktif')
                      else ...[
                        _buildHistoryItem('+150 pts', 'Pembelian Komponen Hardware', '12 Okt 2026'),
                        _buildHistoryItem('+200 pts', 'Perakitan Custom PC', '15 Okt 2026'),
                        _buildHistoryItem('+100 pts', 'Bonus Minigame Memory Match', '20 Okt 2026'),
                        _buildHistoryItem('+50 pts', 'Ulasan Produk Terverifikasi', '22 Okt 2026'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int? _getRequiredPoints(String tier) {
    if (_dbTiers.isEmpty) return null;
    try {
      return _dbTiers.firstWhere((t) => t.tier.name.toLowerCase() == tier.toLowerCase()).requiredPoints;
    } catch (_) {
      return null;
    }
  }

  Widget _buildTierCircle(String label, Color color, bool filled) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
          child: filled ? const Icon(Icons.check, size: 14, color: Colors.black87) : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildBenefits(String tier, MembershipModel? dbTier) {
    List<String> benefits = [];

    if (dbTier != null && dbTier.benefits.isNotEmpty) {
      benefits = List<String>.from(dbTier.benefits);
    } else {
      benefits = [
        'Cashback poin belanja untuk setiap transaksi',
        'Layanan bantuan konsultasi teknisi',
        'Bonus voucher ulang tahun spesial',
      ];
      if (tier.toLowerCase() == 'silver' || tier.toLowerCase() == 'gold' || tier.toLowerCase() == 'platinum') {
        benefits.add('Gratis biaya pengiriman (Free Ongkir) belanja > 1 Juta');
        benefits.add('Dukungan prioritas Customer Service & Rakit PC');
      }
      if (tier.toLowerCase() == 'platinum') {
        benefits.add('Diskon maksimal 20% untuk semua transaksi & perakitan');
        benefits.add('Akses prioritas rilis produk & komponen langka');
      }
    }

    return Column(
      children: benefits.map((b) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(child: Text(b, style: AppTextStyles.bodyMedium)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildHistoryItem(String points, String title, String date) {
    final isPositive = points.startsWith('+');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyMedium),
              Text(date, style: AppTextStyles.caption),
            ],
          ),
          Text(
            points,
            style: AppTextStyles.titleSmall.copyWith(
              color: isPositive ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
