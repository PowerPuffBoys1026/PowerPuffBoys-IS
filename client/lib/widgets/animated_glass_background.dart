import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Ambient background used behind the auth flow and the signed-in shell.
///
/// The v2 dashboard keeps a calm field-journal backdrop, so the orbs are very
/// subtle in dark mode and almost invisible in light mode.
class AnimatedGlassBackground extends StatefulWidget {
  const AnimatedGlassBackground({
    super.key,
    required this.child,
    this.intense = false,
  });

  final Widget child;
  final bool intense;

  @override
  State<AnimatedGlassBackground> createState() =>
      _AnimatedGlassBackgroundState();
}

class _AnimatedGlassBackgroundState extends State<AnimatedGlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strength = widget.intense ? 1.0 : 0.45;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.bgPrimary,
                  colors.bgSecondary,
                  colors.bgPrimary,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final dx = math.sin(t * math.pi) * 50;
                final dy = math.cos(t * math.pi) * 40;
                return Stack(
                  children: [
                    Positioned(
                      top: 90 + dy,
                      left: -100 + dx,
                      child: _Orb(
                        size: 420,
                        color: colors.primary.withValues(
                          alpha: 0.16 * strength,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -180 - dy,
                      right: -120 - dx,
                      child: _Orb(
                        size: 440,
                        color: colors.emerald.withValues(alpha: 0.1 * strength),
                      ),
                    ),
                    Positioned(
                      bottom: -220 + dx,
                      left: 40 + dy,
                      child: _Orb(
                        size: 460,
                        color: colors.violet.withValues(alpha: 0.13 * strength),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
