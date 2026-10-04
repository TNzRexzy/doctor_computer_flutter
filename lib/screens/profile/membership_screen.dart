import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/data/models/user_model.dart';

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Scaffold();

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
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('DOCTOR COMPUTER', style: AppTextStyles.label.copyWith(color: Colors.white)),
                          const Spacer(),
                          const Icon(Icons.diamond, color: Colors.white),
                        ],
                      ),
                      const Spacer(),
                      Text(user.fullName, style: AppTextStyles.heading3.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Member sejak 2023 / Member since', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(user.membershipTier.name.toUpperCase(), style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
                          const Spacer(),
                          Text('${user.points} Points', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Tier Progression', style: AppTextStyles.titleMedium),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTierCircle('Bronze', AppColors.bronze, true),
                    Expanded(child: Container(height: 2, color: AppColors.silver)),
                    _buildTierCircle('Silver', AppColors.silver, user.points >= 100),
                    Expanded(child: Container(height: 2, color: AppColors.surface)),
                    _buildTierCircle('Gold', AppColors.gold, user.points >= 500),
                    Expanded(child: Container(height: 2, color: AppColors.surface)),
                    _buildTierCircle('Platinum', AppColors.platinum, user.points >= 1000),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Keuntungan ${user.membershipTier.name} / Benefits', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                _buildBenefits(user.membershipTier.name),
                const SizedBox(height: 24),
                Text('Riwayat Poin / Points History', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    children: [
                      _buildHistoryItem('+150 pts', 'Pembelian #DC-001', '12 Okt 2023'),
                      _buildHistoryItem('+200 pts', 'Pembelian #DC-002', '15 Okt 2023'),
                      _buildHistoryItem('-100 pts', 'Redeem Voucher', '20 Okt 2023'),
                      _buildHistoryItem('+50 pts', 'Review Bonus', '22 Okt 2023'),
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
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildBenefits(String tier) {
    List<String> benefits = [
      'Cashback points on purchases',
      'Standard support',
      'Birthday bonus',
    ];
    if (tier.toLowerCase() == 'silver' || tier.toLowerCase() == 'gold' || tier.toLowerCase() == 'platinum') {
      benefits.add('Free shipping for orders > 1jt');
      benefits.add('Priority support');
    }
    
    return Column(
      children: benefits.map((b) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text(b),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildHistoryItem(String pts, String desc, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(desc, style: AppTextStyles.bodyMedium),
              Text(date, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          Text(pts, style: AppTextStyles.titleSmall.copyWith(color: pts.startsWith('+') ? AppColors.success : AppColors.error)),
        ],
      ),
    );
  }
}
