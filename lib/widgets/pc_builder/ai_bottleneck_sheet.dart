import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/services/gemini_service.dart';
import 'package:doctor_computer/providers/notification_provider.dart';

class AiBottleneckSheet extends StatelessWidget {
  final PcPartModel? cpu;
  final PcPartModel? gpu;
  final PcPartModel? ram;

  const AiBottleneckSheet({
    super.key,
    required this.cpu,
    required this.gpu,
    this.ram,
  });

  @override
  Widget build(BuildContext context) {
    final result = GeminiService().calculateBottleneck(cpu: cpu, gpu: gpu, ram: ram);
    final percentage = result['bottleneckPercentage'] as int? ?? 0;
    final status = result['status'] as String? ?? '';
    final advice = result['advice'] as String? ?? '';
    final color = result['color'] as Color? ?? Colors.green;
    final res = result['recommendedResolution'] as String? ?? '1080p';
    final fpsMap = result['gamingFps'] as Map<String, String>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.speed, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Bottleneck Calculator', style: AppTextStyles.titleMedium),
                      Text('Analisis Keseimbangan Prosesor & Grafis', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Comparison Row
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PROSESOR (CPU)', style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(cpu?.name ?? 'Belum Dipilih', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('VS', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('KARTU GRAFIS (GPU)', style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(gpu?.name ?? 'Belum Dipilih', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Score card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color, width: 2),
              ),
              child: Column(
                children: [
                  Text('$percentage%', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: color)),
                  Text(status, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 8),
                  Text(
                    advice,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text('Rekomendasi Resolusi: $res', style: AppTextStyles.titleSmall),
            const SizedBox(height: 12),

            // Game FPS Estimates
            Text('Estimasi FPS Pada Game Populer:', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: fpsMap.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key, style: AppTextStyles.bodySmall),
                        Text(entry.value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Push Notification trigger button if bottleneck high
            if (percentage > 15)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  minimumSize: const Size(double.infinity, 46),
                ),
                icon: const Icon(Icons.notification_add, color: Colors.white),
                label: const Text('Simpan Peringatan ke Notifikasi Mobile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  context.read<NotificationProvider>().addNotification(
                    title: '⚠️ Peringatan Bottleneck PC ($percentage%)',
                    message: 'Konfigurasi ${cpu?.name ?? 'CPU'} dan ${gpu?.name ?? 'GPU'} memiliki bottleneck $percentage%. $advice',
                    type: 'bottleneck',
                    actionRoute: '/pc-builder',
                    actionLabel: 'Lihat PC Builder',
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('Notifikasi Peringatan Bottleneck berhasil dikirim ke panel notifikasi!'),
                    ),
                  );
                },
              ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
