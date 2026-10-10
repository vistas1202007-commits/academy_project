import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'app_lock.dart';
import 'app_sidebar.dart';
import 'nav_items.dart';
import 'responsive.dart';

/// Build ya tree finalize ke beech kisi aur widget ka state nahi badal sakte,
/// isliye us waqt kaam frame khatam hone tak tal dete hain.
void _whenSafe(VoidCallback fn) {
  final phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
    fn();
  } else {
    SchedulerBinding.instance.addPostFrameCallback((_) => fn());
  }
}

/// Kitni [FullBleed] screens abhi tree me hain
final ValueNotifier<int> _fullBleedCount = ValueNotifier<int>(0);

class _ShellUserInfo {
  final String name;
  final String role;
  const _ShellUserInfo(this.name, this.role);
}

/// Logged-in user, jab tak Dashboard tree me hai
final ValueNotifier<_ShellUserInfo?> _shellUser = ValueNotifier<_ShellUserInfo?>(null);

/// Is widget ke andar wali screen (open screen, login) desktop par bhi
/// poori width leti hai; jab tak ye tree me hai, sidebar nahi dikhta.
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
    _whenSafe(() => _fullBleedCount.value++);
  }

  @override
  void dispose() {
    _whenSafe(() => _fullBleedCount.value--);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Dashboard isse lapet ke sidebar ko user ka naam aur role batata hai
class ShellUser extends StatefulWidget {
  final String name;
  final String role;
  final Widget child;
  const ShellUser({super.key, required this.name, required this.role, required this.child});

  @override
  State<ShellUser> createState() => _ShellUserState();
}

class _ShellUserState extends State<ShellUser> {
  late _ShellUserInfo _info = _ShellUserInfo(widget.name, widget.role);

  @override
  void initState() {
    super.initState();
    final info = _info;
    _whenSafe(() => _shellUser.value = info);
  }

  @override
  void didUpdateWidget(ShellUser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name || oldWidget.role != widget.role) {
      final info = _info = _ShellUserInfo(widget.name, widget.role);
      _whenSafe(() => _shellUser.value = info);
    }
  }

  @override
  void dispose() {
    final info = _info;
    // Naya dashboard pehle hi aa chuka ho to use na mitaayein
    _whenSafe(() {
      if (identical(_shellUser.value, info)) _shellUser.value = null;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// App navigator ke routes dekhta hai aur batata hai ki sidebar me kaunsa
/// item highlight ho: stack me sabse upar wala menu route, warna Dashboard.
class ShellRouteObserver extends NavigatorObserver {
  final ValueNotifier<String> current = ValueNotifier<String>(NavIds.dashboard);
  final List<Route<dynamic>> _stack = [];

  /// Sabse upar wale route ka menu id (menu se na khula ho to null)
  String? get topId => _stack.isEmpty ? null : _navId(_stack.last);

  static String? _navId(Route<dynamic> route) {
    final name = route.settings.name;
    return NavIds.all.contains(name) ? name : null;
  }

  void _update() {
    var id = NavIds.dashboard;
    for (final route in _stack.reversed) {
      final navId = _navId(route);
      if (navId != null) {
        id = navId;
        break;
      }
    }
    _whenSafe(() => current.value = id);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (newRoute != null) {
      if (index >= 0) {
        _stack[index] = newRoute;
      } else {
        _stack.add(newRoute);
      }
    } else if (index >= 0) {
      _stack.removeAt(index);
    }
    _update();
  }
}

final ShellRouteObserver shellRouteObserver = ShellRouteObserver();

/// Menu item kholta hai: pehle Dashboard tak wapas, phir naya screen
void openNavItem(NavItem item) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null || shellRouteObserver.topId == item.id) return;
  navigator.popUntil((route) => route.isFirst);
  if (item.builder != null) navigator.push(item.route());
}

/// Poore app ka dhaancha. Desktop par (900 se chaudi window) baayin taraf
/// sidebar aur baaki jagah navigator; phone par sirf navigator, jaisa pehle.
/// Navigator hamesha Row ke doosre bachche ki jagah rehta hai, taaki resize
/// ya sidebar aane-jaane par uska state na khoye. Dialog bhi navigator ke
/// overlay me khulte hain, isliye content area ke andar hi rehte hain.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const double sidebarWidth = 260;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = DesktopScope.fromConstraints(constraints);
        final mediaQuery = MediaQuery.of(context);
        return DesktopScope(
          isDesktop: desktop,
          child: ListenableBuilder(
            listenable: Listenable.merge([_fullBleedCount, _shellUser]),
            child: child,
            builder: (context, child) {
              final user = _shellUser.value;
              final showSidebar = desktop && user != null && _fullBleedCount.value == 0;
              final contentWidth = constraints.maxWidth - (showSidebar ? sidebarWidth : 0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: showSidebar ? sidebarWidth : 0,
                    child: showSidebar ? AppSidebar(name: user.name, role: user.role) : null,
                  ),
                  Expanded(
                    // Date picker jaise widgets ko content ki hi width dikhe
                    child: MediaQuery(
                      data: showSidebar
                          ? mediaQuery.copyWith(size: Size(contentWidth, mediaQuery.size.height))
                          : mediaQuery,
                      child: child!,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
