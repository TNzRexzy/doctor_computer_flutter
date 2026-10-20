import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/product_provider.dart';

class FlashDealTimer extends StatefulWidget {
  final bool showLabel;
  const FlashDealTimer({super.key, this.showLabel = false});

  @override
  State<FlashDealTimer> createState() => _FlashDealTimerState();
}

class _FlashDealTimerState extends State<FlashDealTimer> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateTimeLeft();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    final provider = context.read<ProductProvider>();
    final target = provider.flashSaleEndTime;
    final isActive = provider.isFlashSaleActive;
    final now = DateTime.now();

    if (isActive && target.isAfter(now)) {
      setState(() {
        _timeLeft = target.difference(now);
      });
    } else {
      if (_timeLeft != Duration.zero) {
        setState(() {
          _timeLeft = Duration.zero;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return 'Berakhir';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final days = duration.inDays;
    final hours = twoDigits(duration.inHours.remainder(24));
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (days > 0) {
      return '$days hari $hours:$minutes:$seconds';
    }
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final provider = context.watch<ProductProvider>();
    final isEnded = _timeLeft == Duration.zero || !provider.isFlashSaleActive;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel) ...[
          const Icon(Icons.flash_on, color: Colors.amber, size: 20),
          const SizedBox(width: 6),
          Text(
            'Flash Sale',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isEnded
                ? AppColors.surfaceLight
                : AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isEnded
                  ? AppColors.textTertiary.withValues(alpha: 0.2)
                  : AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: isEnded ? AppColors.textTertiary : AppColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDuration(_timeLeft),
                style: AppTextStyles.caption.copyWith(
                  color: isEnded ? AppColors.textTertiary : AppColors.error,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
