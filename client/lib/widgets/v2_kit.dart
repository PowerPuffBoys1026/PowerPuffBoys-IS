import 'package:flutter/material.dart';

import '../theme.dart';

EdgeInsets v2PagePadding(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width > 768;
  return wide
      ? const EdgeInsets.fromLTRB(30, 26, 30, 52)
      : const EdgeInsets.fromLTRB(14, 18, 14, 96);
}

Widget v2Centered(Widget child, {double maxWidth = 1480}) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.borderColor,
    this.background,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? background;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(10);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background ?? colors.card,
          borderRadius: radius,
          border: Border.all(color: borderColor ?? colors.border),
          boxShadow: colors.isDark
              ? const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x0D1B2B26),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: colors.primary.withValues(alpha: 0.1),
              highlightColor: colors.primary.withValues(alpha: 0.05),
              child: Container(
                decoration: accent == null
                    ? null
                    : BoxDecoration(
                        border: Border(
                          left: BorderSide(color: accent!, width: 3),
                        ),
                      ),
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class V2Badge extends StatelessWidget {
  const V2Badge(
    this.label, {
    super.key,
    this.color,
    this.background,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final Color? background;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = color ?? colors.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: background ?? fg.withValues(alpha: colors.isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: dense ? 9.5 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: dense ? 0.5 : 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.selected = false,
    this.tone,
    this.dense = false,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool selected;
  final Color? tone;
  final bool dense;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = tone ?? colors.textMain;
    final active = selected;
    return Material(
      color: active
          ? accent.withValues(alpha: colors.isDark ? 0.18 : 0.1)
          : colors.card,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: expand ? double.infinity : null,
          constraints: BoxConstraints(minHeight: dense ? 32 : 40),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 13,
            vertical: dense ? 6 : 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? accent.withValues(alpha: 0.55) : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: dense ? 14 : 16,
                  color: active ? accent : colors.textMuted,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: dense ? 11 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? accent : colors.textMain,
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

class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.compact = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: compact ? 34 : 38,
          height: compact ? 34 : 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.border),
          ),
          child: Icon(
            icon,
            size: compact ? 18 : 20,
            color: color ?? colors.textMuted,
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 38,
    this.radius = 8,
    this.showText = false,
  });

  final double size;
  final double radius;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB3263B), Color(0xFF761527)],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'C',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.55,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
    if (!showText) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ClassMate',
              style: TextStyle(
                color: colors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.15,
              ),
            ),
            Text(
              'STUDENT SUITE 2.0',
              style: TextStyle(
                color: colors.primary,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                height: 1.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: colors.isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tone, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMain,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(color: colors.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.tag,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String tag;
  final String title;
  final String subtitle;
  final Widget? trailing;

  static const _photo =
      'https://images.unsplash.com/photo-1507842217343-583bb7270b66?auto=format&fit=crop&w=1800&q=85';

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 768;
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 265 : 284),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        color: const Color(0xFF34171D),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331A080C),
            blurRadius: 34,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                _photo,
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.05),
                errorBuilder: (_, _, _) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF241417), Color(0xFF4B121D)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xE80E1112),
                      const Color(0xC7211316),
                      const Color(0x6E4B121D),
                    ],
                    stops: const [0, 0.52, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 22,
              bottom: -26,
              child: Text(
                '01',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: compact ? 150 : 230,
                  height: 0.9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.11),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 34,
                compact ? 24 : 32,
                compact ? 18 : 34,
                compact ? 20 : 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      tag.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'serif',
                        color: Colors.white,
                        fontSize: compact ? 30 : 40,
                        fontWeight: FontWeight.w500,
                        height: 1.08,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                        height: 1.55,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 14),
                    trailing!,
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: const Color(0xFFD45A68)),
            ),
          ],
        ),
      ),
    );
  }
}

class V2ProgressBar extends StatelessWidget {
  const V2ProgressBar({
    super.key,
    required this.value,
    this.height = 7,
    this.color,
    this.track,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: track ?? colors.border.withValues(alpha: 0.6),
        valueColor: AlwaysStoppedAnimation(color ?? colors.primary),
      ),
    );
  }
}

class V2Empty extends StatelessWidget {
  const V2Empty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      child: Column(
        children: [
          Icon(icon, size: 30, color: colors.textDim),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textMain,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

Future<T?> showV2Sheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(child: builder(context)),
      ),
    ),
  );
}

class V2SheetHeader extends StatelessWidget {
  const V2SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
