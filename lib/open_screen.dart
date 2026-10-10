import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'aurora_background.dart';
import 'brand.dart';
import 'web_frame.dart';

/// App khulte waqt (login check aur profile load tak) dikhne wali screen:
/// aurora, barfeela pahaad aur Vistas wordmark.
class OpenScreen extends StatelessWidget {
  const OpenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wordmarkWidth = math.min(size.width * 0.62, 340.0);

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
                // Pahaad ke beech, choti se neeche
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
                    child: Semantics(
                      label: BrandAssets.appName,
                      child: Image.asset(
                        BrandAssets.wordmarkLight,
                        width: wordmarkWidth,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
                // Load hone ka halka sa ishaara
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
