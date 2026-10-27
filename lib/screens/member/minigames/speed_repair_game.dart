import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/screens/member/minigames/sensor_game_support.dart';

class SpeedRepairGame extends StatefulWidget {
  const SpeedRepairGame({super.key});

  @override
  State<SpeedRepairGame> createState() => _SpeedRepairGameState();
}

class _SpeedRepairGameState extends State<SpeedRepairGame> {
  static const int _targetShakes = 12;
  static const int _roundSeconds = 15;

  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  Timer? _timer;
  DateTime? _lastShakeAt;
  int _shakes = 0;
  int _secondsLeft = _roundSeconds;
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
      final cooldownUntil = await loadMinigameCooldown(context, 'speed_repair');
      if (!mounted) return;
      setState(() {
        _cooldownUntil = cooldownUntil;
        _isCooldownLoading = false;
      });
    } catch (error) {
      debugPrint('[SpeedRepairGame] Could not verify game cooldown: $error');
      if (!mounted) return;
      setState(() {
        _cooldownError = 'Pastikan koneksi internet tersedia agar jadwal cooldown dapat diverifikasi.';
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
      _shakes = 0;
      _secondsLeft = _roundSeconds;
      _lastShakeAt = null;
      _isPlaying = true;
      _isFinished = false;
      _isCleared = false;
      _isSaving = false;
      _resultMessage = null;
      _sensorAvailable = true;
    });

    _sensorSubscription =
        userAccelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen(
          _onMotion,
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
        unawaited(_finish(cleared: _shakes >= _targetShakes));
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onMotion(UserAccelerometerEvent event) {
    if (!_isPlaying) return;
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final now = DateTime.now();
    if (magnitude < 6.5 ||
        (_lastShakeAt != null &&
            now.difference(_lastShakeAt!) <
                const Duration(milliseconds: 320))) {
      return;
    }

    _lastShakeAt = now;
    setState(() => _shakes++);
    if (_shakes >= _targetShakes) {
      unawaited(_finish(cleared: true));
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
      game: 'speed_repair',
      notificationTitle: 'Debu PC berhasil dibersihkan',
      result: {'shakes': _shakes, 'duration_seconds': _roundSeconds},
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
    final progress = (_shakes / _targetShakes).clamp(0.0, 1.0);
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
        title: const Text('Shake It: Bersihkan Debu'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MISI 03', style: AppTextStyles.caption),
                  sensorStatusBadge(
                    available: _sensorAvailable,
                    active: _isPlaying,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.20),
                      AppColors.accent.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isCleared
                          ? Icons.auto_awesome
                          : Icons.cleaning_services_rounded,
                      size: 54,
                      color: _isCleared ? AppColors.success : AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isCleared ? 'PC Kembali Bersih!' : 'Bersihkan PC',
                      style: AppTextStyles.heading3,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _sensorAvailable
                          ? 'Goyangkan HP dengan aman untuk mengangkat debu dari kipas dan heatsink.'
                          : 'Sensor gerak tidak tersedia. Coba jalankan game ini di HP yang mendukung accelerometer.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatValue(
                          label: 'GOYANGAN',
                          value: '$_shakes/$_targetShakes',
                          color: AppColors.primary,
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: AppColors.cardBorder,
                        ),
                        _StatValue(
                          label: 'WAKTU',
                          value: '$_secondsLeft dtk',
                          color: _secondsLeft <= 4
                              ? AppColors.error
                              : AppColors.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: AppColors.surface,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!_isPlaying)
                      FilledButton.icon(
                        onPressed: canPlay ? _startGame : null,
                        icon: Icon(
                          _isFinished ? Icons.replay_rounded : Icons.play_arrow,
                        ),
                        label: Text(
                          _isFinished ? 'Coba Lagi' : 'Mulai Bersihkan',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                      )
                    else
                      Text(
                        'Goyangkan maju-mundur dengan mantap',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (cooldownNotice != null) ...[
                cooldownNotice,
                const SizedBox(height: 14),
              ],
              if (_isCleared && _isSaving)
                const LinearProgressIndicator()
              else if (_isCleared && _resultMessage != null)
                sensorResultCard(
                  title: 'Hasil tersimpan',
                  message: _resultMessage!,
                  color: AppColors.success,
                )
              else if (_isFinished && !_isCleared)
                sensorResultCard(
                  title: 'Debu masih menempel',
                  message:
                      'Tercapai $_shakes dari $_targetShakes goyangan. Coba lagi!',
                  color: AppColors.warning,
                )
              else if (!_sensorAvailable)
                sensorResultCard(
                  title: 'Sensor tidak ditemukan',
                  message: 'Game ini membutuhkan accelerometer dan hanya bisa dimainkan di perangkat yang mendukung.',
                  color: AppColors.error,
                ),
              const Spacer(),
              Text(
                'EXP diproses oleh server membership dan mengikuti batas harian.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatValue({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.titleLarge.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
