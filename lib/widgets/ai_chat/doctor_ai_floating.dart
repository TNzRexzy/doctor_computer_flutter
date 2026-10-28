import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/data/models/user_model.dart';
import 'package:doctor_computer/navigation/app_router.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/services/gemini_service.dart';

/// One chat message of the Doctor AI conversation.
class DoctorAiMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  DoctorAiMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

/// Holds the Doctor AI conversation so it survives screen changes and can be
/// opened from anywhere (`DoctorAiController.instance.open()`).
class DoctorAiController extends ChangeNotifier {
  DoctorAiController._();
  static final DoctorAiController instance = DoctorAiController._();

  static const String greeting =
      'Halo! Saya Dokter AI, asisten Doctor Computer. Ada yang bisa saya bantu terkait perakitan PC, klaim garansi, spesifikasi komponen, atau status pesanan Anda?';

  static const List<String> quickPrompts = [
    'Cara klaim garansi toko?',
    'Konsultasi upgrade RAM & SSD',
    'Kenapa PC sering bluescreen?',
    'Cara kerja Blockchain Member & Tier?',
    'Rekomendasi spesifikasi PC gaming',
    'Biaya dan paket rakit PC',
  ];

  final List<DoctorAiMessage> messages = [
    DoctorAiMessage(text: greeting, isUser: false, time: DateTime.now()),
  ];

  bool _isOpen = false;
  bool _isLoading = false;
  bool _routeVisible = true;

  bool get isOpen => _isOpen;
  bool get isLoading => _isLoading;
  bool get routeVisible => _routeVisible;

  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  void toggle() => _isOpen ? close() : open();

  void setRouteVisible(bool value) {
    if (_routeVisible == value) return;
    _routeVisible = value;
    notifyListeners();
  }

  void reset() {
    if (_isLoading) return;
    messages
      ..clear()
      ..add(
        DoctorAiMessage(text: greeting, isUser: false, time: DateTime.now()),
      );
    notifyListeners();
  }

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _isLoading) return;

    messages.add(
      DoctorAiMessage(text: text, isUser: true, time: DateTime.now()),
    );
    _isLoading = true;
    notifyListeners();

    final history = messages
        .take(messages.length - 1)
        .map((m) => {'role': m.isUser ? 'user' : 'model', 'text': m.text})
        .toList();

    String reply;
    try {
      reply = await GeminiService().getCustomerServiceResponse(text, history);
    } catch (e) {
      debugPrint('Doctor AI error: $e');
      reply = 'Maaf, Dokter AI sedang mengalami gangguan. Silakan coba lagi sebentar lagi.';
    }

    messages.add(
      DoctorAiMessage(text: reply, isUser: false, time: DateTime.now()),
    );
    _isLoading = false;
    notifyListeners();
  }
}

/// Hides the floating Doctor AI on the splash / onboarding / auth screens.
class DoctorAiRouteObserver extends NavigatorObserver {
  DoctorAiRouteObserver._();
  static final DoctorAiRouteObserver instance = DoctorAiRouteObserver._();

  static const Set<String> _hiddenRoutes = {
    AppRouter.splash,
    AppRouter.onboarding,
    AppRouter.login,
    AppRouter.register,
    AppRouter.welcome,
  };

  String? _current;

  void _update(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) _current = name;
    final visible = !_hiddenRoutes.contains(_current);
    // Navigator callbacks can fire during build; defer the notification.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DoctorAiController.instance.setRouteVisible(visible);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _update(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);
}

/// Wrap the app (MaterialApp.builder) with this to get the floating Doctor AI
/// on top of every screen.
class DoctorAiFloatingHost extends StatelessWidget {
  final Widget child;
  const DoctorAiFloatingHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild on theme change
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        // Own Overlay so TextField, selection handles etc. work above the Navigator.
        Positioned.fill(child: Overlay.wrap(child: const _DoctorAiLayer())),
      ],
    );
  }
}

class _DoctorAiLayer extends StatelessWidget {
  const _DoctorAiLayer();

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild on theme change
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final allowed =
        auth.isLoggedIn && user != null && user.role == UserRole.user;

