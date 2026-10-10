import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_lock.dart';
import 'app_shell.dart';
import 'brand.dart';
import 'nav_items.dart';

/// Desktop ka hamesha khula menu (phone par iski jagah drawer)
class AppSidebar extends StatelessWidget {
  final String name;
  final String role;
  const AppSidebar({super.key, required this.name, required this.role});

  static const Color _text = Color(0xFFDDF2EE);
  static const Color _muted = Color(0xFF9DBFBB);
  static const Color _logout = Color(0xFFF2B8B0);

  @override
  Widget build(BuildContext context) {
    final items = navItemsFor(role);
    return Material(
      color: AppColors.night,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(BrandAssets.logoCircle, height: 56, width: 56),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.aurora.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      roleLabelFor(role),
                      style: const TextStyle(color: AppColors.aurora, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: shellRouteObserver.current,
                builder: (context, currentId, _) => ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    for (final item in items)
                      _SidebarTile(
                        icon: item.icon,
                        label: item.label,
                        selected: item.id == currentId,
                        onTap: () => openNavItem(item),
                      ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 8),
            _SidebarTile(
              icon: Icons.logout,
              label: 'Logout',
              color: _logout,
              onTap: () {
                // Navigator ke context se, taaki dialog content area me khule
                final navContext = appNavigatorKey.currentContext;
                if (navContext != null) confirmLogout(navContext);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _SidebarTile({required this.icon, required this.label, required this.onTap, this.selected = false, this.color});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (selected ? AppColors.aurora : AppSidebar._text);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.aurora.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color ?? (selected ? AppColors.aurora : AppSidebar._muted)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: fg, fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
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
