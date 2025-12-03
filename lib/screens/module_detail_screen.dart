import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/module.dart';
import '../models/timetable_entry.dart';
import '../providers/timetable_provider.dart';
import 'modules_screen.dart'; // For AddModuleDialog
import 'add_entry_dialog.dart';
import '../models/enums.dart';
import '../providers/attendance_provider.dart';

class ModuleDetailScreen extends StatelessWidget {
  final Module module;

  const ModuleDetailScreen({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    final timetableProvider = Provider.of<TimetableProvider>(context);
    final entries = timetableProvider.entries.where((e) => e.moduleCode == module.code).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${module.code} Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditModuleDialog(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.name, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Credits: ${module.credits}'),
                    Text('Lecturer: ${module.lecturerName}'),
                    if (module.note != null && module.note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Note:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(module.note!),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Classes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No classes added for this module.'))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      // Calculate date for status
                      final now = DateTime.now();
                      int diff = entry.dayOfWeek - now.weekday;
                      if (diff > 0) diff -= 7;
                      final date = now.add(Duration(days: diff));
                      final status = Provider.of<AttendanceProvider>(context).getStatus(entry.id, date);

                      return ListTile(
                        title: Text('${entry.type.name.toUpperCase()}'),
                        subtitle: Text(
                          '${_getDayName(entry.dayOfWeek)} • ${entry.startTime.format(context)} - ${entry.endTime.format(context)}\n'
                          '${entry.mode.name.toUpperCase()}${entry.location != null ? ' • ${entry.location}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status != null) ...[
                              _buildStatusIcon(status),
                              const SizedBox(width: 8),
                            ],
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditEntryDialog(context, entry),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDeleteEntry(context, entry),
                            ),
                          ],
                        ),
                        onTap: () => _showEditEntryDialog(context, entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int day) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[day - 1];
  }

  void _showEditModuleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddModuleDialog(module: module),
    );
  }

  void _showEditEntryDialog(BuildContext context, TimeTableEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AddEntryDialog(entry: entry),
    );
  }

  Future<void> _confirmDeleteEntry(BuildContext context, TimeTableEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Are you sure you want to delete the ${entry.type.name} on ${_getDayName(entry.dayOfWeek)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await Provider.of<TimetableProvider>(context, listen: false).deleteEntry(entry.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class deleted')),
        );
      }
    }
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
