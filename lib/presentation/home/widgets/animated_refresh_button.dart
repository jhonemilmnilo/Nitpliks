import 'package:flutter/material.dart';

/// A reusable micro-animated refresh button that rotates smoothly
/// when tapped and performs the given asynchronous refresh action.
class AnimatedRefreshButton extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final IconData icon;
  final Color color;
  final double size;
  final String tooltip;

  const AnimatedRefreshButton({
    super.key,
    required this.onRefresh,
    this.icon = Icons.refresh_rounded,
    required this.color,
    this.size = 20.0,
    this.tooltip = 'Refresh',
  });

  @override
  State<AnimatedRefreshButton> createState() => _AnimatedRefreshButtonState();
}

class _AnimatedRefreshButtonState extends State<AnimatedRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    // Start repeating continuous rotation while task is running
    _controller.repeat();

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        // Complete the ongoing revolution gracefully back to origin
        final current = _controller.value;
        final target = (current > 0.0) ? 1.0 : 0.0;
        
        await _controller.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
        _controller.reset();

        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      splashRadius: 22,
      onPressed: _isRefreshing ? null : _handleTap,
      icon: RotationTransition(
        turns: _animation,
        child: Icon(
          widget.icon,
          color: _isRefreshing ? widget.color.withValues(alpha: 0.6) : widget.color,
          size: widget.size,
        ),
      ),
    );
  }
}
