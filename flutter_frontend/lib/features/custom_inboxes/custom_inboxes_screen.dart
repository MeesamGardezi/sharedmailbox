import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/custom_inbox.dart';

class CustomInboxesScreen extends StatefulWidget {
  const CustomInboxesScreen({super.key});

  @override
  State<CustomInboxesScreen> createState() => _CustomInboxesScreenState();
}

class _CustomInboxesScreenState extends State<CustomInboxesScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  String? _companyId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCompanyId();
  }

  Future<void> _fetchCompanyId() async {
    if (_user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      if (mounted) {
        setState(() {
          _companyId = doc.data()?['companyId'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_companyId == null) {
      return const Center(child: Text('Error: No company found'));
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.folder,
                color: Color(0xFF6366F1),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Custom Inboxes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateInboxDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Inbox'),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: StreamBuilder<List<CustomInbox>>(
            stream: CustomInboxService.getInboxes(_companyId!),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final inboxes = snapshot.data!;

              if (inboxes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 24),
                      Text(
                        'No Custom Inboxes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create custom inboxes to group your email accounts',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateInboxDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Your First Inbox'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: inboxes.length,
                itemBuilder: (context, index) {
                  return _buildInboxCard(inboxes[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInboxCard(CustomInbox inbox) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEditInboxDialog(context, inbox),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(inbox.color).withValues( alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.folder,
                      color: Color(inbox.color),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inbox.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${inbox.accountIds.length} email account${inbox.accountIds.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditInboxDialog(context, inbox);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(inbox);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (inbox.accountIds.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildAccountsList(inbox.accountIds),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsList(List<String> accountIds) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emailAccounts')
          .where(FieldPath.documentId, whereIn: accountIds.take(10).toList())
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }

        final accounts = snapshot.data!.docs;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: accounts.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final email = data['email'] ?? 'Unknown';
            final isGmail = data['provider'] == 'gmail-oauth';

            return Chip(
              avatar: CircleAvatar(
                backgroundColor: isGmail ? Colors.red.shade100 : Colors.blue.shade100,
                child: Icon(
                  isGmail ? Icons.g_mobiledata : Icons.mail,
                  size: 16,
                  color: isGmail ? Colors.red : Colors.blue,
                ),
              ),
              label: Text(email),
              backgroundColor: Colors.grey.shade50,
              side: BorderSide(color: Colors.grey.shade200),
            );
          }).toList(),
        );
      },
    );
  }

  void _showCreateInboxDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _InboxFormDialog(
        companyId: _companyId!,
        onSave: (name, accountIds, color) async {
          await CustomInboxService.createInbox(
            name: name,
            companyId: _companyId!,
            accountIds: accountIds,
            color: color,
          );
        },
      ),
    );
  }

  void _showEditInboxDialog(BuildContext context, CustomInbox inbox) {
    showDialog(
      context: context,
      builder: (context) => _InboxFormDialog(
        companyId: _companyId!,
        inbox: inbox,
        onSave: (name, accountIds, color) async {
          await CustomInboxService.updateInbox(
            inbox.copyWith(
              name: name,
              accountIds: accountIds,
              color: color,
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(CustomInbox inbox) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Inbox?'),
        content: Text('Are you sure you want to delete "${inbox.name}"? This will not delete the email accounts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              CustomInboxService.deleteInbox(inbox.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Dialog for creating or editing a custom inbox
class _InboxFormDialog extends StatefulWidget {
  final String companyId;
  final CustomInbox? inbox;
  final Future<void> Function(String name, List<String> accountIds, int color) onSave;

  const _InboxFormDialog({
    required this.companyId,
    this.inbox,
    required this.onSave,
  });

  @override
  State<_InboxFormDialog> createState() => _InboxFormDialogState();
}

class _InboxFormDialogState extends State<_InboxFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  List<String> _selectedAccountIds = [];
  int _selectedColor = 0xFF6366F1;
  bool _isSaving = false;

  final List<int> _colorOptions = [
    0xFF6366F1, // Indigo
    0xFFEF4444, // Red
    0xFFF59E0B, // Amber
    0xFF10B981, // Green
    0xFF3B82F6, // Blue
    0xFF8B5CF6, // Purple
    0xFFEC4899, // Pink
    0xFF06B6D4, // Cyan
  ];

  @override
  void initState() {
    super.initState();
    if (widget.inbox != null) {
      _nameController.text = widget.inbox!.name;
      _selectedAccountIds = List.from(widget.inbox!.accountIds);
      _selectedColor = widget.inbox!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.inbox == null ? 'Create Custom Inbox' : 'Edit Inbox'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Inbox Name',
                  hintText: 'e.g., Work, Personal, Support',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Color picker
              const Text(
                'Color',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: _colorOptions.map((color) {
                  final isSelected = color == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Email accounts selector
              const Text(
                'Assign Email Accounts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('emailAccounts')
                      .where('companyId', isEqualTo: widget.companyId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final accounts = snapshot.data!.docs;

                    if (accounts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No email accounts found. Add accounts first.'),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final doc = accounts[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final email = data['email'] ?? 'Unknown';
                        final isGmail = data['provider'] == 'gmail-oauth';
                        final isSelected = _selectedAccountIds.contains(doc.id);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedAccountIds.add(doc.id);
                              } else {
                                _selectedAccountIds.remove(doc.id);
                              }
                            });
                          },
                          secondary: CircleAvatar(
                            radius: 16,
                            backgroundColor: isGmail ? Colors.red.shade100 : Colors.blue.shade100,
                            child: Icon(
                              isGmail ? Icons.g_mobiledata : Icons.mail,
                              size: 18,
                              color: isGmail ? Colors.red : Colors.blue,
                            ),
                          ),
                          title: Text(email),
                          dense: true,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.inbox == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await widget.onSave(
        _nameController.text.trim(),
        _selectedAccountIds,
        _selectedColor,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
