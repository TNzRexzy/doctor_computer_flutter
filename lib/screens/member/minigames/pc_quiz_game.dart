import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/providers/notification_provider.dart';

class PcQuizGame extends StatefulWidget {
  final int expReward;
  const PcQuizGame({super.key, this.expReward = 120});

  @override
  State<PcQuizGame> createState() => _PcQuizGameState();
}

class _PcQuizGameState extends State<PcQuizGame> {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOption;
  bool _answered = false;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Soket motherboard apa yang digunakan oleh prosesor Intel Core Generasi 12, 13, dan 14?',
      'options': ['AM4', 'LGA 1700', 'AM5', 'LGA 1200'],
      'correct': 1,
      'explanation': 'Intel Core Gen 12 (Alder Lake), Gen 13 (Raptor Lake), dan Gen 14 menggunakan soket LGA 1700.',
    },
    {
      'question': 'Tipe memori RAM manakah yang memiliki transfer rate tertinggi dan efisiensi daya terbaik saat ini?',
      'options': ['DDR3', 'DDR4', 'DDR5', 'SDR'],
      'correct': 2,
      'explanation': 'DDR5 adalah standar terbaru dengan frekuensi mulai dari 4800MHz ke atas.',
    },
    {
      'question': 'Jika kartu grafis (GPU) membutuhkan daya 300W dan CPU 125W, berapa watt PSU minimal yang disarankan untuk keamanan?',
      'options': ['450W', '500W', '750W - 850W', '1200W'],
      'correct': 2,
      'explanation': 'Dengan total beban komponen ~450W + headroom transient spikes, PSU 750W-850W adalah pilihan ideal.',
    },
    {
      'question': 'Komponen pendingin manakah yang menggunakan pompa sirkulasi cairan untuk meredam panas prosesor?',
      'options': ['Air Cooler', 'AIO Liquid Cooler', 'Heatsink Pasif', 'Thermal Pad'],
      'correct': 1,
      'explanation': 'AIO (All-in-One) Liquid Cooler menggunakan radiator, pipa, cairan coolant, dan pompa air.',
    },
  ];

  void _chooseOption(int index) {
    if (_answered) return;
    setState(() {
      _selectedOption = index;
      _answered = true;
      if (index == _questions[_currentIndex]['correct']) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _answered = false;
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    final passed = _score >= 2;
    if (passed) {
      final blockchainProvider = context.read<BlockchainProvider>();
      final oldTier = blockchainProvider.currentTier;
      final block = await blockchainProvider.addMinigameReward(
        gameTitle: 'Kuis Perakitan PC',
        expEarned: widget.expReward,
      );
      final newTier = blockchainProvider.currentTier;

      if (mounted) {
        context.read<NotificationProvider>().addNotification(
          title: '🎮 Kuis PC Selesai: +${widget.expReward} EXP!',
          message: 'Skor Anda $_score/${_questions.length}. Blok #${block.index} berhasil ditambang di Blockchain!',
          type: 'minigame',
        );

        if (newTier != oldTier) {
          context.read<NotificationProvider>().addNotification(
            title: '🏆 Upgrade Member Tier: ${newTier.name}!',
            message: 'Tier Anda naik ke ${newTier.name} berkat EXP kuis PC!',
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
          title: const Text('🎉 Selamat! Kuis Lulus!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Skor Anda: $_score dari ${_questions.length} soal benar!', style: AppTextStyles.bodyMedium),
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
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Coba Lagi!'),
          content: Text('Skor Anda $_score/${_questions.length}. Anda perlu minimal 2 jawaban benar untuk mendapatkan EXP.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _currentIndex = 0;
                  _score = 0;
                  _selectedOption = null;
                  _answered = false;
                });
              },
              child: const Text('Ulangi Kuis'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kuis Perakitan PC'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Soal ${_currentIndex + 1} dari ${_questions.length}', style: AppTextStyles.titleSmall),
                  Text('Skor: $_score', style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _questions.length,
                backgroundColor: AppColors.surface,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                q['question'] as String,
                style: AppTextStyles.heading3.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ...List.generate((q['options'] as List).length, (idx) {
                final optionText = q['options'][idx] as String;
                final isSelected = _selectedOption == idx;
                final isCorrect = idx == q['correct'];

                Color borderColor = AppColors.border;
                Color bgColor = AppColors.surface;

                if (_answered) {
                  if (isCorrect) {
                    borderColor = AppColors.success;
                    bgColor = AppColors.success.withValues(alpha: 0.15);
                  } else if (isSelected) {
                    borderColor = AppColors.error;
                    bgColor = AppColors.error.withValues(alpha: 0.15);
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () => _chooseOption(idx),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: borderColor.withValues(alpha: 0.2),
                            child: Text(
                              String.fromCharCode(65 + idx),
                              style: TextStyle(color: borderColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(optionText, style: AppTextStyles.bodyMedium)),
                          if (_answered && isCorrect)
                            Icon(Icons.check_circle, color: AppColors.success)
                          else if (_answered && isSelected && !isCorrect)
                            Icon(Icons.cancel, color: AppColors.error),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (_answered) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '💡 Info: ${q['explanation']}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _nextQuestion,
                    child: Text(
                      _currentIndex < _questions.length - 1 ? 'Soal Berikutnya' : 'Selesai & Klaim EXP',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
