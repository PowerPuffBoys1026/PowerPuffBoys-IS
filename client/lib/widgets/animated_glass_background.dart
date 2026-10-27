import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class AnimatedGlassBackground extends StatefulWidget {
  const AnimatedGlassBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedGlassBackground> createState() => _AnimatedGlassBackgroundState();
}

class _AnimatedGlassBackgroundState extends State<AnimatedGlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF060814),
                Color(0xFF0B1026),
                Color(0xFF10162B),
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final dx1 = math.sin(t * math.pi) * 40;
            final dy1 = math.cos(t * math.pi) * 30;
            final dx2 = math.cos(t * math.pi * 0.7) * 60;
            final dy2 = math.sin(t * math.pi * 0.7) * 40;
            final dx3 = math.sin(t * math.pi * 0.5) * 50;
            final dy3 = math.cos(t * math.pi * 0.5) * 35;

            return Stack(
              children: [
                Positioned(
                  top: 120 + dy1,
                  left: -80 + dx1,
                  child: _Orb(
                    size: 320,
                    colors: [
                      const Color(0xFF7B61FF).withValues(alpha: 0.25),
                      const Color(0xFF7B61FF).withValues(alpha: 0.05),
                    ],
                  ),
                ),
                Positioned(
                  top: -160 + dy2,
                  right: -140 + dx2,
                  child: _Orb(
                    size: 380,
                    colors: [
                      const Color(0xFF22D3EE).withValues(alpha: 0.18),
                      const Color(0xFF22D3EE).withValues(alpha: 0.04),
                    ],
                  ),
                ),
                Positioned(
                  bottom: -200 + dy3,
                  left: 40 + dx3,
                  child: _Orb(
                    size: 420,
                    colors: [
                      const Color(0xFFA78BFA).withValues(alpha: 0.16),
                      const Color(0xFFA78BFA).withValues(alpha: 0.03),
                    ],
                  ),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ],
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
        ),
      ),
    );
  }
}
