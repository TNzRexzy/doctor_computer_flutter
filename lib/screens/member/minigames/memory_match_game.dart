import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/providers/blockchain_provider.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/providers/notification_provider.dart';

class MemoryMatchGame extends StatefulWidget {
  final int expReward;
  const MemoryMatchGame({super.key, this.expReward = 150});

  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _CardItem {
  final int id;
  final String title;
  final IconData icon;
  bool isFlipped = false;
  bool isMatched = false;

  _CardItem({
    required this.id,
    required this.title,
    required this.icon,
  });
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  late List<_CardItem> _cards;
  int? _firstFlippedIndex;
  bool _isProcessing = false;
  int _moves = 0;
  bool _isCompleted = false;

  final List<Map<String, dynamic>> _pairs = [
    {'title': 'CPU', 'icon': Icons.memory},
    {'title': 'GPU', 'icon': Icons.videogame_asset},
    {'title': 'RAM', 'icon': Icons.sd_card},
    {'title': 'SSD', 'icon': Icons.storage},
    {'title': 'Motherboard', 'icon': Icons.developer_board},
    {'title': 'Cooler', 'icon': Icons.ac_unit},
  ];

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    List<_CardItem> items = [];
    for (int i = 0; i < _pairs.length; i++) {
      items.add(_CardItem(id: i, title: _pairs[i]['title'] as String, icon: _pairs[i]['icon'] as IconData));
      items.add(_CardItem(id: i, title: _pairs[i]['title'] as String, icon: _pairs[i]['icon'] as IconData));
    }
    items.shuffle();
    setState(() {
      _cards = items;
      _firstFlippedIndex = null;
      _isProcessing = false;
      _moves = 0;
      _isCompleted = false;
    });
  }

  void _onCardTap(int index) async {
    if (_isProcessing || _isCompleted || _cards[index].isFlipped || _cards[index].isMatched) return;

    setState(() {
      _cards[index].isFlipped = true;
    });

    if (_firstFlippedIndex == null) {
      _firstFlippedIndex = index;
    } else {
      _moves++;
      _isProcessing = true;
      final first = _firstFlippedIndex!;
      final second = index;

      if (_cards[first].id == _cards[second].id) {
        // Matched!
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        setState(() {
          _cards[first].isMatched = true;
          _cards[second].isMatched = true;
          _firstFlippedIndex = null;
          _isProcessing = false;
        });

        // Check if all matched
        if (_cards.every((c) => c.isMatched)) {
          _handleGameSuccess();
        }
      } else {
        // Not matched
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() {
          _cards[first].isFlipped = false;
          _cards[second].isFlipped = false;
          _firstFlippedIndex = null;
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleGameSuccess() async {
    setState(() {
      _isCompleted = true;
    });

    final blockchainProvider = context.read<BlockchainProvider>();
    final auth = context.read<AuthProvider>();
    final oldTier = blockchainProvider.currentTier;
    final block = await blockchainProvider.addMinigameReward(
      gameTitle: 'Memory Match Komponen PC',
      expEarned: widget.expReward,
      userId: auth.currentUser?.id,
      userName: auth.currentUser?.fullName,
    );
    final newTier = blockchainProvider.currentTier;

    // Send notification
    if (mounted) {
      context.read<NotificationProvider>().addNotification(
        title: 'Minigame Selesai: +${widget.expReward} EXP!',
        message: 'Selamat! Blok baru (#${block.index}) telah dicatat di Blockchain dengan Hash: ${block.hash.substring(0, 10)}...',
        type: 'minigame',
      );

      if (newTier != oldTier) {
        context.read<NotificationProvider>().addNotification(
          title: 'Upgrade Member Tier: ${newTier.name}!',
          message: 'Luar biasa! Akumulasi EXP Anda sekarang ${blockchainProvider.totalExp} EXP dan Tier Anda naik ke ${newTier.name}!',
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
        title: Row(
          children: [
            Icon(Icons.celebration, color: AppColors.warning, size: 28),
            const SizedBox(width: 8),
            Text('Kemenangan!', style: AppTextStyles.titleMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Semua kartu komponen berhasil dicocokkan dalam $_moves langkah!', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reward EXP:', style: AppTextStyles.bodySmall),
                      Text('+${widget.expReward} EXP', style: AppTextStyles.titleSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Blok Dibuat:', style: AppTextStyles.bodySmall),
                      Text('Blok #${block.index}', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('New Hash: ${block.hash.substring(0, 16)}...', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  if (newTier != oldTier) ...[
                    const Divider(),
                    Text('TIER UPGRADE: ${newTier.name.toUpperCase()}!', style: AppTextStyles.titleSmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold)),
                  ],
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              _startNewGame();
            },
            child: const Text('Main Lagi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Memory Match PC'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startNewGame,
            tooltip: 'Ulangi Permainan',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Langkah: $_moves', style: AppTextStyles.titleSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: AppColors.warning, size: 16),
                        const SizedBox(width: 4),
                        Text('+${widget.expReward} EXP', style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: _cards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    final isRevealed = card.isFlipped || card.isMatched;

                    return GestureDetector(
                      onTap: () => _onCardTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: card.isMatched
                              ? AppColors.success.withValues(alpha: 0.2)
                              : (isRevealed ? AppColors.surface : AppColors.primary),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: card.isMatched
                                ? AppColors.success
                                : (isRevealed ? AppColors.primary : AppColors.primaryDark),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: isRevealed
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(card.icon, size: 36, color: card.isMatched ? AppColors.success : AppColors.primary),
                                    const SizedBox(height: 6),
                                    Text(card.title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                                  ],
                                )
                              : const Icon(Icons.computer, color: Colors.white, size: 32),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
