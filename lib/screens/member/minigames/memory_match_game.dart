import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/screens/member/minigames/sensor_game_support.dart';

class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});

  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  static const int _roundSeconds = 30;
  static const List<Offset> _componentPositions = [
    Offset(0.78, 0.24),
    Offset(0.24, 0.38),
    Offset(0.70, 0.76),
  ];

  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  Timer? _timer;
  int _secondsLeft = _roundSeconds;
  int _collected = 0;
  Offset _playerPosition = const Offset(0.5, 0.5);
  DateTime? _lastCollectedAt;
  bool _isPlaying = false;
  bool _isFinished = false;
  bool _isCleared = false;
  bool _isSaving = false;
  bool _sensorAvailable = true;
  bool _isCooldownLoading = true;
  DateTime? _cooldownUntil;
  String? _cooldownError;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCooldown());
  }

  Future<void> _loadCooldown() async {
    setState(() {
      _isCooldownLoading = true;
      _cooldownError = null;
    });
    try {
      final cooldownUntil = await loadMinigameCooldown(context, 'memory_match');
      if (!mounted) return;
      setState(() {
        _cooldownUntil = cooldownUntil;
        _isCooldownLoading = false;
      });
    } catch (error) {
      debugPrint('[MemoryMatchGame] Could not verify game cooldown: $error');
      if (!mounted) return;
      setState(() {
        _cooldownError =
            'Pastikan koneksi internet tersedia agar jadwal cooldown dapat diverifikasi.';
        _isCooldownLoading = false;
      });
    }
  }

  Future<void> _startGame() async {
    if (_isCooldownLoading ||
        _cooldownError != null ||
        (_cooldownUntil?.isAfter(DateTime.now()) ?? false)) {
      return;
    }
    await _sensorSubscription?.cancel();
    _timer?.cancel();
    setState(() {
      _secondsLeft = _roundSeconds;
      _collected = 0;
      _playerPosition = const Offset(0.5, 0.5);
      _lastCollectedAt = null;
      _isPlaying = true;
      _isFinished = false;
      _isCleared = false;
      _isSaving = false;
      _sensorAvailable = true;
      _resultMessage = null;
    });

    _sensorSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(
      _onTilt,
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _sensorAvailable = false);
        unawaited(_finish(cleared: false));
      },
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        unawaited(_finish(cleared: _collected == _componentPositions.length));
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onTilt(AccelerometerEvent event) {
    if (!_isPlaying) return;
    const gravity = 9.81;
    final nextPosition = Offset(
      (0.5 + event.x / gravity * 0.48).clamp(0.04, 0.96).toDouble(),
      (0.5 + event.y / gravity * 0.48).clamp(0.04, 0.96).toDouble(),
    );
    final now = DateTime.now();
    final target = _componentPositions[_collected];
    final distance = math.sqrt(
      math.pow(nextPosition.dx - target.dx, 2) +
          math.pow(nextPosition.dy - target.dy, 2),
    );

    setState(() => _playerPosition = nextPosition);
    if (distance < 0.14 &&
        (_lastCollectedAt == null ||
            now.difference(_lastCollectedAt!) >
                const Duration(milliseconds: 450))) {
      _lastCollectedAt = now;
      setState(() => _collected++);
      if (_collected == _componentPositions.length) {
        unawaited(_finish(cleared: true));
      }
    }
  }

  Future<void> _finish({required bool cleared}) async {
    if (!_isPlaying) return;
    _timer?.cancel();
    final subscription = _sensorSubscription;
    _sensorSubscription = null;
    unawaited(subscription?.cancel());
    setState(() {
      _isPlaying = false;
      _isFinished = true;
      _isCleared = cleared;
      _isSaving = cleared;
    });

    if (!cleared) return;
    final message = await awardSensorGame(
      context: context,
      game: 'memory_match',
      notificationTitle: 'Komponen PC berhasil dikumpulkan',
      result: {'components_collected': _collected},
    );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _resultMessage = message;
    });
    await _loadCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sensorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPlay =
        _sensorAvailable &&
        !_isPlaying &&
        !_isSaving &&
        !_isCooldownLoading &&
        _cooldownError == null &&
        !(_cooldownUntil?.isAfter(DateTime.now()) ?? false);
    final cooldownNotice = minigameCooldownNotice(
      isLoading: _isCooldownLoading,
      availableAt: _cooldownUntil,
      error: _cooldownError,
      onRetry: _loadCooldown,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tilt Control: Ambil Komponen'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MISI 01', style: AppTextStyles.caption),
                  sensorStatusBadge(
                    available: _sensorAvailable,
                    active: _isPlaying,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Arahkan teknisi ke komponen',
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Pegang HP mendatar lalu miringkan perlahan untuk menggerakkan teknisi.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _HudValue(
                    icon: Icons.memory_rounded,
                    label: 'KOMPONEN',
                    value: '$_collected/${_componentPositions.length}',
                  ),
                  _HudValue(
                    icon: Icons.timer_outlined,
                    label: 'WAKTU',
                    value: '$_secondsLeft dtk',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _TiltBoard(
                  player: _playerPosition,
                  target: _collected < _componentPositions.length
                      ? _componentPositions[_collected]
                      : null,
                  collected: _collected,
                  active: _isPlaying,
                  sensorAvailable: _sensorAvailable,
                ),
              ),
              const SizedBox(height: 12),
              if (!_isPlaying)
                FilledButton.icon(
                  onPressed: canPlay ? _startGame : null,
                  icon: Icon(
                    _isFinished ? Icons.replay_rounded : Icons.play_arrow,
                  ),
                  label: Text(_isFinished ? 'Main Lagi' : 'Mulai Misi'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                )
              else
                Text(
                  'Kumpulkan ${_componentPositions.length} komponen sebelum waktu habis',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (cooldownNotice != null) ...[
                const SizedBox(height: 10),
                cooldownNotice,
              ],
              if (_isCleared && _isSaving) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ] else if (_isCleared && _resultMessage != null) ...[
                const SizedBox(height: 10),
                sensorResultCard(
                  title: 'Misi berhasil',
                  message: _resultMessage!,
                  color: AppColors.success,
                ),
              ] else if (_isFinished && !_isCleared) ...[
                const SizedBox(height: 10),
                sensorResultCard(
                  title: 'Waktu habis',
                  message: 'Terkumpul $_collected komponen. Coba lagi!',
                  color: AppColors.warning,
                ),
              ] else if (!_sensorAvailable) ...[
                const SizedBox(height: 10),
                sensorResultCard(
                  title: 'Accelerometer tidak tersedia',
                  message:
                      'Game ini membutuhkan accelerometer pada perangkat untuk membaca kemiringan HP.',
                  color: AppColors.error,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TiltBoard extends StatelessWidget {
  final Offset player;
  final Offset? target;
  final int collected;
  final bool active;
  final bool sensorAvailable;

  const _TiltBoard({
    required this.player,
    required this.target,
    required this.collected,
    required this.active,
    required this.sensorAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        const markerSize = 48.0;
        final targetPosition = target;

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surface,
                AppColors.accent.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CircuitPainter(
                      color: AppColors.primary.withValues(alpha: 0.11),
                    ),
                  ),
                ),
                if (targetPosition != null)
                  Positioned(
                    left: (targetPosition.dx * (width - markerSize))
                        .clamp(0.0, width - markerSize)
                        .toDouble(),
                    top: (targetPosition.dy * (height - markerSize))
                        .clamp(0.0, height - markerSize)
                        .toDouble(),
                    child: Container(
                      width: markerSize,
                      height: markerSize,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.memory_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOut,
                  left: (player.dx * (width - markerSize))
                      .clamp(0.0, width - markerSize)
                      .toDouble(),
                  top: (player.dy * (height - markerSize))
                      .clamp(0.0, height - markerSize)
                      .toDouble(),
                  child: Container(
                    width: markerSize,
                    height: markerSize,
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : AppColors.surfaceLight,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.engineering_rounded,
                      color: active ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (!active)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        sensorAvailable ? 'SIAPKAN HP MENDATAR' : 'SENSOR OFFLINE',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Text(
                    '$collected/3 PARTS',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HudValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HudValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CircuitPainter extends CustomPainter {
  final Color color;

  const _CircuitPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var index = 1; index < 6; index++) {
      final y = size.height * index / 6;
      final path = Path()
        ..moveTo(0, y)
        ..lineTo(size.width * 0.18, y)
        ..lineTo(size.width * 0.24, y + 18)
        ..lineTo(size.width * 0.76, y + 18)
        ..lineTo(size.width * 0.82, y);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) =>
      oldDelegate.color != color;
}
