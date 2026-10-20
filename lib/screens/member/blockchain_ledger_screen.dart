import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';

class BlockchainLedgerScreen extends StatelessWidget {
  const BlockchainLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BlockchainProvider>();
    final blocks = provider.blockchain;
    final isChainValid = provider.verifyChain();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Buku Besar Blockchain (Ledger)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isChainValid ? AppColors.success : AppColors.error),
              ),
              child: Row(
                children: [
                  Icon(
                    isChainValid ? Icons.verified_user : Icons.gpp_bad,
                    color: isChainValid ? AppColors.success : AppColors.error,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isChainValid ? 'Rantai Blok Valid & Terenkripsi' : 'Integritas Rantai Bermasalah',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: isChainValid ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total ${blocks.length} blok tercatat secara kriptografis terdistribusi.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Urutan Rantai Blok (Block Sequence)', style: AppTextStyles.titleMedium),
            const SizedBox(height: 12),
            ...List.generate(blocks.length, (index) {
              final block = blocks[index];
              final isGenesis = block.index == 0;

              return Column(
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isGenesis ? AppColors.warning : AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'BLOK ${block.index}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                block.title,
                                style: AppTextStyles.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (block.expEarned > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${block.expEarned} EXP',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('DATA PAYLOAD:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              ...block.data.entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${entry.key}: ', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                                      Expanded(
                                        child: Text(
                                          entry.value.toString(),
                                          style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text('Previous Hash: ', style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                            Expanded(
                              child: Text(
                                block.previousHash.length > 20
                                    ? '${block.previousHash.substring(0, 16)}...'
                                    : block.previousHash,
                                style: AppTextStyles.caption.copyWith(fontFamily: 'monospace', color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Block Hash: ', style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                block.hash.length > 20
                                    ? '${block.hash.substring(0, 20)}...'
                                    : block.hash,
                                style: AppTextStyles.caption.copyWith(
                                  fontFamily: 'monospace',
                                  color: isGenesis ? AppColors.warning : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (index < blocks.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Container(width: 2, height: 16, color: AppColors.primary),
                          Icon(Icons.link, size: 20, color: AppColors.primary),
                          Container(width: 2, height: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
