import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routing/routes.dart';
import '../models/custom_inbox.dart';

/// Main application shell with persistent sidebar navigation.
/// The sidebar stays constant while content changes based on navigation.
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
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

  void _onLogout() {
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Persistent Sidebar - permanently open
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                // Header / Logo
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mail, color: Colors.indigo, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'SharedBox',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.indigo,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                
                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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

                        const SizedBox(height: 16),
                        
                        // Custom Inboxes Section
                        if (_companyId != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'INBOXES',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => context.go(AppRoutes.customInboxes),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.add,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<List<CustomInbox>>(
                            stream: CustomInboxService.getInboxes(_companyId!),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Text(
                                    'No custom inboxes',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                );
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

                        const SizedBox(height: 16),

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
                          label: 'Manage Inboxes',
                          route: AppRoutes.customInboxes,
                          isSelected: currentLocation == AppRoutes.customInboxes,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer / Logout
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: _buildNavItem(
                    context,
                    icon: Icons.logout,
                    selectedIcon: Icons.logout,
                    label: 'Logout',
                    isDestructive: true,
                    onTap: _onLogout,
                  ),
                ),
              ],
            ),
          ),

          // Main Content Area (changes with navigation)
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 10,
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected && !isDestructive ? Colors.indigo.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              iconData,
              color: iconColor ?? color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 12,
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
