import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'aurora_background.dart';
import 'brand.dart';
import 'app_shell.dart';

/// Screen shown while the app opens (during login check and profile load):
/// aurora, snowy mountain and the Vistas wordmark.
class OpenScreen extends StatelessWidget {
  const OpenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FullBleed(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.night,
          body: AuroraBackground(
            showPeak: true,
            peakTop: 0.40,
            child: Stack(
              children: [
                // Centered on the mountain, below the peak
                Align(
                  alignment: const Alignment(0, 0.36),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(offset: Offset(0, 8 * (1 - value)), child: child),
                    ),
                    // Wordmark sized from its own slot's width, not the full screen size
                    child: LayoutBuilder(
                      builder: (context, constraints) => Semantics(
                        label: BrandAssets.appName,
                        child: Image.asset(
                          BrandAssets.wordmarkLight,
                          width: math.min(constraints.maxWidth * 0.62, 340.0),
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                ),
                // Subtle loading hint
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 36 + MediaQuery.paddingOf(context).bottom,
                  child: Center(
                    child: SizedBox(
                      width: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          color: AppColors.aurora,
                          backgroundColor: AppColors.aurora.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
