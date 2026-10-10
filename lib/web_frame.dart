import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'app_colors.dart';

/// Kitni [FullBleed] screens abhi tree me hain. 0 se zyada ho to [WebFrame]
/// poori width de deta hai.
final ValueNotifier<int> _fullBleedCount = ValueNotifier<int>(0);

/// Is widget ke andar wali screen (open screen, login) web par bhi poori
/// browser width leti hai; [WebFrame] ka 720 wala frame tab tak band rehta hai.
class FullBleed extends StatefulWidget {
  final Widget child;
  const FullBleed({super.key, required this.child});

  @override
  State<FullBleed> createState() => _FullBleedState();
}

class _FullBleedState extends State<FullBleed> {
  @override
  void initState() {
    super.initState();
    _fullBleedCount.value++;
  }

  @override
  void dispose() {
    _fullBleedCount.value--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Chaudi screen (web/desktop) par app ko beech me 720 width ke frame me
/// rakhta hai; bahar night background. 720 ya kam width par koi farak nahi.
/// Widget tree hamesha ek jaisa rehta hai, taaki window resize par
/// Navigator ka state na khoye — sirf width/decoration/MediaQuery data badalte hain.
/// [FullBleed] screen aane/jaane par frame dheere khulta/simatta hai.
class WebFrame extends StatefulWidget {
  final Widget child;
  const WebFrame({super.key, required this.child});

  static const double maxWidth = 720;

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> with SingleTickerProviderStateMixin {
  /// 0 = 720 ka frame, 1 = poori width
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: _fullBleedCount.value > 0 ? 1 : 0,
  );
  bool _settled = false;

  static final BoxDecoration _frameDecoration = BoxDecoration(
    color: AppColors.appBackground,
    border: Border.symmetric(
      vertical: BorderSide(color: AppColors.teal.withValues(alpha: 0.25)),
    ),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 32),
    ],
  );

  @override
  void initState() {
    super.initState();
    _fullBleedCount.addListener(_onFullBleedChanged);
  }

  // FullBleed build/dispose ke beech count badalta hai; tree locked hota hai,
  // isliye frame ke baad animate karte hain
  void _onFullBleedChanged() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _fullBleedCount.value > 0 ? 1.0 : 0.0;
      if (!_settled) {
        // App khulte hi pehli screen par animation nahi
        _settled = true;
        _open.value = target;
      } else {
        _open.animateTo(target, curve: Curves.easeInOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _fullBleedCount.removeListener(_onFullBleedChanged);
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final wide = available > WebFrame.maxWidth;
        final mediaQuery = MediaQuery.of(context);
        return AnimatedBuilder(
          animation: _open,
          child: widget.child,
          builder: (context, child) {
            final width = wide
                ? WebFrame.maxWidth + (available - WebFrame.maxWidth) * _open.value
                : available;
            final framed = wide && _open.value < 1;
            return ColoredBox(
              color: wide ? AppColors.night : Colors.transparent,
              child: Center(
                child: SizedBox(
                  width: width,
                  child: DecoratedBox(
                    decoration: framed ? _frameDecoration : const BoxDecoration(),
                    child: ClipRect(
                      // Frame ke andar ke widgets (date picker, dialogs) ko bhi
                      // frame ki width dikhe; phone par data waisa hi rehta hai
                      child: MediaQuery(
                        data: wide ? mediaQuery.copyWith(size: Size(width, mediaQuery.size.height)) : mediaQuery,
                        child: child!,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
