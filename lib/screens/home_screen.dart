import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/timetable_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/theme_provider.dart';
import '../models/timetable_entry.dart';
import '../models/timetable.dart';
import '../models/enums.dart';
import 'timetable_screen.dart';
import 'stats_screen.dart';
import 'modules_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const _TodayTab(),
    const TimetableScreen(),
    const ModulesScreen(),
    const StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final timetableProvider = Provider.of<TimetableProvider>(context);
    final currentTimetable = timetableProvider.currentTimetable;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentTimetable?.name ?? 'Attendance Tracker'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                icon: Icon(themeProvider.themeMode == ThemeMode.dark 
                    ? Icons.light_mode 
                    : Icons.dark_mode),
                onPressed: () {
                  themeProvider.toggleTheme(themeProvider.themeMode != ThemeMode.dark);
                },
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('My Timetables'),
              accountEmail: Text(currentTimetable != null 
                ? '${DateFormat('MMM d').format(currentTimetable.startDate)} - ${DateFormat('MMM d, y').format(currentTimetable.endDate)}'
                : 'No Timetable Selected'),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.calendar_today),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ...timetableProvider.timetables.map((timetable) {
                    return ListTile(
                      title: Text(timetable.name),
                      subtitle: Text(
                        '${DateFormat('MMM d, y').format(timetable.startDate)} - ${DateFormat('MMM d, y').format(timetable.endDate)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: timetable.id == currentTimetable?.id,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () {
                              Navigator.pop(context);
                              _showTimetableDialog(context, timetable: timetable);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => _confirmDeleteTimetable(context, timetable),
                          ),
                        ],
                      ),
                      onTap: () {
                        timetableProvider.setCurrentTimetable(timetable.id);
                        Navigator.pop(context); // Close drawer
                      },
                    );
                  }),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Create New Timetable'),
                    onTap: () {
                      Navigator.pop(context);
                      _showTimetableDialog(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Timetable',
          ),
          NavigationDestination(
            icon: Icon(Icons.book),
            label: 'Modules',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }

  void _showTimetableDialog(BuildContext context, {Timetable? timetable}) {
    showDialog(
      context: context,
      builder: (context) => TimetableDialog(timetable: timetable),
    );
  }

  Future<void> _confirmDeleteTimetable(BuildContext context, Timetable timetable) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Timetable'),
        content: Text('Are you sure you want to delete "${timetable.name}"?'),
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
      await Provider.of<TimetableProvider>(context, listen: false).deleteTimetable(timetable.id);
    }
  }
}

class TimetableDialog extends StatefulWidget {
  final Timetable? timetable;

  const TimetableDialog({super.key, this.timetable});

  @override
  State<TimetableDialog> createState() => _TimetableDialogState();
}

class _TimetableDialogState extends State<TimetableDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _name = widget.timetable?.name ?? '';
    if (widget.timetable != null) {
      _dateRange = DateTimeRange(
        start: widget.timetable!.startDate,
        end: widget.timetable!.endDate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.timetable == null ? 'New Timetable' : 'Edit Timetable'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(labelText: 'Timetable Name (e.g. Sem 1)'),
              validator: (value) => value!.isEmpty ? 'Required' : null,
              onSaved: (value) => _name = value!,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(_dateRange == null 
                ? 'Select Duration' 
                : '${DateFormat('MMM d, y').format(_dateRange!.start)} - ${DateFormat('MMM d, y').format(_dateRange!.end)}'),
              trailing: const Icon(Icons.calendar_today),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange: _dateRange,
                );
                if (picked != null) {
                  setState(() {
                    _dateRange = picked;
                  });
                }
              },
            ),
            if (_dateRange == null)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Please select a date range', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate() && _dateRange != null) {
              _formKey.currentState!.save();
              
              if (widget.timetable == null) {
                // Create
                final timetable = Timetable(
                  id: const Uuid().v4(),
                  name: _name,
                  startDate: _dateRange!.start,
                  endDate: _dateRange!.end,
                  isCurrent: true, // Auto-switch to new timetable
                );
                Provider.of<TimetableProvider>(context, listen: false).addTimetable(timetable);
              } else {
                // Update
                final updatedTimetable = Timetable(
                  id: widget.timetable!.id,
                  name: _name,
                  startDate: _dateRange!.start,
                  endDate: _dateRange!.end,
                  isCurrent: widget.timetable!.isCurrent,
                );
                Provider.of<TimetableProvider>(context, listen: false).updateTimetable(updatedTimetable);
              }
              
              Navigator.pop(context);
            }
          },
          child: Text(widget.timetable == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dayOfWeek = today.weekday;
    final timetableProvider = Provider.of<TimetableProvider>(context);
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final todaysEntries = timetableProvider.getEntriesForDay(dayOfWeek);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            DateFormat('EEEE, MMMM d, y').format(today),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Expanded(
          child: todaysEntries.isEmpty
              ? const Center(child: Text('No classes today!'))
              : ListView.builder(
                  itemCount: todaysEntries.length,
                  itemBuilder: (context, index) {
                    final entry = todaysEntries[index];
                    final status = attendanceProvider.getStatus(entry.id, today);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(entry.subjectName),
                        subtitle: Text(
                          '${entry.type.name.toUpperCase()} • ${entry.startTime.format(context)} - ${entry.endTime.format(context)}',
                        ),
                        trailing: _buildStatusIcon(status),
                        onTap: () => _showAttendanceDialog(context, entry, today),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(AttendanceStatus? status) {
    if (status == null) return const Icon(Icons.check_box_outline_blank);
    switch (status) {
      case AttendanceStatus.present:
        return const Icon(Icons.check_circle, color: Colors.green);
      case AttendanceStatus.absent:
        return const Icon(Icons.cancel, color: Colors.red);
      case AttendanceStatus.cancelled:
        return const Icon(Icons.remove_circle, color: Colors.grey);
    }
  }

  void _showAttendanceDialog(BuildContext context, TimeTableEntry entry, DateTime date) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Mark Attendance for ${entry.subjectName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Present'),
                onTap: () {
                  Provider.of<AttendanceProvider>(context, listen: false)
                      .markAttendance(entry.id, date, AttendanceStatus.present);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Absent'),
                onTap: () {
                  Provider.of<AttendanceProvider>(context, listen: false)
                      .markAttendance(entry.id, date, AttendanceStatus.absent);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle, color: Colors.grey),
                title: const Text('Cancelled'),
                onTap: () {
                  Provider.of<AttendanceProvider>(context, listen: false)
                      .markAttendance(entry.id, date, AttendanceStatus.cancelled);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
