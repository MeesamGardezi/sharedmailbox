import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/email_model.dart';

class EmailFetchResult {
  final List<Email> emails;
  final Map<String, dynamic> pagination;

  EmailFetchResult({required this.emails, required this.pagination});
}

class EmailService {
  // final String baseUrl = 'https://api.mybox.buildersolve.com/api';
  final String baseUrl = 'http://localhost:3000/api';

  Future<EmailFetchResult> fetchEmails(List<Map<String, dynamic>> accounts, {Map<String, dynamic>? offsets}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/emails'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accounts': accounts,
          'offsets': offsets ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> emailsJson = data['emails'] ?? [];
        final List<Email> emails = emailsJson.map((json) => Email.fromJson(json)).toList();
        final Map<String, dynamic> pagination = data['pagination'] ?? {};
        
        return EmailFetchResult(emails: emails, pagination: pagination);
      } else {
        throw Exception('Failed to load emails: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching emails: $e');
    }
  }

  Future<void> markAsRead(String id, Map<String, dynamic> account, String? messageId, String? uid) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/emails/$id/read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'account': account,
          'messageId': messageId,
          'uid': uid,
        }),
      );
    } catch (e) {
      print('Error marking as read: $e');
    }
  }
}
