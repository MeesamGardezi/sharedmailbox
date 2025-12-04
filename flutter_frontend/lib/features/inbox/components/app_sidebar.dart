import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routes.dart';

class AppSidebar extends StatefulWidget {
  final VoidCallback onLogout;

  const AppSidebar({
    super.key,
    required this.onLogout,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).matchedLocation;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: _isHovered ? 200 : 72,
        color: Colors.white,
        child: Column(
          children: [
            // Header / Logo
            SizedBox(
              height: 64,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.mail, color: Colors.indigo, size: 32),
                      if (_isHovered) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Mailbox',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // Navigation Items
            _buildNavItem(
              context,
              icon: Icons.inbox_outlined,
              selectedIcon: Icons.inbox,
              label: 'Inbox',
              route: AppRoutes.home,
              isSelected: currentLocation == AppRoutes.home || currentLocation == AppRoutes.inbox,
            ),
            _buildNavItem(
              context,
              icon: Icons.manage_accounts_outlined,
              selectedIcon: Icons.manage_accounts,
              label: 'Accounts',
              route: AppRoutes.accounts,
              isSelected: currentLocation == AppRoutes.accounts,
            ),
            _buildNavItem(
              context,
              icon: Icons.calendar_today_outlined,
              selectedIcon: Icons.calendar_today,
              label: 'Calendar',
              route: AppRoutes.calendar,
              isSelected: currentLocation == AppRoutes.calendar,
            ),
            _buildNavItem(
              context,
              icon: Icons.people_outline,
              selectedIcon: Icons.people,
              label: 'Team',
              route: AppRoutes.team,
              isSelected: currentLocation == AppRoutes.team,
            ),
            
            const Spacer(),
            const Divider(height: 1),
            
            // Logout
            _buildNavItem(
              context,
              icon: Icons.logout,
              selectedIcon: Icons.logout,
              label: 'Logout',
              isDestructive: true,
              onTap: widget.onLogout,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    String? route,
    bool isSelected = false,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final color = isDestructive
        ? Colors.red
        : isSelected
            ? Colors.indigo
            : Colors.grey.shade700;
    
    final iconData = isSelected ? selectedIcon : icon;

    return InkWell(
      onTap: onTap ?? (route != null ? () => context.go(route) : null),
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected && !isDestructive ? Colors.indigo.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Center(
                child: Icon(
                  iconData,
                  color: color,
                  size: 24,
                ),
              ),
            ),
            if (_isHovered)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
