import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Open screen aur login ka raat wala aasmaan: tare, dheere hilti aurora ki
/// lehrein aur neeche pahaad. Sirf aurora wali layer har frame repaint hoti
/// hai; aasmaan aur pahaad alag RepaintBoundary me ek hi baar bante hain.
/// Blur/MaskFilter use nahi hota, taaki web aur purane phone dono par smooth rahe.
class AuroraBackground extends StatefulWidget {
  /// Bada barfeela pahaad beech me (open screen). Login par sirf neeche ki
  /// halki pahadiyan aati hain.
  final bool showPeak;

  /// Bade pahaad ki choti screen height ke kis hisse par ho (0 = upar)
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
    // "Reduce motion" on ho to aurora ruki rehti hai
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

/// Aasmaan ka gradient aur kuch tare
class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  // Fraction me positions, har size par ek jaisa phailav
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

/// Ek aurora lehar: upar ki kinaari sine waves se banti hai, neeche gradient
/// se dheere gayab hoti hai
class _Band {
  final double top; // height ka fraction
  final double thickness; // height ka fraction
  final double amplitude; // height ka fraction
  final double waves; // poori width me kitni lehrein
  final double phase;
  final int speed; // ek loop me kitne chakkar (integer, taaki loop seamless rahe)
  final Color color;
  final double alpha;

  const _Band(this.top, this.thickness, this.amplitude, this.waves, this.phase, this.speed, this.color, this.alpha);
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> animation;

  _AuroraPainter(this.animation) : super(repaint: animation);

  static const List<_Band> _bands = [
    _Band(0.10, 0.20, 0.045, 1.1, 0.0, 1, AppColors.teal, 0.40),
    _Band(0.17, 0.18, 0.055, 0.8, 2.1, -1, AppColors.aurora, 0.32),
    _Band(0.25, 0.20, 0.040, 1.4, 4.0, 2, Color(0xFF1F7F86), 0.45),
    _Band(0.33, 0.16, 0.035, 1.0, 1.2, -1, AppColors.aurora, 0.16),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = animation.value * 2 * math.pi;
    // Bahut chaudi screen par lehrein zyada na khinchein
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
              band.color.withValues(alpha: band.alpha * 0.35),
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

    // Peeche ki pahadiyan, poori width me
    canvas.drawPath(
      _ridge(size, const [
        Offset(0, 0.70), Offset(0.14, 0.60), Offset(0.27, 0.67), Offset(0.42, 0.58),
        Offset(0.58, 0.66), Offset(0.74, 0.57), Offset(0.88, 0.64), Offset(1, 0.59),
      ]),
      Paint()..color = _backRidge,
    );

    if (showPeak) {
      final apex = Offset(w / 2, peakTop * h);
      // Dhalaan height se tay hoti hai, taaki chaudi screen par pahaad na phaile
      final halfBase = (h - apex.dy) * 0.95;
      paintSnowPeak(canvas, apex, halfBase, h, Paint()..color = _peakBody);
    }

    // Aage ki sabse gehri pahadiyan
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

/// Ek pahaad jiski choti par barf ho. [apex] choti, [halfBase] neeche aadhi
/// chaudai, [baseY] pahaad ka neeche ka kinara.
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

  // Barf: choti se neeche tak, zig-zag kinaare ke saath
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

/// Login ke upar wala chhota barfeela pahaad (logo jaisa)
class SnowPeakMark extends StatelessWidget {
  final double width;
  const SnowPeakMark({super.key, this.width = 150});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.42,
      child: const CustomPaint(painter: _SnowPeakMarkPainter()),
    );
  }
}

class _SnowPeakMarkPainter extends CustomPainter {
  const _SnowPeakMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Neeche se aasmaan me ghul jata hai, koi seedhi kinaari nahi dikhti
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF15434C), const Color(0xFF15434C).withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    paintSnowPeak(canvas, Offset(size.width / 2, 0), size.width / 2, size.height, body);
  }

  @override
  bool shouldRepaint(_SnowPeakMarkPainter oldDelegate) => false;
}
