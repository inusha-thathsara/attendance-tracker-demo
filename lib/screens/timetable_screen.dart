import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_entry.dart';
import '../models/timetable.dart';
import '../models/enums.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import 'attendance_history_screen.dart';
import 'add_entry_dialog.dart';




import 'package:table_calendar/table_calendar.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  bool _isCalendarView = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimetableProvider>(context);
    final currentTimetable = provider.currentTimetable;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Timetable'),
        actions: [
          IconButton(
            icon: Icon(_isCalendarView ? Icons.list : Icons.calendar_month),
            onPressed: () {
              setState(() {
                _isCalendarView = !_isCalendarView;
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntryDialog(context),
        child: const Icon(Icons.add),
      ),
      body: _isCalendarView 
          ? _buildCalendarView(provider, currentTimetable)
          : _buildListView(provider),
    );
  }

  Widget _buildListView(TimetableProvider provider) {
    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = index + 1;
        final entries = provider.getEntriesForDay(day);
        
        if (entries.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                days[index],
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ...entries.map((entry) {
              // Calculate date for status (Current Week Logic)
              final now = DateTime.now();
              // Find Monday of the current week
              final currentMonday = now.subtract(Duration(days: now.weekday - 1));
              // Add offset for the entry's day
              final date = currentMonday.add(Duration(days: entry.dayOfWeek - 1));
              final status = Provider.of<AttendanceProvider>(context).getStatus(entry.id, date);

              return _buildEntryTile(entry, status);
            }),
            const Divider(),
          ],
        );
      },
    );
  }

  Widget _buildCalendarView(TimetableProvider provider, Timetable? currentTimetable) {
    if (currentTimetable == null) {
      return const Center(child: Text('No timetable selected'));
    }

    return Column(
      children: [
        TableCalendar<TimeTableEntry>(
          firstDay: currentTimetable.startDate,
          lastDay: currentTimetable.endDate,
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            }
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          eventLoader: (day) {
            // Check if day is within timetable range
            if (day.isBefore(currentTimetable.startDate) || 
                day.isAfter(currentTimetable.endDate)) {
              return [];
            }
            return provider.getEntriesForDay(day.weekday);
          },
          calendarStyle: const CalendarStyle(
            markerDecoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Divider(),
        Expanded(
          child: _selectedDay == null
              ? const Center(child: Text('Select a day'))
              : Builder(
                  builder: (context) {
                    final entries = provider.getEntriesForDay(_selectedDay!.weekday);
                    if (entries.isEmpty) {
                      return const Center(child: Text('No classes for this day'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final status = Provider.of<AttendanceProvider>(context).getStatus(entry.id, _selectedDay!);
                        return _buildEntryTile(entry, status);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEntryTile(TimeTableEntry entry, AttendanceStatus? status) {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    
    return ListTile(
      title: Text(entry.moduleCode != null ? '${entry.moduleCode} - ${entry.subjectName}' : entry.subjectName),
      subtitle: Text('${entry.type.name} • ${entry.mode.name}${entry.location != null ? ' • ${entry.location}' : ''} • ${entry.startTime.format(context)} - ${entry.endTime.format(context)}'),
      onTap: () => _showAttendanceDialog(context, entry),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != null) ...[
            _buildStatusIcon(status),
            const SizedBox(width: 8),
          ],
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showAddEntryDialog(context, entry: entry);
              } else if (value == 'delete') {
                provider.deleteEntry(entry.id);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context, {TimeTableEntry? entry}) {
    showDialog(
      context: context,
      builder: (context) => AddEntryDialog(entry: entry),
    );
  }

  void _showAttendanceDialog(BuildContext context, TimeTableEntry entry) {
    final timetableProvider = Provider.of<TimetableProvider>(context, listen: false);
    final currentTimetable = timetableProvider.currentTimetable;

    if (currentTimetable == null) return;
    
    // Use selected day if in calendar view, otherwise calculate for current week
    DateTime targetDate;
    if (_isCalendarView && _selectedDay != null) {
      targetDate = _selectedDay!;
    } else {
      final now = DateTime.now();
      final currentMonday = now.subtract(Duration(days: now.weekday - 1));
      targetDate = currentMonday.add(Duration(days: entry.dayOfWeek - 1));
    }
    
    showDialog(
      context: context,
      builder: (context) => AttendanceDialog(
        entry: entry,
        initialDate: targetDate,
        timetable: currentTimetable,
      ),
    );
  }

  Widget _buildStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return const Icon(Icons.check_circle, color: Colors.green);
      case AttendanceStatus.absent:
        return const Icon(Icons.cancel, color: Colors.red);
      case AttendanceStatus.cancelled:
        return const Icon(Icons.remove_circle, color: Colors.grey);
    }
  }
}



class AttendanceDialog extends StatefulWidget {
  final TimeTableEntry entry;
  final DateTime initialDate;
  final Timetable timetable;

  const AttendanceDialog({
    super.key,
    required this.entry,
    required this.initialDate,
    required this.timetable,
  });

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  late DateTime _selectedDate;
  AttendanceStatus? _currentStatus;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _loadStatus();
  }

  void _loadStatus() {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    setState(() {
      _currentStatus = provider.getStatus(widget.entry.id, _selectedDate);
    });
  }

  bool _isDateValid(DateTime date) {
    // Normalize dates to ignore time
    final start = DateTime(widget.timetable.startDate.year, widget.timetable.startDate.month, widget.timetable.startDate.day);
    final end = DateTime(widget.timetable.endDate.year, widget.timetable.endDate.month, widget.timetable.endDate.day).add(const Duration(days: 1)).subtract(const Duration(seconds: 1)); // End of day
    
    return date.isAfter(start.subtract(const Duration(days: 1))) && date.isBefore(end.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _isDateValid(_selectedDate);

    return AlertDialog(
      title: Text('Mark Attendance: ${widget.entry.subjectName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Date'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _isDateValid(_selectedDate) ? _selectedDate : widget.timetable.startDate,
                firstDate: widget.timetable.startDate,
                lastDate: widget.timetable.endDate,
                selectableDayPredicate: (day) => day.weekday == widget.entry.dayOfWeek,
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
                _loadStatus();
              }
            },
          ),
          if (!isValid)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Selected date is outside the timetable duration.',
                style: TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildStatusButton(AttendanceStatus.present, Colors.green, 'Present', isValid)),
              const SizedBox(width: 4),
              Expanded(child: _buildStatusButton(AttendanceStatus.absent, Colors.red, 'Absent', isValid)),
              const SizedBox(width: 4),
              Expanded(child: _buildStatusButton(AttendanceStatus.cancelled, Colors.grey, 'Cancelled', isValid)),
            ],
          ),
          if (_currentStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Current: ${_currentStatus!.name.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceHistoryScreen(
                  entry: widget.entry,
                  timetable: widget.timetable,
                ),
              ),
            );
          },
          child: const Text('History'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStatusButton(AttendanceStatus status, Color color, String label, bool enabled) {
    final isSelected = _currentStatus == status;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : null,
        foregroundColor: isSelected ? Colors.white : color,
      ),
      onPressed: enabled ? () {
        Provider.of<AttendanceProvider>(context, listen: false)
            .markAttendance(widget.entry.id, _selectedDate, status);
        _loadStatus();
      } : null,
      child: Text(label),
    );
  }
}
