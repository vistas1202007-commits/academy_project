import 'package:flutter/material.dart';

/// Isse chaudi window = desktop (sidebar wala layout), kam = phone layout
const double kDesktopMinWidth = 900;

/// [AppShell] apne LayoutBuilder se tay karta hai ki window desktop hai ya
/// nahi, aur ye scope neeche har screen tak pahunchata hai.
class DesktopScope extends InheritedWidget {
  final bool isDesktop;
  const DesktopScope({super.key, required this.isDesktop, required super.child});

  /// LayoutBuilder ki constraints se faisla (MediaQuery ki size se nahi)
  static bool fromConstraints(BoxConstraints constraints) => constraints.maxWidth > kDesktopMinWidth;

  @override
  bool updateShouldNotify(DesktopScope oldWidget) => oldWidget.isDesktop != isDesktop;
}

/// Desktop layout chal raha hai ya nahi (phone par false)
bool isDesktop(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DesktopScope>()?.isDesktop ?? false;

/// Body ko [maxWidth] tak rokta hai aur beech me rakhta hai. Phone par
/// width kam hoti hai, isliye wahan koi farak nahi padta.
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
        child: child,
      ),
    );
  }
}
