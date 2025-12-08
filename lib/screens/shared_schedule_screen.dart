import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/timetable.dart';
import '../models/module.dart';
import '../models/timetable_entry.dart';
import '../models/enums.dart';
import '../providers/timetable_provider.dart';
import '../providers/module_provider.dart';

class SharedScheduleScreen extends StatefulWidget {
  final Timetable importedTimetable;
  final List<Module> modules;
  final List<TimeTableEntry> classes;

  const SharedScheduleScreen({
    super.key,
    required this.importedTimetable,
    required this.modules,
    required this.classes,
  });

  @override
  State<SharedScheduleScreen> createState() => _SharedScheduleScreenState();
}

class _SharedScheduleScreenState extends State<SharedScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getDayName(int day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (day < 1 || day > 7) return 'Unknown';
    return days[day - 1];
  }

  Future<void> _importSchedule() async {
    setState(() => _isSaving = true);
    final timetableProvider = Provider.of<TimetableProvider>(context, listen: false);
    final moduleProvider = Provider.of<ModuleProvider>(context, listen: false);

    try {
      // 1. Create the new timetable
      // We generate a fresh ID to ensure it's treated as a new entity for this user
      final newTimetableId = const Uuid().v4();
      final newTimetable = widget.importedTimetable.copyWith(
        id: newTimetableId,
        isCurrent: true, // Automatically switch to this new timetable
      );
      
      await timetableProvider.addTimetable(newTimetable);

      // 2. Import Modules
      // We blindly add/update modules. Conflicts (same code) will overwrite, which is expected behavior for syncing/sharing.
      for (var module in widget.modules) {
        await moduleProvider.addModule(module);
      }

      // 3. Import Classes
      // We must re-link these classes to the NEW timetable ID
      for (var entry in widget.classes) {
        // Create a copy of the entry but pointing to the new timetable
        // We also need fresh IDs for the entries themselves to avoid colliding with anything weird
        // (though usually they come with UUIDs, it's safer to re-gen or respect existing if sure unique)
        // Let's re-gen ID to be safe and purely local.
        final newEntry = TimeTableEntry(
          id: const Uuid().v4(),
          subjectName: entry.subjectName,
          type: entry.type,
          dayOfWeek: entry.dayOfWeek,
          startTimeHour: entry.startTimeHour,
          startTimeMinute: entry.startTimeMinute,
          endTimeHour: entry.endTimeHour,
          endTimeMinute: entry.endTimeMinute,
          location: entry.location,
          sessionMode: entry.sessionMode,
          moduleCode: entry.moduleCode,
          timetableId: newTimetableId, // Link to the new timetable
        );
        
        await timetableProvider.addEntry(newEntry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timetable imported successfully!')),
        );
        // Pop back to home (SharedScheduleScreen replaced Scanner, so just one pop needed)
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving timetable: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Shared Schedule'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Modules'),
            Tab(text: 'Classes'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.importedTimetable.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${dateFormat.format(widget.importedTimetable.startDate)} - ${dateFormat.format(widget.importedTimetable.endDate)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(label: Text('${widget.modules.length} Modules')),
                    const SizedBox(width: 8),
                    Chip(label: Text('${widget.classes.length} Classes')),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Modules List
                ListView.builder(
                  itemCount: widget.modules.length,
                  itemBuilder: (context, index) {
                    final module = widget.modules[index];
                    return ListTile(
                      title: Text('${module.code} - ${module.name}'),
                      subtitle: Text('${module.credits} credits • ${module.lecturerName}'),
                    );
                  },
                ),
                
                // Classes List
                ListView.builder(
                  itemCount: widget.classes.length,
                  itemBuilder: (context, index) {
                    final entry = widget.classes[index];
                    return ListTile(
                      title: Text(entry.moduleCode != null ? '${entry.moduleCode} - ${entry.subjectName}' : entry.subjectName),
                      subtitle: Text(
                        '${_getDayName(entry.dayOfWeek)} • ${entry.startTime.format(context)} - ${entry.endTime.format(context)}\n${entry.location ?? "No Location"}',
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Chip(label: Text(entry.type.name), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(entry.mode.name), 
                            padding: EdgeInsets.zero, 
                            visualDensity: VisualDensity.compact,
                            backgroundColor: entry.mode == SessionMode.online ? Colors.green.withOpacity(0.2) : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Action Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _importSchedule,
                icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download),
                label: Text(_isSaving ? 'Importing...' : 'Approve & Import Schedule'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
