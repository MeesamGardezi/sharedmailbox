import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/email_service.dart';
import '../../core/models/email_model.dart';

class InboxState extends ChangeNotifier {
  final EmailService _emailService = EmailService();
  List<Email> _emails = [];
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _accounts = [];
  
  Map<String, dynamic> _pagination = {};
  bool _isLoadingMore = false;

  List<Email> get emails => _emails;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _pagination.values.any((p) => p['hasMore'] == true) || _pagination.isEmpty;

  Future<void> fetchEmails() async {
    _isLoading = true;
    _error = null;
    _pagination = {};
    notifyListeners();

    try {
      await _loadAccounts();

      if (_accounts.isEmpty) {
        _emails = [];
      } else {
        final result = await _emailService.fetchEmails(_accounts);
        _emails = result.emails;
        _pagination = result.pagination;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreEmails() async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      // Prepare offsets from current pagination state
      final offsets = _pagination.map((key, value) {
        if (value['nextPageToken'] != null) {
          return MapEntry(key, value['nextPageToken']);
        } else if (value['nextOffset'] != null) {
          return MapEntry(key, value['nextOffset']);
        }
        return MapEntry(key, null);
      });

      // Remove nulls
      offsets.removeWhere((key, value) => value == null);

      final result = await _emailService.fetchEmails(_accounts, offsets: offsets);
      
      // Append new emails
      _emails.addAll(result.emails);
      
      // Update pagination state (merge with existing)
      result.pagination.forEach((key, value) {
        _pagination[key] = value;
      });
      
      // Re-sort emails by date
      _emails.sort((a, b) => b.date.compareTo(a.date));
      
    } catch (e) {
      print('Error loading more emails: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadAccounts() async {
    if (_accounts.isNotEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null || userData['companyId'] == null) {
      throw Exception('No company associated');
    }

    final accountsSnapshot = await FirebaseFirestore.instance
        .collection('emailAccounts')
        .where('companyId', isEqualTo: userData['companyId'])
        .where('status', isEqualTo: 'active')
        .get();

    _accounts = accountsSnapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ..._sanitizeData(doc.data()),
      };
    }).toList();
  }

  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    return data.map((key, value) {
      return MapEntry(key, _sanitizeValue(value));
    });
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is Map<String, dynamic>) {
      return _sanitizeData(value);
    } else if (value is List) {
      return value.map((e) => _sanitizeValue(e)).toList();
    }
    return value;
  }

  Future<void> markAsRead(Email email) async {
    if (email.isRead) return;

    email.isRead = true;
    notifyListeners(); // Optimistic update

    // Find the account for this email
    final account = _accounts.firstWhere(
      (acc) => acc['name'] == email.accountName,
      orElse: () => {},
    );

    if (account.isNotEmpty) {
      String? uid;
      if (email.accountType == 'imap') {
        final parts = email.id.split('_');
        if (parts.length >= 3) {
          uid = parts.last;
        }
      }

      await _emailService.markAsRead(email.id, account, email.messageId, uid);
    }
  }
}
