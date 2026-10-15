import 'package:flutter/material.dart';

/// Windows wider than this = desktop (sidebar layout), narrower = phone layout
const double kDesktopMinWidth = 900;

/// [AppShell] uses its LayoutBuilder to decide whether the window is desktop,
/// and this scope passes that down to every screen.
class DesktopScope extends InheritedWidget {
  final bool isDesktop;
  const DesktopScope({super.key, required this.isDesktop, required super.child});

  /// Decided from LayoutBuilder constraints (not MediaQuery size)
  static bool fromConstraints(BoxConstraints constraints) => constraints.maxWidth > kDesktopMinWidth;

  @override
  bool updateShouldNotify(DesktopScope oldWidget) => oldWidget.isDesktop != isDesktop;
}

/// Whether the desktop layout is active (false on phone)
bool isDesktop(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DesktopScope>()?.isDesktop ?? false;

/// Caps the body at [maxWidth] and centers it. Phones are narrower,
/// so it makes no difference there.
class ContentWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const ContentWidth({super.key, required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        // Full width (up to maxWidth), so phone alignment stays as before
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