    return AnimatedBuilder(
      animation: DoctorAiController.instance,
      builder: (context, _) {
        final controller = DoctorAiController.instance;
        if (!allowed || !controller.routeVisible) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final media = MediaQuery.of(context);
            final screen = Size(
              constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : media.size.width,
              constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : media.size.height,
            );
            final keyboard = media.viewInsets.bottom;
            final safe = media.padding;

            final panelWidth = math.min(400.0, screen.width - 24);
            final available =
                screen.height -
                keyboard -
                safe.top -
                24 -
                12 -
                (keyboard > 0 ? 0 : safe.bottom);
            final panelHeight = math.max(
              0.0,
              math.min(available, math.min(screen.height * 0.78, 620.0)),
            );

            return SizedBox.expand(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.035),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: controller.isOpen
                    ? Stack(
                        key: const ValueKey('doctor-ai-panel'),
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: (screen.width - panelWidth) / 2,
                            bottom:
                                keyboard +
                                12 +
                                (keyboard > 0 ? 0 : safe.bottom),
                            width: panelWidth,
                            height: panelHeight,
                            child: const _DoctorAiPanel(),
                          ),
                        ],
                      )
                    : Stack(
                        key: const ValueKey('doctor-ai-bubble'),
                        clipBehavior: Clip.none,
                        children: [
                          _DoctorAiBubble(
                            screen: screen,
                            safe: safe,
                            onTap: controller.open,
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Draggable round floating button.
class _DoctorAiBubble extends StatefulWidget {
  final Size screen;
  final EdgeInsets safe;
  final VoidCallback onTap;

  const _DoctorAiBubble({
    required this.screen,
    required this.safe,
    required this.onTap,
  });

  @override
  State<_DoctorAiBubble> createState() => _DoctorAiBubbleState();
}

class _DoctorAiBubbleState extends State<_DoctorAiBubble> {
  static const double _size = 60;
  static Offset? _savedPosition; // survives panel open/close

  Offset? _position = _savedPosition;
  bool _dragging = false;

  Offset _clamp(Offset o) {
    final minX = 8.0;
    final maxX = math.max(minX, widget.screen.width - _size - 8);
    final minY = widget.safe.top + 8;
    final maxY = math.max(
      minY,
      widget.screen.height - _size - widget.safe.bottom - 8,
    );
    return Offset(
      o.dx.clamp(minX, maxX).toDouble(),
      o.dy.clamp(minY, maxY).toDouble(),
    );
  }

  Offset get _defaultPosition => Offset(
    widget.screen.width - _size - 12,
    widget.screen.height - _size - widget.safe.bottom - 96,
  );

  @override
  Widget build(BuildContext context) {
    final position = _clamp(_position ?? _defaultPosition);

    return AnimatedPositioned(
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: position.dx,
      top: position.dy,
      width: _size,
      height: _size,
      child: Semantics(
        button: true,
        label: 'Tanya Dokter AI',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanStart: (_) => setState(() => _dragging = true),
          onPanUpdate: (details) {
            setState(() {
              _position = _clamp((_position ?? position) + details.delta);
            });
          },
          onPanEnd: (_) {
            setState(() {
              _dragging = false;
              final p = _position ?? position;
              final toLeft = p.dx + _size / 2 < widget.screen.width / 2;
              _position = _clamp(
                Offset(toLeft ? 12 : widget.screen.width - _size - 12, p.dy),
              );
              _savedPosition = _position;
            });
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              Positioned(
                right: 3,
                top: 3,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating chat window.
class _DoctorAiPanel extends StatefulWidget {
  const _DoctorAiPanel();

  @override
  State<_DoctorAiPanel> createState() => _DoctorAiPanelState();
}

class _DoctorAiPanelState extends State<_DoctorAiPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DoctorAiController _controller = DoctorAiController.instance;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _lastCount = _controller.messages.length;
    _controller.addListener(_onControllerChanged);
    _scrollToBottom(jump: true);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final count = _controller.messages.length;
    if (count != _lastCount || _controller.isLoading) {
      _lastCount = count;
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send([String? preset]) {
    final text = (preset ?? _textController.text).trim();
    if (text.isEmpty || _controller.isLoading) return;
    if (preset == null) _textController.clear();
    _controller.send(text);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild on theme change

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: ((value - 0.85) / 0.15).clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(
            scale: value,
            alignment: Alignment.bottomRight,
            child: child,
          ),
        );
      },
      child: Material(
        color: AppColors.background,
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final messages = _controller.messages;
            final isLoading = _controller.isLoading;
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= messages.length) return _buildTyping();
                      return _buildBubble(messages[index]);
                    },
                  ),
                ),
                if (messages.length <= 1) _buildQuickPrompts(),
                _buildInput(isLoading),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final onPrimary = AppColors.buttonText;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.smart_toy_rounded,
              color: Color(0xFFE88700),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dokter AI',
                  style: TextStyle(
                    color: onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Online • Customer Service AI',
                      style: TextStyle(
                        color: onPrimary.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Mulai ulang',
            icon: Icon(Icons.refresh_rounded, color: onPrimary, size: 22),
            onPressed: _controller.reset,
          ),
          IconButton(
            tooltip: 'Tutup',
            icon: Icon(Icons.close_rounded, color: onPrimary, size: 24),
            onPressed: _controller.close,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: DoctorAiController.quickPrompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = DoctorAiController.quickPrompts[index];
          return ActionChip(
            label: Text(prompt, style: const TextStyle(fontSize: 12)),
            backgroundColor: AppColors.surface,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
            shape: const StadiumBorder(),
            onPressed: () => _send(prompt),
          );
        },
      ),
    );
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Dokter AI sedang mengetik...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tanya spesifikasi, garansi, servis...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isLoading ? null : () => _send(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isLoading ? null : AppColors.primaryGradient,
                color: isLoading ? AppColors.surfaceLight : null,
              ),
              child: Icon(
                Icons.send_rounded,
                size: 20,
                color: isLoading ? AppColors.textTertiary : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(DoctorAiMessage msg) {
    final isUser = msg.isUser;
    final textColor = isUser ? AppColors.buttonText : AppColors.textPrimary;
    final base = TextStyle(color: textColor, fontSize: 14, height: 1.4);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Text.rich(TextSpan(children: _formatSpans(msg.text, base))),
      ),
    );
  }

  /// Gemini answers with light markdown; render **bold** and bullet points.
  List<InlineSpan> _formatSpans(String raw, TextStyle base) {
    var text = raw.replaceAll('\r', '').replaceAll('`', '');
    text = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    text = text.replaceAllMapped(
      RegExp(r'^[ \t]*[\*\-][ \t]+', multiLine: true),
      (m) => '• ',
    );

    final spans = <InlineSpan>[];
    final bold = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
    var last = 0;
    for (final m in bold.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: base.copyWith(fontWeight: FontWeight.bold),
        ),
      );
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return spans;
  }
}
