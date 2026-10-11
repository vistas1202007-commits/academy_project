import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared widgets for inner screens: soft aurora wash, app bar ribbon,
/// section heading, card, empty state, loader and a one-time entrance.
/// No animation loops; animations are skipped when "Reduce motion" is on.

bool _reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Soft aurora wash above the content (washTop to appBackground)
class PageWash extends StatelessWidget {
  final Widget child;

  /// How tall the wash is
  final double height;

  const PageWash({super.key, required this.child, this.height = 260});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.washTop, AppColors.appBackground],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A faint aurora wave on the right. Used in both the app bar and welcome card.
class AuroraRibbonPainter extends CustomPainter {
  /// 0-1, how visible the ribbon is
  final double opacity;
  const AuroraRibbonPainter({this.opacity = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Only the right ~45%
    final left = w * 0.55;
    final band = Path()
      ..moveTo(left, h * 0.95)
      ..cubicTo(left + (w - left) * 0.35, h * 0.35, left + (w - left) * 0.65, h * 1.05, w, h * 0.15)
      ..lineTo(w, h * 0.55)
      ..cubicTo(left + (w - left) * 0.7, h * 1.25, left + (w - left) * 0.4, h * 0.6, left, h * 1.2)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.aurora.withValues(alpha: 0),
          AppColors.ribbon.withValues(alpha: AppColors.ribbon.a * opacity),
          AppColors.teal.withValues(alpha: 0.10 * opacity),
        ],
        stops: const [0, 0.6, 1],
      ).createShader(Rect.fromLTWH(left, 0, w - left, h));
    canvas.drawPath(band, paint);
  }

  @override
  bool shouldRepaint(AuroraRibbonPainter oldDelegate) => oldDelegate.opacity != opacity;
}

/// AppBar flexibleSpace: a very faint static ribbon on appPrimary
class AppBarRibbon extends StatelessWidget {
  const AppBarRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: AuroraRibbonPainter(opacity: 0.8), size: Size.infinite),
    );
  }
}

/// Headings like "Overview", "Quick Actions", with a small aurora bar in front
class SectionHeading extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;
  const SectionHeading(this.text, {super.key, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.aurora, AppColors.appAccent],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// One style for all list/stat cards: white, radius 12, 0.5px border, soft shadow
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin, this.onTap});

  static const BorderRadius radius = BorderRadius.all(Radius.circular(12));

  static BoxDecoration get decoration => BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(color: AppColors.appPrimary.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Empty list: icon, one line, and an optional button
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({super.key, required this.icon, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.mintChipStart, AppColors.mintChipEnd]),
              ),
              child: Icon(icon, size: 32, color: AppColors.appPrimary),
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.appPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One loader for all screens
class AppLoader extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  const AppLoader({super.key, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(color: AppColors.appPrimary, strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// One-time entrance: fade + slight upward slide, staggered by [index] * 50ms.
/// Doesn't replay on rebuild.
class Entrance extends StatefulWidget {
  final int index;
  final Widget child;
  const Entrance({super.key, this.index = 0, required this.child});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Counts up values like "42" or "86%" over 600ms.
/// Text values like "--" or "Not marked yet" are shown as is.
class CountUpText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  const CountUpText(this.value, {super.key, this.style});

  static final RegExp _number = RegExp(r'^(\d+)(\D*)$');

  @override
  Widget build(BuildContext context) {
    final m = _number.firstMatch(value);
    if (m == null || _reduceMotion(context)) return Text(value, style: style);
    final target = int.parse(m.group(1)!);
    final suffix = m.group(2)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}
