import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/timetable_entry.dart';
import '../models/enums.dart';
import '../providers/attendance_provider.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final TimeTableEntry entry;

  const AttendanceHistoryScreen({super.key, required this.entry});

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
    // Find the most recent occurrence
    int diff = widget.entry.dayOfWeek - now.weekday;
    if (diff > 0) diff -= 7;
    
    DateTime current = now.add(Duration(days: diff));
    
    // Generate for last 12 weeks
    for (int i = 0; i < 12; i++) {
      if (current.isBefore(now) || isSameDay(current, now)) {
         _pastDates.add(current);
      }
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
