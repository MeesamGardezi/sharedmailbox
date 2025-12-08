import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_frontend/features/whatsapp/whatsapp_message_model.dart';
import 'package:flutter_frontend/features/whatsapp/whatsapp_service.dart';
import 'package:intl/intl.dart';

class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  final WhatsAppService _service = WhatsAppService();
  String? _selectedGroupId;
  bool _showConnectionPanel = false;

  // TODO: For now, use 'default_user' to match WhatsApp logger session
  String get currentUserId => 'default_user';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.message, color: Colors.white),
            SizedBox(width: 8),
            Text('WhatsApp Monitor'),
          ],
        ),
        backgroundColor: const Color(0xFF128C7E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          StreamBuilder<Map<String, dynamic>?>(
            stream: _service.streamWhatsAppAccountStatus(currentUserId),
            builder: (context, snapshot) {
              final isConnected = snapshot.data?['status'] == 'connected';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected ? Colors.greenAccent : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Connected' : 'Not Connected',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Connect WhatsApp',
            onPressed: () {
              setState(() {
                _showConnectionPanel = !_showConnectionPanel;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showConnectionPanel) _buildConnectionPanel(),
          _buildGroupFilterBar(),
          Expanded(child: _buildMessagesList()),
        ],
      ),
    );
  }

  Widget _buildConnectionPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: _service.streamWhatsAppAccountStatus(currentUserId),
        builder: (context, snapshot) {
          final accountData = snapshot.data;
          final isConnected = accountData?['status'] == 'connected';

          if (isConnected) {
            return _buildConnectedStatus(accountData!);
          }
          return _buildQRCodeSection();
        },
      ),
    );
  }

  Widget _buildConnectedStatus(Map<String, dynamic> accountData) {
    return Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFF25D366),
          child: Icon(Icons.check, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                accountData['name'] ?? 'WhatsApp Account',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '+${accountData['phone'] ?? 'Unknown'}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _showConnectionPanel = false;
            });
          },
        ),
      ],
    );
  }

  Widget _buildQRCodeSection() {
    return Column(
      children: [
        const Text(
          'Scan QR Code with WhatsApp',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Open WhatsApp on your phone → Menu → Linked Devices → Link a Device',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        FutureBuilder<String?>(
          future: _service.getQRCode(currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Image.memory(
                  base64Decode(snapshot.data!.split(',').last),
                  width: 200,
                  height: 200,
                ),
              );
            }

            return Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text('QR Code not available', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF128C7E)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGroupFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _service.getMonitoredGroupsStream(currentUserId),
        builder: (context, snapshot) {
          final groups = snapshot.data ?? [];
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', null),
                ...groups.map((group) => _buildFilterChip(
                  group['groupName'] ?? 'Unknown',
                  group['groupId'],
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String? groupId) {
    final isSelected = _selectedGroupId == groupId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedGroupId = selected ? groupId : null;
          });
        },
        selectedColor: const Color(0xFF25D366).withValues(alpha: 0.2),
        checkmarkColor: const Color(0xFF128C7E),
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<List<WhatsAppMessage>>(
      stream: _service.getMessagesStream(currentUserId),
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

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var messages = snapshot.data ?? [];

        if (_selectedGroupId != null) {
          messages = messages.where((m) => m.groupId == _selectedGroupId).toList();
        }

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(
                  'Connect WhatsApp and monitor a group to start seeing messages.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showConnectionPanel = true),
                  icon: const Icon(Icons.link),
                  label: const Text('Connect WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF128C7E),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: messages.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _buildMessageCard(messages[index]),
        );
      },
    );
  }

  Widget _buildMessageCard(WhatsAppMessage msg) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF25D366),
                  radius: 20,
                  child: Text(
                    msg.initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          msg.groupName,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTimestamp(msg.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            if (msg.hasMedia) ...[
              const SizedBox(height: 12),
              _buildMediaContent(msg),
            ],
            if (msg.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(msg.content, style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(WhatsAppMessage msg) {
    if (msg.mediaError) {
      return _buildMediaError('Media failed to load');
    }

    final mediaUrl = msg.mediaUrl ?? msg.mediaPath;

    if (mediaUrl == null) {
      return _buildMediaLoading(msg.mediaType ?? 'media');
    }

    if (msg.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          mediaUrl,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 200,
              color: Colors.grey.shade100,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildMediaError('Image unavailable - CORS not configured'),
        ),
      );
    }

    if (msg.isVideo) {
      return _buildMediaPlaceholder(Icons.play_circle_filled, 'Video');
    }

    if (msg.isAudio) {
      return _buildMediaPlaceholder(Icons.audiotrack, 'Audio message');
    }

    return _buildMediaPlaceholder(Icons.attach_file, msg.mediaType ?? 'File');
  }

  Widget _buildMediaLoading(String type) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 8),
          Text('Loading $type...', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMediaError(String message) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey.shade400, size: 32),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMediaPlaceholder(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (diff.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(timestamp)}';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE HH:mm').format(timestamp);
    } else {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }
}
