import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';
import 'package:doctor_computer/services/gemini_service.dart';
import 'package:doctor_computer/providers/notification_provider.dart';
import 'package:doctor_computer/widgets/common/app_toast.dart';

class AiBottleneckSheet extends StatefulWidget {
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
  State<AiBottleneckSheet> createState() => _AiBottleneckSheetState();
}

class _AiBottleneckSheetState extends State<AiBottleneckSheet> {
  Map<String, dynamic>? _result;
  bool _loading = true;

  PcPartModel? get cpu => widget.cpu;
  PcPartModel? get gpu => widget.gpu;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  /// Sends the selected parts to Gemini as soon as the sheet is opened.
  Future<void> _analyze() async {
    final result = await GeminiService().calculateBottleneckAI(
      cpu: widget.cpu,
      gpu: widget.gpu,
      ram: widget.ram,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result ?? const <String, dynamic>{};
    final percentage = result['bottleneckPercentage'] as int? ?? 0;
    final status = result['status'] as String? ?? '';
    final advice = result['advice'] as String? ?? '';
    final color = result['color'] as Color? ?? Colors.green;
    final res = result['recommendedResolution'] as String? ?? '1080p';
    final fpsMap = result['gamingFps'] as Map<String, String>? ?? {};
    final isLocal = result['source'] == 'local';

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
                      Text(
                        'AI Bottleneck Calculator',
                        style: AppTextStyles.titleMedium,
                      ),
                      Text(
                        'Analisis Keseimbangan Prosesor & Grafis',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
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
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROSESOR (CPU)',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cpu?.name ?? 'Belum Dipilih',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'KARTU GRAFIS (GPU)',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gpu?.name ?? 'Belum Dipilih',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Score card
            if (_loading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Gemini AI sedang menganalisis kombinasi CPU & GPU...',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
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
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      advice,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isLocal) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Estimasi offline (Gemini AI tidak tersedia saat ini).',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 20),

            Text(
              _loading
                  ? 'Rekomendasi Resolusi: ...'
                  : 'Rekomendasi Resolusi: $res',
              style: AppTextStyles.titleSmall,
            ),
            const SizedBox(height: 12),

            // Game FPS Estimates
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimasi FPS Pada Game Populer:',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    _buildLegendDot(AppColors.success, '≥60'),
                    const SizedBox(width: 8),
                    _buildLegendDot(AppColors.warning, '30-59'),
                    const SizedBox(width: 8),
                    _buildLegendDot(AppColors.error, '<30'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : fpsMap.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Pilih CPU dan GPU untuk melihat estimasi FPS.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: fpsMap.entries.map((entry) {
                        final fpsValue =
                            int.tryParse(
                              entry.value.replaceAll(RegExp(r'[^0-9]'), ''),
                            ) ??
                            0;
                        final Color fpsColor;
                        if (fpsValue >= 60) {
                          fpsColor = AppColors.success;
                        } else if (fpsValue >= 30) {
                          fpsColor = AppColors.warning;
                        } else {
                          fpsColor = AppColors.error;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sports_esports,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: AppTextStyles.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: fpsColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: fpsColor.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: fpsColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      entry.value,
                                      style: TextStyle(
                                        color: fpsColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 20),

            // Push Notification trigger button if bottleneck high
            if (!_loading && percentage > 15)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  minimumSize: const Size(double.infinity, 46),
                ),
                icon: const Icon(Icons.notification_add, color: Colors.white),
                label: const Text(
                  'Simpan Peringatan ke Notifikasi Mobile',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  context.read<NotificationProvider>().addNotification(
                    title: '⚠️ Peringatan Bottleneck PC ($percentage%)',
                    message:
                        'Konfigurasi ${cpu?.name ?? 'CPU'} dan ${gpu?.name ?? 'GPU'} memiliki bottleneck $percentage%. $advice',
                    type: 'bottleneck',
                    actionRoute: '/pc-builder',
                    actionLabel: 'Lihat PC Builder',
                  );
                  Navigator.pop(context);
                  AppToast.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text(
                        'Notifikasi Peringatan Bottleneck berhasil dikirim ke panel notifikasi!',
                      ),
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

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
