import 'dart:async';
import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';

class FlashDealTimer extends StatefulWidget {
  const FlashDealTimer({super.key});

  @override
  State<FlashDealTimer> createState() => _FlashDealTimerState();
}

class _FlashDealTimerState extends State<FlashDealTimer> {
  late DateTime _targetTime;
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _targetTime = DateTime.now().add(const Duration(hours: 8));
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    if (_targetTime.isAfter(now)) {
      setState(() {
        _timeLeft = _targetTime.difference(now);
      });
    } else {
      _timer.cancel();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.flash_on, color: Colors.amber, size: 24),
        const SizedBox(width: 8),
        Text(
          'Flash Deal',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _formatDuration(_timeLeft),
            style: AppTextStyles.label.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}


