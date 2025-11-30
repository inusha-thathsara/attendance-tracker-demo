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
              if (modules.isNotEmpty)
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
                )
              else
                TextFormField(
                  initialValue: _subjectName,
                  decoration: const InputDecoration(labelText: 'Subject Name'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                  onSaved: (value) => _subjectName = value!,
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
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
              
              if (widget.entry != null) {
                Provider.of<TimetableProvider>(context, listen: false)
                    .updateEntry(entry);
              } else {
                Provider.of<TimetableProvider>(context, listen: false).addEntry(entry);
              }
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
