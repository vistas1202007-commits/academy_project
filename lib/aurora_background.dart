import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Night sky for the open and login screens: stars, slowly moving aurora
/// waves and mountains below. Only the aurora layer repaints every frame;
/// sky and mountains are drawn once in separate RepaintBoundaries.
/// No Blur/MaskFilter, so it stays smooth on web and older phones.
class AuroraBackground extends StatefulWidget {
  /// Large snowy mountain in the middle (open screen). Login shows only the
  /// soft low hills.
  final bool showPeak;

  /// Where the big mountain's peak sits as a fraction of screen height (0 = top)
  final double peakTop;

  final Widget? child;

  const AuroraBackground({
    super.key,
    this.showPeak = false,
    this.peakTop = 0.42,
    this.child,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Aurora stays still when "Reduce motion" is on
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.night,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: CustomPaint(painter: _SkyPainter())),
          RepaintBoundary(child: CustomPaint(painter: _AuroraPainter(_controller))),
          RepaintBoundary(
            child: CustomPaint(
              painter: _MountainPainter(showPeak: widget.showPeak, peakTop: widget.peakTop),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

/// Sky gradient and a few stars
class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  // Positions as fractions, so the spread looks the same at any size
  static const List<Offset> _stars = [
    Offset(0.12, 0.06), Offset(0.31, 0.15), Offset(0.58, 0.04), Offset(0.83, 0.11),
    Offset(0.93, 0.27), Offset(0.07, 0.31), Offset(0.46, 0.24), Offset(0.71, 0.33),
    Offset(0.22, 0.40), Offset(0.88, 0.45), Offset(0.38, 0.08), Offset(0.66, 0.19),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.night, Color(0xFF0A2630), Color(0xFF0B2D35)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    final star = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < _stars.length; i++) {
      final p = _stars[i];
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), i.isEven ? 1.3 : 0.9, star);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => false;
}

/// One aurora wave: the top edge is built from sine waves, the bottom fades
/// out gradually with a gradient
class _Band {
  final double top; // fraction of height
  final double thickness; // fraction of height
  final double amplitude; // fraction of height
  final double waves; // number of waves across the full width
  final double phase;
  final int speed; // cycles per loop (integer, so the loop is seamless)
  final Color color;
  final double alpha;

  const _Band(this.top, this.thickness, this.amplitude, this.waves, this.phase, this.speed, this.color, this.alpha);
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> animation;

  _AuroraPainter(this.animation) : super(repaint: animation);

  static const List<_Band> _bands = [
    _Band(0.10, 0.20, 0.045, 1.1, 0.0, 1, AppColors.teal, 0.55),
    _Band(0.17, 0.18, 0.055, 0.8, 2.1, -1, AppColors.aurora, 0.52),
    _Band(0.25, 0.20, 0.040, 1.4, 4.0, 2, Color(0xFF1F7F86), 0.58),
    _Band(0.33, 0.16, 0.035, 1.0, 1.2, -1, AppColors.aurora, 0.30),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = animation.value * 2 * math.pi;
    // Don't stretch the waves too much on very wide screens
    final waveScale = (w / 420).clamp(1.0, 3.0);
    final step = math.max(6.0, w / 90);

    for (final band in _bands) {
      final top = band.top * h;
      final amp = band.amplitude * h;
      final k = band.waves * waveScale * 2 * math.pi / w;
      final shift = band.phase + t * band.speed;

      double edge(double x) =>
          top + amp * math.sin(k * x + shift) + amp * 0.35 * math.sin(k * 2.3 * x - shift * 0.5);

      final path = Path()..moveTo(0, edge(0));
      for (double x = step; x < w + step; x += step) {
        path.lineTo(x, edge(x));
      }
      final bottom = top + amp * 1.4 + band.thickness * h;
      path
        ..lineTo(w, bottom)
        ..lineTo(0, bottom)
        ..close();

      final bandRect = Rect.fromLTRB(0, top - amp * 1.4, w, bottom);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              band.color.withValues(alpha: band.alpha),
              band.color.withValues(alpha: band.alpha * 0.45),
              band.color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(bandRect),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => oldDelegate.animation != animation;
}

class _MountainPainter extends CustomPainter {
  final bool showPeak;
  final double peakTop;

  const _MountainPainter({required this.showPeak, required this.peakTop});

  static const Color _backRidge = Color(0xFF0D3139);
  static const Color _peakBody = Color(0xFF0C2A31);
  static const Color _frontRidge = Color(0xFF071A20);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back hills, full width
    canvas.drawPath(
      _ridge(size, const [
        Offset(0, 0.70), Offset(0.14, 0.60), Offset(0.27, 0.67), Offset(0.42, 0.58),
        Offset(0.58, 0.66), Offset(0.74, 0.57), Offset(0.88, 0.64), Offset(1, 0.59),
      ]),
      Paint()..color = _backRidge,
    );

    if (showPeak) {
      final apex = Offset(w / 2, peakTop * h);
      // Slope is based on height, so mountains don't spread out on wide screens
      final halfBase = (h - apex.dy) * 0.95;
      paintSnowPeak(canvas, apex, halfBase, h, Paint()..color = _peakBody);
    }

    // Darkest front hills
    canvas.drawPath(
      _ridge(size, const [
        Offset(0, 0.86), Offset(0.2, 0.79), Offset(0.4, 0.88), Offset(0.62, 0.80),
        Offset(0.8, 0.87), Offset(1, 0.81),
      ]),
      Paint()..color = _frontRidge,
    );
  }

  static Path _ridge(Size size, List<Offset> points) {
    final path = Path()..moveTo(0, size.height);
    for (final p in points) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    return path
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldRepaint(_MountainPainter oldDelegate) =>
      oldDelegate.showPeak != showPeak || oldDelegate.peakTop != peakTop;
}

/// A mountain with a snowy peak. [apex] is the peak, [halfBase] half the base
/// width, [baseY] the mountain's bottom edge.
void paintSnowPeak(Canvas canvas, Offset apex, double halfBase, double baseY, Paint body) {
  final height = baseY - apex.dy;
  final slope = halfBase / height;

  canvas.drawPath(
    Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(apex.dx + halfBase, baseY)
      ..lineTo(apex.dx - halfBase, baseY)
      ..close(),
    body,
  );

  // Snow: from the peak downward, with a zig-zag edge
  final capH = height * 0.2;
  final capW = capH * slope;
  canvas.drawPath(
    Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(apex.dx + capW, apex.dy + capH)
      ..lineTo(apex.dx + capW * 0.45, apex.dy + capH * 0.78)
      ..lineTo(apex.dx, apex.dy + capH * 1.08)
      ..lineTo(apex.dx - capW * 0.45, apex.dy + capH * 0.78)
      ..lineTo(apex.dx - capW, apex.dy + capH)
      ..close(),
    Paint()..color = const Color(0xFFD4EEE6),
  );
}
