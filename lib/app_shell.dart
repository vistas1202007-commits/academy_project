import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'app_lock.dart';
import 'app_sidebar.dart';
import 'nav_items.dart';
import 'responsive.dart';

/// Another widget's state can't change during build or tree finalization,
/// so the work is deferred until the frame ends.
void _whenSafe(VoidCallback fn) {
  final phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
    fn();
  } else {
    SchedulerBinding.instance.addPostFrameCallback((_) => fn());
  }
}

/// How many [FullBleed] screens are currently in the tree
final ValueNotifier<int> _fullBleedCount = ValueNotifier<int>(0);

class _ShellUserInfo {
  final String name;
  final String role;
  const _ShellUserInfo(this.name, this.role);
}

/// Logged-in user, while the Dashboard is in the tree
final ValueNotifier<_ShellUserInfo?> _shellUser = ValueNotifier<_ShellUserInfo?>(null);

/// The screen inside this widget (open screen, login) takes the full width
/// on desktop too; while it is in the tree, the sidebar is hidden.
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

/// The Dashboard wraps itself in this to give the sidebar the user's name and role
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
    // Don't clear it if a new dashboard has already arrived
    _whenSafe(() {
      if (identical(_shellUser.value, info)) _shellUser.value = null;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Watches the app navigator's routes and reports which sidebar item to
/// highlight: the topmost menu route in the stack, else Dashboard.
class ShellRouteObserver extends NavigatorObserver {
  final ValueNotifier<String> current = ValueNotifier<String>(NavIds.dashboard);
  final List<Route<dynamic>> _stack = [];

  /// Menu id of the topmost route (null if it wasn't opened from the menu)
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

/// Opens a menu item: first pops back to the Dashboard, then pushes the new screen
void openNavItem(NavItem item) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null || shellRouteObserver.topId == item.id) return;
  navigator.popUntil((route) => route.isFirst);
  if (item.builder != null) navigator.push(item.route());
}

/// The whole app's frame. On desktop (window wider than 900), sidebar on the
/// left and the navigator in the rest; on phone only the navigator, as before.
/// The navigator always stays in the Row's second child slot, so it keeps its
/// state across resizes or the sidebar showing/hiding. Dialogs also open in the
/// navigator's overlay, so they stay inside the content area.
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
                    // Widgets like the date picker should see only the content width
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
