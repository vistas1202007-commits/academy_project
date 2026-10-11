import 'package:flutter/material.dart';

/// Vistas branding images. The wordmark is never built with a Text widget;
/// it always comes from these images.
class BrandAssets {
  BrandAssets._();

  static const String logoCircle = 'assets/branding/vistas_logo_circle.png';
  static const String markCircle = 'assets/branding/vistas_mark_circle.png';
  static const String mountainGlyph = 'assets/branding/vistas_mountain_glyph.png';

  /// For dark backgrounds (app bar, aurora)
  static const String wordmarkLight = 'assets/branding/vistas_wordmark_light.png';

  /// For light backgrounds (About, lock screen)
  static const String wordmarkDark = 'assets/branding/vistas_wordmark_dark.png';

  static const String appName = 'Vistas';
  static const String tagline = 'Skill Training ERP';
}

/// For the dark app bar: mountain glyph + small light wordmark
class VistasAppBarTitle extends StatelessWidget {
  const VistasAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: BrandAssets.appName,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(BrandAssets.mountainGlyph, height: 18, filterQuality: FilterQuality.medium),
          const SizedBox(width: 10),
          Image.asset(BrandAssets.wordmarkLight, height: 26, filterQuality: FilterQuality.medium),
        ],
      ),
    );
  }
}
