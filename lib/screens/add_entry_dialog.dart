
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/timetable_entry.dart';
import '../models/enums.dart';
import '../providers/timetable_provider.dart';
import '../providers/module_provider.dart';

class AddEntryDialog extends StatefulWidget {
  final TimeTableEntry? entry;

  const AddEntryDialog({super.key, this.entry});

  @override
  State<AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<AddEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  String _subjectName = '';
  String? _moduleCode;
  EntryType _type = EntryType.lecture;
  SessionMode _mode = SessionMode.physical;
  int _dayOfWeek = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  String? _location;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _subjectName = widget.entry!.subjectName;
      _moduleCode = widget.entry!.moduleCode;
      _type = widget.entry!.type;
      _mode = widget.entry!.mode;
      _dayOfWeek = widget.entry!.dayOfWeek;
      _startTime = widget.entry!.startTime;
      _endTime = widget.entry!.endTime;
      _location = widget.entry!.location;
    }
  }

  @override
  Widget build(BuildContext context) {
    final moduleProvider = Provider.of<ModuleProvider>(context);
    final modules = moduleProvider.modules;

    return AlertDialog(
      title: Text(widget.entry == null ? 'Add Class' : 'Edit Class'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _moduleCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Module'),
                items: modules.map((m) => DropdownMenuItem(
                  value: m.code,
                  child: Text(
                    '${m.code} - ${m.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _moduleCode = value;
                    final module = modules.firstWhere((m) => m.code == value);
                    _subjectName = module.name;
                  });
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              DropdownButtonFormField<EntryType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: EntryType.values.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e.name.toUpperCase()),
                )).toList(),
                onChanged: (value) => setState(() => _type = value!),
              ),
              DropdownButtonFormField<SessionMode>(
                value: _mode,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: SessionMode.values.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e.name.toUpperCase()),
                )).toList(),
                onChanged: (value) => setState(() => _mode = value!),
              ),
              if (_mode == SessionMode.physical)
                TextFormField(
                  initialValue: _location,
                  decoration: const InputDecoration(labelText: 'Venue'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                  onSaved: (value) => _location = value,
                ),
              DropdownButtonFormField<int>(
                value: _dayOfWeek,
                decoration: const InputDecoration(labelText: 'Day'),
                items: List.generate(7, (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index]),
                )),
                onChanged: (value) => setState(() => _dayOfWeek = value!),
              ),
              ListTile(
                title: const Text('Start Time'),
                trailing: Text(_startTime.format(context)),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _startTime);
                  if (t != null) setState(() => _startTime = t);
                },
              ),
              ListTile(
                title: const Text('End Time'),
                trailing: Text(_endTime.format(context)),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _endTime);
                  if (t != null) setState(() => _endTime = t);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();

              // Check for conflicts
              final conflict = _checkForConflict(context);
              if (conflict != null) {
                final proceed = await _showConflictDialog(context, conflict);
                if (!proceed) return;
              }

              final entry = TimeTableEntry(
                id: widget.entry?.id ?? const Uuid().v4(),
                subjectName: _subjectName,
                type: _type,
                dayOfWeek: _dayOfWeek,
                startTimeHour: _startTime.hour,
                startTimeMinute: _startTime.minute,
                endTimeHour: _endTime.hour,
                endTimeMinute: _endTime.minute,
                location: _location,
                moduleCode: _moduleCode,
                sessionMode: _mode,
                timetableId: widget.entry?.timetableId,
              );
              
              if (context.mounted) {
                if (widget.entry != null) {
                  Provider.of<TimetableProvider>(context, listen: false)
                      .updateEntry(entry);
                } else {
                  Provider.of<TimetableProvider>(context, listen: false).addEntry(entry);
                }
                Navigator.pop(context);
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  TimeTableEntry? _checkForConflict(BuildContext context) {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final entries = provider.entries;
    
    final newStartMinutes = _startTime.hour * 60 + _startTime.minute;
    final newEndMinutes = _endTime.hour * 60 + _endTime.minute;

    for (var entry in entries) {
      // Skip if it's the same entry we are editing
      if (widget.entry != null && entry.id == widget.entry!.id) continue;

      // Check day
      if (entry.dayOfWeek != _dayOfWeek) continue;

      // Check time overlap
      final startMinutes = entry.startTimeHour * 60 + entry.startTimeMinute;
      final endMinutes = entry.endTimeHour * 60 + entry.endTimeMinute;

      if (startMinutes < newEndMinutes && endMinutes > newStartMinutes) {
        return entry;
      }
    }
    return null;
  }

  Future<bool> _showConflictDialog(BuildContext context, TimeTableEntry conflict) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Time Conflict'),
        content: Text(
          'This class overlaps with "${conflict.subjectName}" (${_formatTime(conflict.startTimeHour, conflict.startTimeMinute)} - ${_formatTime(conflict.endTimeHour, conflict.endTimeMinute)}).\n\nDo you want to save anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save Anyway'),
          ),
        ],
      ),
    ) ?? false;
  }

  String _formatTime(int hour, int minute) {
    final time = TimeOfDay(hour: hour, minute: minute);
    return time.format(context);
  }
}
