import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_entry.dart';
import '../models/enums.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import 'attendance_history_screen.dart';
import 'add_entry_dialog.dart';
import '../providers/module_provider.dart';




class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimetableProvider>(context);
    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Timetable'),
        actions: [

        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntryDialog(context),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
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
                }),
              const Divider(),
            ],
          );
        },
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

    
    // Find the date for this entry in the current week
    final now = DateTime.now();
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final initialDate = currentMonday.add(Duration(days: entry.dayOfWeek - 1));
    
    showDialog(
      context: context,
      builder: (context) => AttendanceDialog(
        entry: entry,
        initialDate: initialDate,
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

  const AttendanceDialog({
    super.key,
    required this.entry,
    required this.initialDate,
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

  @override
  Widget build(BuildContext context) {
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
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildStatusButton(AttendanceStatus.present, Colors.green, 'Present')),
              const SizedBox(width: 4),
              Expanded(child: _buildStatusButton(AttendanceStatus.absent, Colors.red, 'Absent')),
              const SizedBox(width: 4),
              Expanded(child: _buildStatusButton(AttendanceStatus.cancelled, Colors.grey, 'Cancelled')),
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
                builder: (context) => AttendanceHistoryScreen(entry: widget.entry),
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

  Widget _buildStatusButton(AttendanceStatus status, Color color, String label) {
    final isSelected = _currentStatus == status;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : null,
        foregroundColor: isSelected ? Colors.white : color,
      ),
      onPressed: () {
        Provider.of<AttendanceProvider>(context, listen: false)
            .markAttendance(widget.entry.id, _selectedDate, status);
        _loadStatus();
      },
      child: Text(label),
    );
  }
}
