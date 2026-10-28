import 'dart:async';

import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';

class AppToast {
  const AppToast._(this._context);

  final BuildContext _context;

  static OverlayEntry? _activeEntry;

  static AppToast of(BuildContext context) => AppToast._(context);

  void showSnackBar(SnackBar snackBar) {
    if (!_context.mounted) return;

    final overlay = Overlay.of(_context, rootOverlay: true);
    final previousEntry = _activeEntry;
    _activeEntry = null;
    previousEntry?.remove();
    final theme = Theme.of(_context);
    final backgroundColor = snackBar.backgroundColor ?? AppColors.surface;
    final foregroundColor = snackBar.backgroundColor == null
        ? AppColors.textPrimary
        : backgroundColor.computeLuminance() > 0.55
        ? AppColors.buttonText
        : Colors.white;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppToastOverlay(
        content: snackBar.content,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: theme.snackBarTheme.elevation ?? 8,
        action: snackBar.action,
        duration: snackBar.duration,
        onDismissed: () {
          if (!identical(_activeEntry, entry)) return;
          _activeEntry = null;
          entry.remove();
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }
}

class _AppToastOverlay extends StatefulWidget {
  const _AppToastOverlay({
    required this.content,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.elevation,
    required this.action,
    required this.duration,
    required this.onDismissed,
  });

  final Widget content;
  final Color backgroundColor;
  final Color foregroundColor;
  final double elevation;
  final SnackBarAction? action;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AppToastOverlay> createState() => _AppToastOverlayState();
}

class _AppToastOverlayState extends State<_AppToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _position = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(_opacity);
    _controller.forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _dismissTimer?.cancel();
    if (!mounted) return;
    if (!MediaQuery.of(context).disableAnimations) {
      await _controller.reverse();
    }
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _position,
            child: FadeTransition(
              opacity: _opacity,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.cardBorder.withValues(alpha: 0.8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: widget.elevation + 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: DefaultTextStyle(
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: widget.foregroundColor,
                            ),
                            child: widget.content,
                          ),
                        ),
                        if (widget.action case final action?) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              action.onPressed();
                              unawaited(_dismiss());
                            },
                            child: Text(
                              action.label,
                              style: TextStyle(
                                color:
                                    action.textColor ?? widget.foregroundColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
