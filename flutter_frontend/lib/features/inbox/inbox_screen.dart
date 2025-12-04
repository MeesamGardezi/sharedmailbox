import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'inbox_state.dart';
import '../../core/models/email_model.dart';
import '../../core/ui/resizable_shell.dart';
import 'components/app_sidebar.dart';
import 'components/email_renderer/email_renderer.dart';
import '../accounts/accounts_screen.dart';
import '../calendar/calendar_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  int _selectedIndex = 0;
  Email? _selectedEmail;
  bool _isSidebarVisible = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ScrollController _emailListScrollController = ScrollController();


  @override
  void initState() {
    super.initState();
    _emailListScrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_emailListScrollController.position.pixels >= 
        _emailListScrollController.position.maxScrollExtent * 0.8) {
      final state = context.read<InboxState>();
      if (!state.isLoadingMore && !state.isLoading && state.hasMore) {
        state.loadMoreEmails();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _emailListScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InboxState()..fetchEmails(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            AppSidebar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                  _selectedEmail = null;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              onLogout: () => FirebaseAuth.instance.signOut(),
            ),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildInboxView();
      case 1:
        return const AccountsScreen();
      case 2:
        return const CalendarScreen();
      case 3:
        return _buildTeamManagementPlaceholder();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTeamManagementPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Team Management', style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildInboxView() {
    return Consumer<InboxState>(
      builder: (context, state, child) {
        if (state.isLoading && state.emails.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => state.fetchEmails(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final filteredEmails = _searchQuery.isEmpty
            ? state.emails
            : state.emails.where((email) {
                final query = _searchQuery.toLowerCase();
                return email.subject.toLowerCase().contains(query) ||
                    email.from.toLowerCase().contains(query) ||
                    email.text.toLowerCase().contains(query);
              }).toList();

        return ResizableShell(
          isSidebarVisible: _isSidebarVisible,
          initialSidebarWidth: 320,
          minSidebarWidth: 250,
          maxSidebarWidth: 450,
          sidebar: Container(
            color: const Color(0xFFF5F5F5),
            child: Column(
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search mail',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade600),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade600),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F3F4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                
                // Email List
                Expanded(
                  child: filteredEmails.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'No emails' : 'No results',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _emailListScrollController,
                          itemCount: filteredEmails.length + (state.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filteredEmails.length) {
                              return const LinearProgressIndicator(minHeight: 2);
                            }
                            
                            final email = filteredEmails[index];
                            final isSelected = _selectedEmail?.id == email.id;
                            final isRead = email.isRead;
                            
                            return Material(
                              color: isSelected
                                  ? const Color(0xFFD3E3FD)
                                  : (isRead ? Colors.white : const Color(0xFFF2F6FC)),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedEmail = email);
                                  if (!isRead) state.markAsRead(email);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: _getAvatarColor(email.from),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            email.from.isNotEmpty ? email.from[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    email.from,
                                                    style: TextStyle(
                                                      fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                                      fontSize: 13,
                                                      color: const Color(0xFF202124),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _formatDateCompact(email.date),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isRead ? Colors.grey.shade600 : const Color(0xFF202124),
                                                    fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              email.subject,
                                              style: TextStyle(
                                                fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                                fontSize: 13,
                                                color: const Color(0xFF202124),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              email.snippet,
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          body: Container(
            color: Colors.white,
            child: Column(
              children: [
                // Top Toolbar
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isSidebarVisible ? Icons.menu : Icons.menu_open),
                        onPressed: () => setState(() => _isSidebarVisible = !_isSidebarVisible),
                        tooltip: 'Toggle list',
                        iconSize: 20,
                        color: const Color(0xFF5F6368),
                      ),
                      if (_selectedEmail != null) ...[
                        const SizedBox(width: 4),
                        _buildToolbarButton(Icons.archive_outlined, 'Archive', () {}),
                        _buildToolbarButton(Icons.report_gmailerrorred_outlined, 'Report spam', () {}),
                        _buildToolbarButton(Icons.delete_outline, 'Delete', _showDeleteConfirmation),
                        const SizedBox(width: 8),
                        Container(width: 1, height: 24, color: Colors.grey.shade300),
                        const SizedBox(width: 8),
                        _buildToolbarButton(Icons.mail_outline, 'Mark as unread', () {}),
                        _buildToolbarButton(Icons.access_time, 'Snooze', () {}),
                        _buildToolbarButton(Icons.add_task, 'Add to Tasks', () {}),
                        const SizedBox(width: 8),
                        Container(width: 1, height: 24, color: Colors.grey.shade300),
                        const SizedBox(width: 8),
                        _buildToolbarButton(Icons.drive_file_move_outline, 'Move to', () {}),
                        _buildToolbarButton(Icons.label_outline, 'Labels', () {}),
                        _buildToolbarButton(Icons.more_vert, 'More', () {}),
                      ],
                    ],
                  ),
                ),
                
                // Email Content
                Expanded(
                  child: _selectedEmail == null
                      ? _buildEmptyState()
                      : _buildEmailDetail(_selectedEmail!),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbarButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: const Color(0xFF5F6368)),
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF1A73E8),
      const Color(0xFFE8710A),
      const Color(0xFF0B8043),
      const Color(0xFFD93025),
      const Color(0xFFA142F4),
      const Color(0xFF1E8E3E),
    ];
    return colors[name.hashCode % colors.length];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 100, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'Select an email to read',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailDetail(Email email) {
    return SelectionArea(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject
              SelectableText(
                email.subject,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF202124),
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 20),
              
              // Sender Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getAvatarColor(email.from),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        email.from.isNotEmpty ? email.from[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                email.from,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF202124),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              _formatDateTime(email.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.star_border),
                              onPressed: () {},
                              iconSize: 18,
                              color: const Color(0xFF5F6368),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.reply),
                              onPressed: () {},
                              iconSize: 18,
                              color: const Color(0xFF5F6368),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () {},
                              iconSize: 18,
                              color: const Color(0xFF5F6368),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'to me',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Email Body with proper HTML rendering
              // Email Body with IFrame rendering
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: EmailRenderer(
                    htmlContent: email.html.isNotEmpty 
                        ? email.html 
                        : '<p>${email.text.replaceAll('\n', '<br>')}</p>',
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action Buttons
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.reply, size: 16),
                    label: const Text('Reply'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A73E8),
                      side: const BorderSide(color: Color(0xFFDADCE0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.forward, size: 16),
                    label: const Text('Forward'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A73E8),
                      side: const BorderSide(color: Color(0xFFDADCE0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formatDateCompact(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final emailDate = DateTime(date.year, date.month, date.day);
    
    if (emailDate == today) {
      return DateFormat.jm().format(date);
    } else if (now.year == date.year) {
      return DateFormat.MMMd().format(date);
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays < 1 && now.day == date.day) {
      return DateFormat.jm().format(date);
    } else if (diff.inDays < 7) {
      return '${DateFormat.E().format(date)}, ${DateFormat.jm().format(date)}';
    } else {
      return DateFormat('MMM d, yyyy, h:mm a').format(date);
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: const Text('Delete this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversation deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
