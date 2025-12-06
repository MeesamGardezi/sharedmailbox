import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/routing/routes.dart';
import '../../../core/models/custom_inbox.dart';

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
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _fetchCompanyId();
  }

  Future<void> _fetchCompanyId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _companyId = doc.data()?['companyId'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching company ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).matchedLocation;
    
    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        children: [
          // Header / Logo
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail, color: Colors.indigo, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Mailbox',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Navigation
                  _buildSectionHeader('MAIN'),
                  _buildNavItem(
                    context,
                    icon: Icons.inbox_outlined,
                    selectedIcon: Icons.inbox,
                    label: 'All Inboxes',
                    route: AppRoutes.home,
                    isSelected: currentLocation == AppRoutes.home || currentLocation == AppRoutes.inbox,
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

                  const SizedBox(height: 24),
                  
                  // Custom Inboxes
                  if (_companyId != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'INBOXES',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            color: Colors.grey.shade500,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => context.go(AppRoutes.customInboxes),
                            tooltip: 'Manage Inboxes',
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<List<CustomInbox>>(
                      stream: CustomInboxService.getInboxes(_companyId!),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        
                        final inboxes = snapshot.data!;
                        return Column(
                          children: inboxes.map((inbox) {
                            final route = '/custom-inbox/${inbox.id}';
                            return _buildNavItem(
                              context,
                              icon: Icons.folder_outlined,
                              selectedIcon: Icons.folder,
                              label: inbox.name,
                              route: route,
                              isSelected: currentLocation == route,
                              iconColor: Color(inbox.color),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Settings & Tools
                  _buildSectionHeader('SETTINGS'),
                  _buildNavItem(
                    context,
                    icon: Icons.manage_accounts_outlined,
                    selectedIcon: Icons.manage_accounts,
                    label: 'Email Accounts',
                    route: AppRoutes.accounts,
                    isSelected: currentLocation == AppRoutes.accounts,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Custom Inboxes',
                    route: AppRoutes.customInboxes,
                    isSelected: currentLocation == AppRoutes.customInboxes,
                  ),
                ],
              ),
            ),
          ),
          
          // Footer / Logout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: _buildNavItem(
              context,
              icon: Icons.logout,
              selectedIcon: Icons.logout,
              label: 'Logout',
              isDestructive: true,
              onTap: widget.onLogout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
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
    Color? iconColor,
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
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected && !isDestructive ? Colors.indigo.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              iconData,
              color: iconColor ?? color,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
