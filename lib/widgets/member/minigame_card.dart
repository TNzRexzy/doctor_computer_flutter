import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/widgets/common/app_toast.dart';

class MinigameCard extends StatefulWidget {
  final Map<String, dynamic> game;

  const MinigameCard({super.key, required this.game});

  @override
  State<MinigameCard> createState() => _MinigameCardState();
}

class _MinigameCardState extends State<MinigameCard> {
  bool _isCompleted = false;
  static final Set<String> _completedGames = {};

  @override
  void initState() {
    super.initState();
    _isCompleted = _completedGames.contains(widget.game['id']);
  }

  void _completeGame() {
    if (_isCompleted) return;
    setState(() => _isCompleted = true);
    _completedGames.add(widget.game['id']);
    _showCompletion();
  }

  void _showCompletion() {
    AppToast.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Minigame selesai. EXP tidak diberikan sebelum hasil diverifikasi server.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.buttonText),
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _completeGame,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isCompleted
                ? [
                    AppColors.success.withValues(alpha: 0.8),
                    AppColors.accent.withValues(alpha: 0.8),
                  ]
                : [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.accent.withValues(alpha: 0.1),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isCompleted ? AppColors.success : AppColors.primary,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isCompleted ? Icons.check_circle : Icons.play_circle,
              color: _isCompleted ? AppColors.success : AppColors.primary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              widget.game['title'] as String,
              style: AppTextStyles.bodyMedium.copyWith(
                color: _isCompleted ? AppColors.success : AppColors.primary,
                fontWeight: _isCompleted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.game['description'] as String,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, color: AppColors.warning, size: 14),
                const SizedBox(width: 4),
                Text(
                  'EXP nonaktif',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
