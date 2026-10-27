import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/providers/notification_provider.dart';

Widget sensorStatusBadge({required bool available, required bool active}) {
  final color = available ? AppColors.success : AppColors.error;
  final label = !available
      ? 'SENSOR TIDAK TERSEDIA'
      : active
      ? 'SENSOR AKTIF'
      : 'SENSOR SIAP';

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          available ? Icons.sensors : Icons.sensors_off,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

String formatCooldownDate(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day ${months[local.month - 1]} ${local.year}, $hour:$minute';
}

Widget? minigameCooldownNotice({
  required bool isLoading,
  required DateTime? availableAt,
  String? error,
  VoidCallback? onRetry,
}) {
  if (isLoading) {
    return sensorResultCard(
      title: 'Memeriksa jadwal game',
      message: 'Mengambil status cooldown dari server...',
      color: AppColors.accent,
    );
  }
  if (error != null) {
    return Column(
      children: [
        sensorResultCard(
          title: 'Jadwal game tidak dapat dimuat',
          message: error,
          color: AppColors.error,
        ),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba muat ulang'),
          ),
      ],
    );
  }
  if (availableAt == null || !availableAt.isAfter(DateTime.now())) return null;

  return sensorResultCard(
    title: 'Game sedang cooldown',
    message:
        'Game ini bisa dimainkan kembali pada ${formatCooldownDate(availableAt)}. Cooldown berlaku 3 hari untuk game ini saja.',
    color: AppColors.warning,
  );
}

Future<DateTime?> loadMinigameCooldown(
  BuildContext context,
  String game,
) {
  return context.read<BlockchainProvider>().getMinigameCooldown(game);
}

Future<String?> awardSensorGame({
  required BuildContext context,
  required String game,
  required String notificationTitle,
  required Map<String, dynamic> result,
}) async {
  final award = await context.read<BlockchainProvider>().awardMinigameExp(
    game: game,
    result: result,
  );
  if (!context.mounted) return null;

  await context.read<AuthProvider>().restoreSession();
  if (!context.mounted) return null;

  final message = BlockchainProvider.describeAward(award);
  context.read<NotificationProvider>().addNotification(
    title: notificationTitle,
    message: message,
    type: 'minigame',
  );
  return message;
}

Widget sensorResultCard({
  required String title,
  required String message,
  required Color color,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_rounded, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleSmall),
              const SizedBox(height: 4),
              Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
