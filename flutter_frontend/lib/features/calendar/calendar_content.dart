import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';

// ============================================================================
// CALENDAR CONTENT - Without sidebar, for use inside AppShell
// ============================================================================

class CalendarContent extends StatefulWidget {
  const CalendarContent({super.key});

  @override
  State<CalendarContent> createState() => _CalendarContentState();
}

class _CalendarContentState extends State<CalendarContent> {
  final _user = FirebaseAuth.instance.currentUser;
  String? _companyId;
  bool _isLoading = true;
  String? _error;

  // Calendar state
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;
  CalendarViewType _viewType = CalendarViewType.month;
  Map<DateTime, List<CalendarEvent>> _events = {};
  List<CalendarEvent> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedEvents = _getEventsForDay(_selectedDay!);
    _initialize();
  }

  Future<void> _initialize() async {
    await _fetchCompanyId();
    await _loadCalendarEvents();
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to fetch user data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCalendarEvents() async {
    if (_companyId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final accountsSnapshot = await FirebaseFirestore.instance
          .collection('emailAccounts')
          .where('companyId', isEqualTo: _companyId)
          .where('provider', isEqualTo: 'gmail-oauth')
          .get();

      if (accountsSnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No Google account found. Please add a Gmail account first.';
        });
        return;
      }

      final accountData = accountsSnapshot.docs.first.data();

      // Fetch events for visible range (3 months buffer)
      final startDate = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      final endDate = DateTime(_focusedMonth.year, _focusedMonth.month + 2, 0, 23, 59, 59);

      final response = await http.post(
        Uri.parse(AppConfig.calendarEventsEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'account': {
            'email': accountData['email'],
            'oauth': {
              'accessToken': accountData['oauth']?['accessToken'],
              'refreshToken': accountData['oauth']?['refreshToken'],
              'expiryDate': accountData['oauth']?['expiryDate'],
            },
          },
          'timeMin': startDate.toIso8601String(),
          'timeMax': endDate.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['events'] ?? [];

        final Map<DateTime, List<CalendarEvent>> eventMap = {};

        for (var item in items) {
          final event = CalendarEvent.fromJson(item);
          final eventDate = DateTime(
            event.start.year,
            event.start.month,
            event.start.day,
          );

          if (eventMap[eventDate] == null) {
            eventMap[eventDate] = [];
          }
          eventMap[eventDate]!.add(event);
        }

        setState(() {
          _events = eventMap;
          _selectedEvents = _getEventsForDay(_selectedDay ?? DateTime.now());
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load events: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading calendar events: $e';
        _isLoading = false;
      });
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      _selectedDay = day;
      _selectedEvents = _getEventsForDay(day);
    });
  }

  void _goToToday() {
    setState(() {
      _focusedMonth = DateTime.now();
      _selectedDay = DateTime.now();
      _selectedEvents = _getEventsForDay(_selectedDay!);
    });
    _loadCalendarEvents();
  }

  void _goToPreviousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
    _loadCalendarEvents();
  }

  void _goToNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
    _loadCalendarEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Google Calendar-style Header
        _buildHeader(),

        // Main Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState()
                  : _buildMainContent(),
        ),
      ],
    );
  }

  // ============================================================================
  // HEADER
  // ============================================================================

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Calendar icon and title
          Row(
            children: [
              Image.network(
                'https://www.gstatic.com/images/branding/product/1x/calendar_2020q4_48dp.png',
                width: 40,
                height: 40,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Calendar',
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFF3C4043),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Today button
          _buildTodayButton(),

          const SizedBox(width: 16),

          // Navigation arrows
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _goToPreviousMonth,
            color: const Color(0xFF5F6368),
            splashRadius: 20,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _goToNextMonth,
            color: const Color(0xFF5F6368),
            splashRadius: 20,
          ),

          const SizedBox(width: 16),

          // Month and year
          Text(
            DateFormat('MMMM yyyy').format(_focusedMonth),
            style: const TextStyle(
              fontSize: 22,
              color: Color(0xFF3C4043),
              fontWeight: FontWeight.w400,
            ),
          ),

          const Spacer(),

          // View type dropdown
          _buildViewTypeDropdown(),

          const SizedBox(width: 16),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCalendarEvents,
            color: const Color(0xFF5F6368),
            splashRadius: 20,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildTodayButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _goToToday,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDADCE0)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Today',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3C4043),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDADCE0)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CalendarViewType>(
          value: _viewType,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF5F6368)),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF3C4043),
          ),
          onChanged: (CalendarViewType? newValue) {
            if (newValue != null) {
              setState(() {
                _viewType = newValue;
              });
            }
          },
          items: CalendarViewType.values.map((type) {
            return DropdownMenuItem<CalendarViewType>(
              value: type,
              child: Text(type.label),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ============================================================================
  // MAIN CONTENT (No sidebar - just calendar and events panel)
  // ============================================================================

  Widget _buildMainContent() {
    return Row(
      children: [
        // Calendar Grid
        Expanded(
          flex: 3,
          child: _buildCalendarGrid(),
        ),

        // Event Details Panel
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          child: _buildEventDetailsPanel(),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF5F6368),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCalendarEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // CALENDAR GRID
  // ============================================================================

  Widget _buildCalendarGrid() {
    final weeks = _getWeeksInMonth(_focusedMonth);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Day headers (SUN, MON, TUE, etc.)
          _buildDayHeaders(),

          // Calendar weeks
          Expanded(
            child: Column(
              children: weeks.map((week) {
                return Expanded(
                  child: _buildWeekRow(week),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders() {
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: days.map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF70757A),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeekRow(List<DateTime> week) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: week.map((day) {
          return Expanded(
            child: _buildDayCell(day),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final isToday = _isSameDay(day, DateTime.now());
    final isSelected = _selectedDay != null && _isSameDay(day, _selectedDay!);
    final isCurrentMonth = day.month == _focusedMonth.month;
    final events = _getEventsForDay(day);

    return GestureDetector(
      onTap: () => _onDaySelected(day),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE8F0FE)
              : Colors.transparent,
          border: Border(
            right: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Day number
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFF1A73E8)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.w500 : FontWeight.w400,
                          color: isToday
                              ? Colors.white
                              : isCurrentMonth
                                  ? const Color(0xFF3C4043)
                                  : const Color(0xFF70757A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Events
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: events.take(3).map((event) {
                    return _buildEventBar(event, isCurrentMonth);
                  }).toList(),
                ),
              ),
            ),

            // More events indicator
            if (events.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '${events.length - 3} more',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1A73E8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventBar(CalendarEvent event, bool isCurrentMonth) {
    // Determine event color based on event type
    Color eventColor;
    if (event.summary.toLowerCase().contains('holiday') ||
        event.summary.toLowerCase().contains('christmas') ||
        event.summary.toLowerCase().contains('new year')) {
      eventColor = const Color(0xFF33B679); // Green for holidays
    } else {
      eventColor = const Color(0xFF039BE5); // Blue for regular events
    }

    return Container(
      margin: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: eventColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        event.summary,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: isCurrentMonth ? 1.0 : 0.6),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ============================================================================
  // EVENT DETAILS PANEL
  // ============================================================================

  Widget _buildEventDetailsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedDay != null
                    ? DateFormat('EEEE, MMMM d').format(_selectedDay!)
                    : 'Select a day',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3C4043),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_selectedEvents.length} ${_selectedEvents.length == 1 ? 'event' : 'events'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF70757A),
                ),
              ),
            ],
          ),
        ),

        // Events list
        Expanded(
          child: _selectedEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No events',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _selectedEvents.length,
                  itemBuilder: (context, index) {
                    return _buildEventDetailCard(_selectedEvents[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventDetailCard(CalendarEvent event) {
    // Determine event color
    Color eventColor;
    if (event.summary.toLowerCase().contains('holiday') ||
        event.summary.toLowerCase().contains('christmas') ||
        event.summary.toLowerCase().contains('new year')) {
      eventColor = const Color(0xFF33B679);
    } else {
      eventColor = const Color(0xFF039BE5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color indicator
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: eventColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.summary,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3C4043),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      event.isAllDay
                          ? 'All day'
                          : '${DateFormat.jm().format(event.start)} - ${DateFormat.jm().format(event.end)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (event.description != null &&
                    event.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    event.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  List<List<DateTime>> _getWeeksInMonth(DateTime month) {
    final weeks = <List<DateTime>>[];
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    // Find the first day of the first week (may be in previous month)
    final firstDayOfFirstWeek = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday % 7),
    );

    var currentDay = firstDayOfFirstWeek;

    // Generate weeks until we've passed the last day of the month
    while (currentDay.isBefore(lastDayOfMonth) ||
        currentDay.month == month.month ||
        weeks.length < 5) {
      final week = <DateTime>[];
      for (var i = 0; i < 7; i++) {
        week.add(currentDay);
        currentDay = currentDay.add(const Duration(days: 1));
      }
      weeks.add(week);

      // Stop if we have at least 5 weeks and the current day is past the month
      if (weeks.length >= 5 && currentDay.month != month.month) {
        break;
      }

      // Maximum 6 weeks
      if (weeks.length >= 6) {
        break;
      }
    }

    return weeks;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ============================================================================
// ENUMS AND MODELS
// ============================================================================

enum CalendarViewType {
  month('Month'),
  twoWeeks('2 Weeks'),
  week('Week');

  final String label;
  const CalendarViewType(this.label);
}

class CalendarEvent {
  final String id;
  final String summary;
  final String? description;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
  final String? calendarId;
  final Color? color;

  CalendarEvent({
    required this.id,
    required this.summary,
    this.description,
    required this.start,
    required this.end,
    this.isAllDay = false,
    this.calendarId,
    this.color,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final startData = json['start'];
    final endData = json['end'];

    DateTime parseDateTime(dynamic data) {
      if (data['dateTime'] != null) {
        return DateTime.parse(data['dateTime']);
      } else if (data['date'] != null) {
        return DateTime.parse(data['date']);
      }
      return DateTime.now();
    }

    final start = parseDateTime(startData);
    final end = parseDateTime(endData);
    final isAllDay = startData['date'] != null;

    return CalendarEvent(
      id: json['id'] ?? '',
      summary: json['summary'] ?? 'Untitled Event',
      description: json['description'],
      start: start,
      end: end,
      isAllDay: isAllDay,
      calendarId: json['calendarId'],
    );
  }
}
