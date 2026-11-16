import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/theme_state.dart';
import '../theme.dart';
import '../widgets/v2_kit.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String kicker;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  static const _photo =
      'https://images.unsplash.com/photo-1507842217343-583bb7270b66?auto=format&fit=crop&w=1600&q=85';

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 11,
                    child: _Editorial(photo: _photo, compact: false),
                  ),
                  Expanded(
                    flex: 9,
                    child: _FormSide(
                      kicker: kicker,
                      title: title,
                      subtitle: subtitle,
                      footer: footer,
                      child: child,
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 232,
                      child: _Editorial(photo: _photo, compact: true),
                    ),
                    _FormSide(
                      kicker: kicker,
                      title: title,
                      subtitle: subtitle,
                      footer: footer,
                      compact: true,
                      child: child,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Editorial extends StatelessWidget {
  const _Editorial({required this.photo, required this.compact});

  final String photo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: compact
          ? BorderRadius.zero
          : const BorderRadius.only(
              topRight: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            photo,
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.1),
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A1015), Color(0xFF6B1524)],
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xB30E1112),
                  const Color(0x8F211316),
                  const Color(0xE6080B0C),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 20 : 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandMark(size: 36, radius: 7),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ClassMate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          'STUDENT SUITE 2.0',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                if (!compact)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'ACADEMIC & FOCUS SUITE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                if (!compact) const SizedBox(height: 14),
                Text(
                  compact
                      ? 'Make room for what matters.'
                      : 'Your academic life,\nbeautifully organized.',
                  style: TextStyle(
                    fontFamily: 'serif',
                    color: Colors.white,
                    fontSize: compact ? 26 : 42,
                    fontWeight: FontWeight.w500,
                    height: 1.08,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Timetable, attendance, grades, focus sessions, and flashnotes — one calm workspace.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: compact ? 11.5 : 13,
                    height: 1.55,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"Small daily efforts compound into extraordinary results."',
                          style: TextStyle(
                            fontFamily: 'serif',
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'CLASSMATE FIELD NOTES',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSide extends StatelessWidget {
  const _FormSide({
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.compact = false,
  });

  final String kicker;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = context.watch<ThemeState>();
    return Container(
      color: compact ? colors.bgPrimary : Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        compact ? 22 : 46,
        compact ? 24 : 28,
        compact ? 22 : 46,
        compact ? 30 : 36,
      ),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'ClassMate Student Suite',
                      style: TextStyle(
                        color: colors.textDim,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    IconAction(
                      icon: theme.isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      tooltip: theme.isDark
                          ? 'Switch to light theme'
                          : 'Switch to dark theme',
                      compact: true,
                      onPressed: theme.toggle,
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                Text(
                  kicker.toUpperCase(),
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'serif',
                    color: colors.textMain,
                    fontSize: compact ? 30 : 36,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                child,
                if (footer != null) ...[const SizedBox(height: 20), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
