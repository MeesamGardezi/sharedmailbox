import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _loadCalendarEvents();
  }

  Future<void> _loadCalendarEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get user's company
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _errorMessage = 'User profile not found';
          _isLoading = false;
        });
        return;
      }

      final companyId = userDoc.data()?['companyId'];
      if (companyId == null) {
        setState(() {
          _errorMessage = 'No company associated with user';
          _isLoading = false;
        });
        return;
      }

      // First, check if there are ANY active accounts
      final allAccountsSnapshot = await FirebaseFirestore.instance
          .collection('emailAccounts')
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'active')
          .get();

      if (allAccountsSnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No email accounts found. Please add an account first.';
          _isLoading = false;
        });
        return;
      }

      // Now check specifically for Gmail OAuth accounts
      final gmailAccountsSnapshot = await FirebaseFirestore.instance
          .collection('emailAccounts')
          .where('companyId', isEqualTo: companyId)
          .where('provider', isEqualTo: 'gmail-oauth')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (gmailAccountsSnapshot.docs.isEmpty) {
        // Check what types of accounts exist
        final hasImapAccounts = allAccountsSnapshot.docs.any(
          (doc) => doc.data()['provider'] == 'imap'
        );
        
        setState(() {
          _errorMessage = hasImapAccounts 
            ? 'Calendar requires a Gmail account connected via OAuth.\n\nYou have IMAP accounts, but calendar access requires Gmail OAuth.\n\nPlease add a Gmail account in the Email Accounts section.'
            : 'No Google account found. Please add a Gmail account to access calendar.';
          _isLoading = false;
        });
        return;
      }

      // Use the first Gmail account
      final accountData = gmailAccountsSnapshot.docs.first.data();
      _selectedAccount = accountData;

      // Fetch calendar events from backend
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Extract only the necessary OAuth fields to avoid serialization issues
      final oauth = accountData['oauth'] as Map<String, dynamic>?;
      
      // Validate OAuth credentials exist
      if (oauth == null || oauth['accessToken'] == null || oauth['refreshToken'] == null) {
        setState(() {
          _errorMessage = 'OAuth credentials are missing or incomplete. Please reconnect your Gmail account.';
          _isLoading = false;
        });
        return;
      }

      print('[Calendar] Fetching events with account: ${accountData['email']}');
      
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/calendar/events'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'account': {
            'email': accountData['email'],
            'oauth': {
              'accessToken': oauth['accessToken'],
              'refreshToken': oauth['refreshToken'],
              'expiryDate': oauth['expiryDate'],
            }
          },
          'timeMin': startOfMonth.toIso8601String(),
          'timeMax': endOfMonth.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _events = data['events'] ?? [];
          _isLoading = false;
        });

        // If token was refreshed, update it in Firestore
        if (data['tokenRefreshed'] != null) {
          await gmailAccountsSnapshot.docs.first.reference.update({
            'oauth.accessToken': data['tokenRefreshed']['accessToken'],
            'oauth.expiryDate': data['tokenRefreshed']['expiryDate'],
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch calendar events: ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.indigo, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendar',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                    if (_selectedAccount != null)
                      Text(
                        _selectedAccount!['email'] ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _loadCalendarEvents,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadCalendarEvents,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _events.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_available,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No events this month',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _events.length,
                            itemBuilder: (context, index) {
                              final event = _events[index];
                              return _buildEventCard(event);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final summary = event['summary'] ?? 'Untitled Event';
    final description = event['description'];
    final location = event['location'];
    
    // Parse start and end times
    final start = event['start'];
    final end = event['end'];
    
    DateTime? startTime;
    DateTime? endTime;
    bool isAllDay = false;

    if (start != null) {
      if (start['dateTime'] != null) {
        startTime = DateTime.parse(start['dateTime']);
      } else if (start['date'] != null) {
        startTime = DateTime.parse(start['date']);
        isAllDay = true;
      }
    }

    if (end != null) {
      if (end['dateTime'] != null) {
        endTime = DateTime.parse(end['dateTime']);
      } else if (end['date'] != null) {
        endTime = DateTime.parse(end['date']);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and time
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (startTime != null)
                        Row(
                          children: [
                            Icon(
                              isAllDay ? Icons.calendar_today : Icons.access_time,
                              size: 16,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAllDay
                                  ? DateFormat('EEEE, MMMM d, y').format(startTime)
                                  : '${DateFormat('EEEE, MMMM d, y • h:mm a').format(startTime)}${endTime != null ? ' - ${DateFormat('h:mm a').format(endTime)}' : ''}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Location
            if (location != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.black54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            // Description
            if (description != null) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
