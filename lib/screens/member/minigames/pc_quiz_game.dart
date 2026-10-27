import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/screens/member/minigames/sensor_game_support.dart';

class PcQuizGame extends StatefulWidget {
  const PcQuizGame({super.key});

  @override
  State<PcQuizGame> createState() => _PcQuizGameState();
}

class _PcQuizGameState extends State<PcQuizGame> {
  static const double _targetRotation = math.pi * 2;
  static const int _roundSeconds = 12;

  StreamSubscription<GyroscopeEvent>? _sensorSubscription;
  Timer? _timer;
  DateTime? _lastGyroSampleAt;
  double _rotationRadians = 0;
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
      final cooldownUntil = await loadMinigameCooldown(context, 'pc_quiz');
      if (!mounted) return;
      setState(() {
        _cooldownUntil = cooldownUntil;
        _isCooldownLoading = false;
      });
    } catch (error) {
      debugPrint('[PcQuizGame] Could not verify game cooldown: $error');
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
      _rotationRadians = 0;
      _secondsLeft = _roundSeconds;
      _lastGyroSampleAt = null;
      _isPlaying = true;
      _isFinished = false;
      _isCleared = false;
      _isSaving = false;
      _sensorAvailable = true;
      _resultMessage = null;
    });

    _sensorSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(
      _onGyroscope,
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
        unawaited(_finish(cleared: _rotationRadians.abs() >= _targetRotation));
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onGyroscope(GyroscopeEvent event) {
    if (!_isPlaying) return;
    final now = DateTime.now();
    final previousSample = _lastGyroSampleAt;
    _lastGyroSampleAt = now;
    if (previousSample == null) return;

    final elapsed = now.difference(previousSample).inMicroseconds / 1000000;
    if (elapsed <= 0 || elapsed > 0.25) return;
    setState(() {
      _rotationRadians += event.z * elapsed;
    });
    if (_rotationRadians.abs() >= _targetRotation) {
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
      game: 'pc_quiz',
      notificationTitle: 'Kipas pendingin berhasil dikalibrasi',
      result: {'score': 2, 'rotation_radians': _rotationRadians},
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
    final progress = (_rotationRadians.abs() / _targetRotation).clamp(
      0.0,
      1.0,
    );
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
        title: const Text('Gyro Spin: Kalibrasi Kipas'),
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
                  Text('MISI 02', style: AppTextStyles.caption),
                  sensorStatusBadge(
                    available: _sensorAvailable,
                    active: _isPlaying,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.16),
                        AppColors.primary.withValues(alpha: 0.14),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isCleared ? 'KIPAS SIAP!' : 'Nyalakan pendingin',
                        style: AppTextStyles.heading3,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _sensorAvailable
                            ? 'Putar HP satu lingkaran penuh seperti memutar rotor kipas.'
                            : 'Gyroscope tidak tersedia. Game ini membutuhkan sensor rotasi pada HP.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: 210,
                        height: 210,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 10,
                                strokeCap: StrokeCap.round,
                                backgroundColor: AppColors.surface,
                                color: AppColors.accent,
                              ),
                            ),
                            Transform.rotate(
                              angle: _rotationRadians,
                              child: Container(
                                width: 144,
                                height: 144,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surface.withValues(
                                    alpha: 0.78,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.toys_rounded,
                                  size: 82,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '${(progress * 100).round()}%',
                                  style: AppTextStyles.caption.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Metric(
                            label: 'ROTASI',
                            value:
                                '${(_rotationRadians.abs() * 180 / math.pi).round()}°',
                          ),
                          _Metric(label: 'WAKTU', value: '$_secondsLeft dtk'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_isPlaying)
                FilledButton.icon(
                  onPressed: canPlay ? _startGame : null,
                  icon: Icon(
                    _isFinished ? Icons.replay_rounded : Icons.play_arrow,
                  ),
                  label: Text(_isFinished ? 'Coba Lagi' : 'Mulai Kalibrasi'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                  ),
                )
              else
                Text(
                  'Putar HP perlahan dan satu arah',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (cooldownNotice != null) ...[
                const SizedBox(height: 12),
                cooldownNotice,
              ],
              if (_isCleared && _isSaving) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ] else if (_isCleared && _resultMessage != null) ...[
                const SizedBox(height: 12),
                sensorResultCard(
                  title: 'Kalibrasi berhasil',
                  message: _resultMessage!,
                  color: AppColors.success,
                ),
              ] else if (_isFinished && !_isCleared) ...[
                const SizedBox(height: 12),
                sensorResultCard(
                  title: 'Belum satu putaran penuh',
                  message: 'Coba putar HP satu lingkaran penuh sebelum waktu habis.',
                  color: AppColors.warning,
                ),
              ] else if (!_sensorAvailable) ...[
                const SizedBox(height: 12),
                sensorResultCard(
                  title: 'Gyroscope tidak tersedia',
                  message:
                      'Sensor gyroscope tidak dapat dibaca pada perangkat ini.',
                  color: AppColors.error,
                ),
              ],
              const SizedBox(height: 10),
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

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
