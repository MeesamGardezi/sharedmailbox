import 'package:cloud_firestore/cloud_firestore.dart';

class WhatsAppMessage {
  final String id;
  final String groupId;
  final String userId;
  final String sender;
  final String senderPhone;
  final String content;
  final DateTime timestamp;
  final String type;
  final String senderName;
  final String groupName;
  final String? mediaPath;
  final String? mediaUrl;
  final String? mediaType;
  final bool hasMedia;
  final bool mediaError;

  WhatsAppMessage({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.type,
    required this.hasMedia,
    this.senderName = 'Unknown',
    this.senderPhone = '',
    this.groupName = 'Unknown Group',
    this.mediaPath,
    this.mediaUrl,
    this.mediaType,
    this.mediaError = false,
  });

  factory WhatsAppMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parsedTimestamp;
    try {
      final ts = data['timestamp'];
      if (ts is Timestamp) {
        parsedTimestamp = ts.toDate();
      } else if (ts is String) {
        parsedTimestamp = DateTime.parse(ts);
      } else if (ts is DateTime) {
        parsedTimestamp = ts;
      } else {
        parsedTimestamp = DateTime.now();
      }
    } catch (e) {
      parsedTimestamp = DateTime.now();
    }

    return WhatsAppMessage(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      userId: data['userId'] ?? '',
      sender: data['sender'] ?? '',
      senderPhone: data['senderPhone'] ?? '',
      content: data['content'] ?? '',
      timestamp: parsedTimestamp,
      type: data['type'] ?? 'text',
      hasMedia: data['hasMedia'] ?? false,
      senderName: data['senderName'] ?? data['senderPhone'] ?? 'Unknown',
      groupName: data['groupName'] ?? 'Unknown Group',
      mediaPath: data['mediaPath'],
      mediaUrl: data['mediaUrl'],
      mediaType: data['mediaType'],
      mediaError: data['mediaError'] ?? false,
    );
  }

  bool get isImage {
    if (mediaType == null) return false;
    return mediaType!.startsWith('image/');
  }

  bool get isVideo {
    if (mediaType == null) return false;
    return mediaType!.startsWith('video/');
  }

  bool get isAudio {
    if (mediaType == null) return false;
    return mediaType!.startsWith('audio/');
  }

  String get displayName {
    if (senderName.isNotEmpty && senderName != 'Unknown') {
      return senderName;
    }
    if (senderPhone.isNotEmpty) {
      return senderPhone;
    }
    return 'Unknown';
  }

  String get initials {
    final name = displayName;
    if (name.isEmpty || name == 'Unknown') return '?';

    if (RegExp(r'^\+?\d{8,}$').hasMatch(name)) {
      return name.substring(name.length - 2);
    }

    return name[0].toUpperCase();
  }
}
