import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/module.dart';
import '../models/timetable_entry.dart';
import '../providers/module_provider.dart';
import '../providers/timetable_provider.dart';
import '../services/firestore_service.dart';
import 'module_detail_screen.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _expandedTimetableId;

  @override
  Widget build(BuildContext context) {
    final moduleProvider = Provider.of<ModuleProvider>(context);
    final timetableProvider = Provider.of<TimetableProvider>(context);
    final modules = moduleProvider.modules;
    final timetables = timetableProvider.timetables;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modules'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddModuleDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<TimeTableEntry>>(
        stream: _firestoreService.getAllTimetableEntriesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEntries = snapshot.data ?? [];
          
          // Group modules by timetable
          final Map<String, Set<String>> timetableModuleCodes = {}; // TimetableID -> Set<ModuleCode>
          final Set<String> assignedModuleCodes = {};
          final Map<String, Set<String>> moduleTimetableIds = {}; // ModuleCode -> Set<TimetableID>

          for (var entry in allEntries) {
            if (entry.timetableId != null && entry.moduleCode != null) {
              timetableModuleCodes.putIfAbsent(entry.timetableId!, () => {}).add(entry.moduleCode!);
              assignedModuleCodes.add(entry.moduleCode!);
              moduleTimetableIds.putIfAbsent(entry.moduleCode!, () => {}).add(entry.timetableId!);
            }
          }

          // Find unassigned modules
          final unassignedModules = modules.where((m) => !assignedModuleCodes.contains(m.code)).toList();

          final validTimetableIds = timetables.map((t) => t.id).toSet();

          // Find shared modules
          final sharedModuleCodes = moduleTimetableIds.entries
              .where((entry) {
                final validIdsForModule = entry.value.intersection(validTimetableIds);
                return validIdsForModule.length > 1;
              })
              .map((entry) => entry.key)
              .toSet();
          
          final sharedModules = modules.where((m) => sharedModuleCodes.contains(m.code)).toList();

          if (modules.isEmpty) {
            return const Center(child: Text('No modules added yet.'));
          }

          return ListView(
            children: [
              // Shared Group
              if (sharedModules.isNotEmpty)
                _buildAccordionGroup(
                  title: 'Shared',
                  subtitle: '${sharedModules.length} Modules',
                  isExpanded: _expandedTimetableId == 'shared',
                  onTap: () {
                    setState(() {
                      _expandedTimetableId = _expandedTimetableId == 'shared' ? null : 'shared';
                    });
                  },
                  children: sharedModules.map((module) {
                    final timetableIds = moduleTimetableIds[module.code] ?? {};
                    final timetableNames = timetables
                        .where((t) => timetableIds.contains(t.id))
                        .map((t) => t.name)
                        .toList();
                    return _buildModuleTile(context, module, sharedTimetableNames: timetableNames);
                  }).toList(),
                ),

              // Timetable Groups
              ...timetables.map((timetable) {
                final moduleCodes = timetableModuleCodes[timetable.id] ?? {};
                final timetableModules = modules.where((m) => moduleCodes.contains(m.code)).toList();
                
                if (timetableModules.isEmpty) return const SizedBox.shrink();

                final isExpanded = _expandedTimetableId == timetable.id;

                final totalCredits = timetableModules.fold<double>(0, (sum, m) => sum + m.credits);
                final creditString = totalCredits % 1 == 0 ? totalCredits.toInt().toString() : totalCredits.toString();

                return _buildAccordionGroup(
                  title: timetable.name,
                  subtitle: '${timetableModules.length} Modules • $creditString Credits',
                  isExpanded: isExpanded,
                  onTap: () {
                    setState(() {
                      _expandedTimetableId = isExpanded ? null : timetable.id;
                    });
                  },
                  children: timetableModules.map((module) => _buildModuleTile(context, module)).toList(),
                );
              }),

              // Unassigned Group
              if (unassignedModules.isNotEmpty)
                _buildAccordionGroup(
                  title: 'Unassigned',
                  subtitle: '${unassignedModules.length} Modules',
                  isExpanded: _expandedTimetableId == 'unassigned',
                  onTap: () {
                    setState(() {
                      _expandedTimetableId = _expandedTimetableId == 'unassigned' ? null : 'unassigned';
                    });
                  },
                  children: unassignedModules.map((module) => _buildModuleTile(context, module)).toList(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccordionGroup({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 1,
      child: Column(
        children: [
          ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle),
            trailing: AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: const Icon(Icons.expand_more),
            ),
            onTap: onTap,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              child: isExpanded
                  ? Column(children: children)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildModuleTile(BuildContext context, Module module, {List<String>? sharedTimetableNames}) {
    String subtitleText = '${module.credits} Credits • ${module.lecturerName}';
    if (sharedTimetableNames != null && sharedTimetableNames.isNotEmpty) {
      subtitleText += '\nShared in: ${sharedTimetableNames.join(", ")}';
    }

    return ListTile(
      title: Text('${module.code} - ${module.name}'),
      subtitle: Text(subtitleText),
      isThreeLine: sharedTimetableNames != null && sharedTimetableNames.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showAddModuleDialog(context, module: module),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDeleteModule(context, module),
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModuleDetailScreen(module: module),
          ),
        );
      },
    );
  }

  void _showAddModuleDialog(BuildContext context, {Module? module}) {
    final timetableProvider = Provider.of<TimetableProvider>(context, listen: false);
    if (timetableProvider.currentTimetable == null && module == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Please select or create a timetable first'),
            ],
          ),
        ),
      );
      Scaffold.of(context).openDrawer();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AddModuleDialog(module: module),
    );
  }

  Future<void> _confirmDeleteModule(BuildContext context, Module module) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module'),
        content: Text('Are you sure you want to delete ${module.name} (${module.code})?\n\nWARNING: This will also delete all classes associated with this module.'),
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
      // Delete associated classes first
      await Provider.of<TimetableProvider>(context, listen: false).deleteEntriesByModule(module.code);
      // Then delete the module
      if (context.mounted) {
        await Provider.of<ModuleProvider>(context, listen: false).deleteModule(module.code);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Module ${module.code} and associated classes deleted')),
          );
        }
      }
    }
  }
}

