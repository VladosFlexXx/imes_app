part of '../../home/tab_schedule.dart';

class InteractiveDaySwipe extends StatefulWidget {
  final Widget child;
  final ValueKey<String> pageKey;
  final ValueChanged<int> onSwipeDay; // -1 = previous day, +1 = next day
  final int slideDir; // -1, 0, +1 for programmatic navigation

  const InteractiveDaySwipe({
    super.key,
    required this.child,
    required this.pageKey,
    required this.onSwipeDay,
    this.slideDir = 0,
  });

  @override
  State<InteractiveDaySwipe> createState() => _InteractiveDaySwipeState();
}

class _InteractiveDaySwipeState extends State<InteractiveDaySwipe>
    with TickerProviderStateMixin {
  late final AnimationController _settleController;
  late final AnimationController _entryController;

  late Animation<double> _settleAnimation;
  late Animation<double> _entryAnimation;

  double _dragOffset = 0.0;
  bool _isDragging = false;
  bool _thresholdCrossed = false;
  int _lastSwipeDir = 0; // -1 or +1
  double _entryStartOffset = 0.0;

  static const double _kThreshold = 65.0;

  @override
  void initState() {
    super.initState();

    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _settleAnimation =
        Tween<double>(begin: 0.0, end: 0.0).animate(_settleController);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );

    // Initial load: already resting
    _entryController.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant InteractiveDaySwipe oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.pageKey != oldWidget.pageKey) {
      _settleController.stop();
      _dragOffset = 0.0;
      _isDragging = false;
      _thresholdCrossed = false;

      if (_lastSwipeDir != 0) {
        _entryStartOffset = _lastSwipeDir == 1 ? 75.0 : -75.0;
        _lastSwipeDir = 0;
      } else {
        if (widget.slideDir != 0) {
          _entryStartOffset = widget.slideDir > 0 ? 65.0 : -65.0;
        } else {
          _entryStartOffset = 0.0;
        }
      }

      _entryController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _settleController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  double _dampOffset(double raw) {
    final abs = raw.abs();
    if (abs <= 80.0) return raw;
    final over = abs - 80.0;
    final damped = 80.0 + 50.0 * (1.0 - math.exp(-over / 90.0));
    return raw.sign * damped;
  }

  void _onDragStart(DragStartDetails details) {
    _settleController.stop();
    _entryController.stop();
    setState(() {
      _isDragging = true;
      _dragOffset = 0.0;
      _thresholdCrossed = false;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final delta = details.primaryDelta ?? details.delta.dx;
    final newOffset = _dragOffset + delta;

    final crossed = newOffset.abs() >= _kThreshold;
    if (crossed && !_thresholdCrossed) {
      _thresholdCrossed = true;
      AppHaptics.selectionClick();
    } else if (!crossed && _thresholdCrossed) {
      _thresholdCrossed = false;
    }

    setState(() {
      _dragOffset = newOffset;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final vx = details.primaryVelocity ?? 0.0;
    final crossed = _dragOffset.abs() >= _kThreshold;
    final flicked = (vx.abs() >= 260) &&
        (vx.sign == _dragOffset.sign || _dragOffset.abs() > 15);
    final shouldSwitch = crossed || flicked;

    if (!shouldSwitch || _dragOffset == 0.0) {
      final currentDamped = _dampOffset(_dragOffset);
      _settleAnimation = Tween<double>(
        begin: currentDamped,
        end: 0.0,
      ).animate(
        CurvedAnimation(
          parent: _settleController,
          curve: Curves.easeOutBack,
        ),
      );
      _settleController.duration = const Duration(milliseconds: 220);
      _settleController.forward(from: 0.0);
      setState(() {
        _dragOffset = 0.0;
      });
      return;
    }

    final dir = (_dragOffset > 0 || vx > 0) ? -1 : 1;
    _lastSwipeDir = dir;

    final screenW = MediaQuery.of(context).size.width;
    final currentDamped = _dampOffset(_dragOffset);
    final flingTarget = dir == 1 ? -screenW * 0.85 : screenW * 0.85;

    _settleAnimation = Tween<double>(
      begin: currentDamped,
      end: flingTarget,
    ).animate(
      CurvedAnimation(
        parent: _settleController,
        curve: Curves.easeInCubic,
      ),
    );
    _settleController.duration = const Duration(milliseconds: 130);
    _settleController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      widget.onSwipeDay(dir);
    });

    setState(() {
      _dragOffset = 0.0;
    });
  }

  void _onDragCancel() {
    if (!_isDragging) return;
    _isDragging = false;
    final currentDamped = _dampOffset(_dragOffset);
    _settleAnimation = Tween<double>(
      begin: currentDamped,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _settleController,
        curve: Curves.easeOutBack,
      ),
    );
    _settleController.duration = const Duration(milliseconds: 200);
    _settleController.forward(from: 0.0);
    setState(() {
      _dragOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: _onDragCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_settleController, _entryController]),
        builder: (context, child) {
          double offset = 0.0;
          double tilt = 0.0;
          double scale = 1.0;
          double opacity = 1.0;

          if (_isDragging) {
            offset = _dampOffset(_dragOffset);
            tilt = (offset / 1400.0).clamp(-0.035, 0.035);
            scale = 1.0 - (offset.abs() / 2500.0).clamp(0.0, 0.03);
            opacity = (1.0 - (offset.abs() / 1500.0)).clamp(0.75, 1.0);
          } else if (_settleController.isAnimating) {
            offset = _settleAnimation.value;
            tilt = (offset / 1400.0).clamp(-0.035, 0.035);
            scale = 1.0 - (offset.abs() / 2500.0).clamp(0.0, 0.03);
            opacity = (1.0 - (offset.abs() / 1500.0)).clamp(0.0, 1.0);
          } else if (_entryController.isAnimating) {
            final t = _entryAnimation.value;
            offset = (1.0 - t) * _entryStartOffset;
            tilt = 0.0;
            scale = 0.98 + 0.02 * t;
            opacity = (0.2 + 0.8 * t).clamp(0.0, 1.0);
          }

          return Transform.translate(
            offset: Offset(offset, 0.0),
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
