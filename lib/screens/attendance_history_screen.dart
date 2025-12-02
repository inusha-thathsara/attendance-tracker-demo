import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/timetable.dart';
import '../models/timetable_entry.dart';
import '../models/enums.dart';
import '../providers/attendance_provider.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final TimeTableEntry entry;
  final Timetable timetable;

  const AttendanceHistoryScreen({super.key, required this.entry, required this.timetable});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  late List<DateTime> _pastDates;

  @override
  void initState() {
    super.initState();
    _generatePastDates();
  }

  void _generatePastDates() {
    _pastDates = [];
    final now = DateTime.now();
    
    // Determine the end date for generation (min of now or timetable end)
    // We want to show history up to today, or up to the end of the semester if it's in the past.
    // If the semester ends in the future, we stop at today.
    // If the semester ended in the past, we stop at the end date.
    DateTime endDate = widget.timetable.endDate;
    if (now.isBefore(endDate)) {
      endDate = now;
    }

    // Start from the end date and go backwards to the start date
    DateTime current = endDate;
    
    // Adjust current to match the day of week
    while (current.weekday != widget.entry.dayOfWeek) {
      current = current.subtract(const Duration(days: 1));
    }
    
    // Ensure we didn't go before the start date
    if (current.isBefore(widget.timetable.startDate)) {
      return;
    }

    while (current.isAfter(widget.timetable.startDate) || isSameDay(current, widget.timetable.startDate)) {
       _pastDates.add(current);
       current = current.subtract(const Duration(days: 7));
    }
  }

  bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.entry.subjectName} History'),
      ),
      body: ListView.builder(
        itemCount: _pastDates.length,
        itemBuilder: (context, index) {
          final date = _pastDates[index];
          final status = provider.getStatus(widget.entry.id, date);

          return ListTile(
            title: Text(DateFormat('EEEE, MMMM d, yyyy').format(date)),
            subtitle: Text(status != null ? status.name.toUpperCase() : 'Not Marked'),
            trailing: _buildStatusIcon(status),
            onTap: () => _showStatusDialog(context, date, status),
          );
        },
      ),
    );
  }

  Widget _buildStatusIcon(AttendanceStatus? status) {
    switch (status) {
      case AttendanceStatus.present:
        return const Icon(Icons.check_circle, color: Colors.green);
      case AttendanceStatus.absent:
        return const Icon(Icons.cancel, color: Colors.red);
      case AttendanceStatus.cancelled:
        return const Icon(Icons.block, color: Colors.grey);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  void _showStatusDialog(BuildContext context, DateTime date, AttendanceStatus? currentStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark Attendance for ${DateFormat('MMM d').format(date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Present'),
              onTap: () {
                Provider.of<AttendanceProvider>(context, listen: false)
                    .markAttendance(widget.entry.id, date, AttendanceStatus.present);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('Absent'),
              onTap: () {
                Provider.of<AttendanceProvider>(context, listen: false)
                    .markAttendance(widget.entry.id, date, AttendanceStatus.absent);
                Navigator.pop(context);
              },
            ),
             ListTile(
              leading: const Icon(Icons.block, color: Colors.grey),
              title: const Text('Cancelled'),
              onTap: () {
                Provider.of<AttendanceProvider>(context, listen: false)
                    .markAttendance(widget.entry.id, date, AttendanceStatus.cancelled);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