class AddModuleDialog extends StatefulWidget {
  final Module? module;

  const AddModuleDialog({super.key, this.module});

  @override
  State<AddModuleDialog> createState() => _AddModuleDialogState();
}

class _AddModuleDialogState extends State<AddModuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _code;
  late String _name;
  late double _credits;
  late String _lecturerName;
  late String _note;

  @override
  void initState() {
    super.initState();
    _code = widget.module?.code ?? '';
    _name = widget.module?.name ?? '';
    _credits = widget.module?.credits ?? 0;
    _lecturerName = widget.module?.lecturerName ?? '';
    _note = widget.module?.note ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.module == null ? 'Add Module' : 'Edit Module'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _code,
                decoration: const InputDecoration(labelText: 'Module Code'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
                onSaved: (value) => _code = value!,
                enabled: widget.module == null, // Code is ID, cannot change
              ),
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Module Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
                onSaved: (value) => _name = value!,
              ),
              TextFormField(
                initialValue: _credits.toString(),
                decoration: const InputDecoration(labelText: 'Credits'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Required' : null,
                onSaved: (value) => _credits = double.tryParse(value!) ?? 0,
              ),
              TextFormField(
                initialValue: _lecturerName,
                decoration: const InputDecoration(labelText: 'Lecturer Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
                onSaved: (value) => _lecturerName = value!,
              ),
              TextFormField(
                initialValue: _note,
                decoration: const InputDecoration(labelText: 'Note (Optional)'),
                maxLines: 3,
                onSaved: (value) => _note = value ?? '',
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
              final module = Module(
                code: _code,
                name: _name,
                credits: _credits,
                lecturerName: _lecturerName,
                note: _note,
              );
              
              Provider.of<ModuleProvider>(context, listen: false).addModule(module);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
