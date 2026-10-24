import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/notification_provider.dart';

class SpeedRepairGame extends StatefulWidget {
  final int expReward;
  const SpeedRepairGame({super.key, this.expReward = 100});

  @override
  State<SpeedRepairGame> createState() => _SpeedRepairGameState();
}

class _SpeedRepairGameState extends State<SpeedRepairGame> {
  int _clicks = 0;
  final int _targetClicks = 25;
  int _timeLeft = 10;
  Timer? _timer;
  bool _isPlaying = false;
  bool _isGameOver = false;

  void _startGame() {
    setState(() {
      _clicks = 0;
      _timeLeft = 10;
      _isPlaying = true;
      _isGameOver = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timer?.cancel();
          _isPlaying = false;
          _isGameOver = true;
          _checkResult();
        }
      });
    });
  }

  void _onTapRepair() {
    if (!_isPlaying) return;
    setState(() {
      _clicks++;
      if (_clicks >= _targetClicks) {
        _timer?.cancel();
        _isPlaying = false;
        _isGameOver = true;
        _checkResult();
      }
    });
  }

  Future<void> _checkResult() async {
    if (_clicks >= _targetClicks) {
      final blockchainProvider = context.read<BlockchainProvider>();
      final auth = context.read<AuthProvider>();
      final oldTier = blockchainProvider.currentTier;
      final block = await blockchainProvider.addMinigameReward(
        gameTitle: 'Speed Thermal Paste & Cleaning',
        expEarned: widget.expReward,
        userId: auth.currentUser?.id,
        userName: auth.currentUser?.fullName,
      );
      final newTier = blockchainProvider.currentTier;

      if (mounted) {
        context.read<NotificationProvider>().addNotification(
          title: 'PC Repair Selesai: +${widget.expReward} EXP!',
          message: 'Komputer bersih dan dingin kembali! Blok #${block.index} berhasil ditambang di Blockchain.',
          type: 'minigame',
        );

        if (newTier != oldTier) {
          context.read<NotificationProvider>().addNotification(
            title: 'Upgrade Member Tier: ${newTier.name}!',
            message: 'Tier Anda naik ke ${newTier.name}!',
            type: 'tier_upgrade',
          );
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('PC Berhasil Di-Service!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Suhu CPU turun drastis ke 35°C!', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reward: +${widget.expReward} EXP', style: AppTextStyles.titleSmall.copyWith(color: AppColors.success)),
                    Text('Blok Blockchain #${block.index}', style: AppTextStyles.caption),
                    Text('Hash: ${block.hash.substring(0, 16)}...', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Kembali ke Member'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_clicks / _targetClicks).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Speed PC Repair'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Bersihkan Debu & Ganti Thermal Paste!', style: AppTextStyles.heading3, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Tekan tombol secepat mungkin sebelum waktu habis untuk mendinginkan CPU!', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Waktu', style: AppTextStyles.caption),
                      Text('$_timeLeft dtk', style: AppTextStyles.heading2.copyWith(color: _timeLeft <= 3 ? AppColors.error : AppColors.primary)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Progress Tap', style: AppTextStyles.caption),
                      Text('$_clicks / $_targetClicks', style: AppTextStyles.heading2.copyWith(color: AppColors.accent)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: progress,
                minHeight: 14,
                backgroundColor: AppColors.surface,
                color: AppColors.success,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 36),
              if (!_isPlaying && !_isGameOver) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text('Mulai Permainan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _startGame,
                ),
              ] else if (_isPlaying) ...[
                GestureDetector(
                  onTap: _onTapRepair,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [AppColors.accent, AppColors.primary]),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          spreadRadius: 8,
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app, size: 50, color: Colors.white),
                          SizedBox(height: 8),
                          Text('TAP CEPAT!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (_isGameOver && _clicks < _targetClicks) ...[
                Text('Waktu Habis! Anda baru mencapai $_clicks tap.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: _startGame,
                  child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
