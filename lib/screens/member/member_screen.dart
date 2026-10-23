import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/widgets/member/tier_badge.dart';
import 'package:doctor_computer/widgets/member/exp_progress_bar.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';
import 'package:doctor_computer/screens/member/minigames/memory_match_game.dart';
import 'package:doctor_computer/screens/member/minigames/pc_quiz_game.dart';
import 'package:doctor_computer/screens/member/minigames/speed_repair_game.dart';
import 'package:doctor_computer/screens/member/blockchain_ledger_screen.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/models/blockchain/blockchain.dart';

class MemberScreen extends StatelessWidget {
  const MemberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final blockchain = context.watch<BlockchainProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final isAdmin = user?.role == UserRole.admin;

    final effectiveExp = isAdmin
        ? 999999
        : (blockchain.totalExp >= (user?.points ?? 0) ? blockchain.totalExp : (user?.points ?? 0));
    final currentTier = isAdmin
        ? MemberTier.platinum
        : MemberTier.fromExp(effectiveExp);
    final totalExp = effectiveExp;
    final nextTier = isAdmin ? null : currentTier.getNextTier();

    final progress = isAdmin
        ? 1.0
        : (nextTier != null
            ? ((totalExp - currentTier.value) / (nextTier.value - currentTier.value)).clamp(0.0, 1.0)
            : 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Membership & Minigames', style: AppTextStyles.heading3),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Blockchain Ledger',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockchainLedgerScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(currentTier.color).withValues(alpha: 0.8),
                      Color(currentTier.color).withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(currentTier.color).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TierBadge(tier: currentTier, size: 90),
                    const SizedBox(height: 12),
                    Text(
                      user?.fullName ?? 'Member Doctor Computer',
                      style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAdmin
                          ? 'Tier Aktif: PLATINUM (MAX • Hak Akses Administrator)'
                          : 'Tier Aktif: ${currentTier.name.toUpperCase()} (Diskon ${currentTier.discountPercent}%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isAdmin ? 'Total: 999,999 EXP (MAX)' : 'Total: $totalExp EXP',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // EXP Progress
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Progress Naik Tier', style: AppTextStyles.titleSmall),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAdmin
                              ? 'Level Tertinggi (Maksimal)'
                              : (nextTier != null
                                  ? '${nextTier.value - totalExp} EXP lagi ke ${nextTier.name}'
                                  : 'Maksimal (Platinum)'),
                          style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ExpProgressBar(
                      progress: progress,
                      currentLevel: isAdmin ? 'Platinum (MAX)' : currentTier.name,
                      nextLevel: nextTier?.name,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Minigames Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Minigames (Klaim EXP)', style: AppTextStyles.titleMedium),
                  Text('Mainkan & Naikkan Tier', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 12),

              _buildGameCard(
                context: context,
                title: 'Memory Match Komponen PC',
                description: 'Cocokkan kartu CPU, GPU, RAM, SSD untuk melatih ingatan.',
                exp: 150,
                difficulty: 'Mudah',
                icon: Icons.memory,
                color: Colors.teal,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryMatchGame(expReward: 150)));
                },
              ),

              _buildGameCard(
                context: context,
                title: 'Kuis Perakitan PC & Hardware',
                description: 'Uji pengetahuan seputar soket, RAM DDR5, dan spek komputer.',
                exp: 120,
                difficulty: 'Sedang',
                icon: Icons.quiz,
                color: Colors.orange,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PcQuizGame(expReward: 120)));
                },
              ),

              _buildGameCard(
                context: context,
                title: 'Speed Thermal Paste & Repair',
                description: 'Tap cepat untuk membersihkan debu dan mendinginkan CPU.',
                exp: 100,
                difficulty: 'Cepat (10s)',
                icon: Icons.speed,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeedRepairGame(expReward: 100)));
                },
              ),

              const SizedBox(height: 20),

              // Blockchain Quick Link Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockchainLedgerScreen()));
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.hub, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Buku Besar Blockchain Pribadi', style: AppTextStyles.titleSmall),
                          const SizedBox(height: 2),
                          Text('${blockchain.blockchain.length} Blok Tercatat (Genesis A1B2, Game, Belanja)', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Demo Button: Belanja RAM +500 EXP (Block 2)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: BorderSide(color: AppColors.primary),
                ),
                icon: const Icon(Icons.add_shopping_cart, size: 20),
                label: const Text('Simulasi Belanja RAM: +500 EXP (Blok 2 Demo)'),
                onPressed: () async {
                  final block = await blockchain.addShoppingReward(
                    itemName: 'Corsair Vengeance DDR5 32GB RAM',
                    expEarned: 500,
                  );
                  if (context.mounted) {
                    final auth = context.read<AuthProvider>();
                    if (auth.currentUser != null) {
                      final tierEnum = auth.parseMembershipTier(blockchain.currentTier.name);
                      await auth.updatePointsAndTier(blockchain.totalExp, tierEnum);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.success,
                          content: Text('Belanja Berhasil! +500 EXP ditambahkan ke Blok #${block.index}! Tier: ${blockchain.currentTier.name}'),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String description,
    required int exp,
    required String difficulty,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: AppTextStyles.titleSmall)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+$exp EXP',
                          style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Tingkat: $difficulty', style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('Mainkan Sekarang ➔', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}