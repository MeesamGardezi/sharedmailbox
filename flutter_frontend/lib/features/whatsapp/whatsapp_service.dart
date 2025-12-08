import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_frontend/features/whatsapp/whatsapp_message_model.dart';
import '../../core/config/app_config.dart';

class WhatsAppService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID, falling back to 'default_user' for testing
  String get currentUserId => _auth.currentUser?.uid ?? 'default_user';

  /// Stream messages for a specific user, ordered by time
  Stream<List<WhatsAppMessage>> getMessagesStream(String userId) {
    return _firestore
        .collection('messages')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => WhatsAppMessage.fromFirestore(doc))
          .toList();
      
      // Sort in memory to avoid needing a Firestore composite index immediately
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return messages;
    });
  }

  /// Stream messages for current authenticated user
  Stream<List<WhatsAppMessage>> getMyMessagesStream() {
    return getMessagesStream(currentUserId);
  }

  /// Get monitored groups from Firestore
  Stream<List<Map<String, dynamic>>> getMonitoredGroupsStream(String userId) {
    return _firestore
        .collection('monitoredGroups')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Check WhatsApp connection status
  Future<Map<String, dynamic>> getSessionStatus(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.whatsappSessionStatus(userId)),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Failed to get status'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Get available groups from WhatsApp
  Future<List<Map<String, dynamic>>> getGroups(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.whatsappGroups(userId)),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> groups = jsonDecode(response.body);
        return groups.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching groups: $e');
      return [];
    }
  }

  /// Toggle group monitoring
  Future<bool> toggleGroupMonitoring({
    required String userId,
    required String groupId,
    required String groupName,
    required bool isMonitoring,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.whatsappApiUrl}/monitor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'groupId': groupId,
          'groupName': groupName,
          'isMonitoring': isMonitoring,
        }),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Error toggling monitoring: $e');
      return false;
    }
  }

  /// Get QR code for linking WhatsApp
  Future<String?> getQRCode(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.whatsappQrCode(userId)),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['qrCode'];
      }
      return null;
    } catch (e) {
      print('Error fetching QR code: $e');
      return null;
    }
  }

  /// Check if WhatsApp account is connected from Firestore
  Future<Map<String, dynamic>?> getConnectedWhatsAppAccount(String userId) async {
    try {
      final doc = await _firestore.collection('whatsappAccounts').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error checking WhatsApp account: $e');
      return null;
    }
  }

  /// Stream WhatsApp account status
  Stream<Map<String, dynamic>?> streamWhatsAppAccountStatus(String userId) {
    return _firestore
        .collection('whatsappAccounts')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }
}
