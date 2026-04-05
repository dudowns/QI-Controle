// lib/widgets/slide_in_card.dart
import 'package:flutter/material.dart';

class SlideInCard extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double startOffset;
  final Curve curve;
  final int delay;

  const SlideInCard({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.startOffset = 0.3,
    this.curve = Curves.easeOutCubic,
    this.delay = 0,
  });

  @override
  State<SlideInCard> createState() => _SlideInCardState();
}

class _SlideInCardState extends State<SlideInCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset(0, widget.startOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    if (widget.delay > 0) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _offsetAnimation,
        child: widget.child,
      ),
    );
  }
}
