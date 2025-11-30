import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/module.dart';
import '../providers/module_provider.dart';
import '../providers/timetable_provider.dart';
import 'module_detail_screen.dart';

class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ModuleProvider>(context);
    final modules = provider.modules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modules'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddModuleDialog(context),
        child: const Icon(Icons.add),
      ),
      body: modules.isEmpty
          ? const Center(child: Text('No modules added yet.'))
          : ListView.builder(
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                return ListTile(
                  title: Text('${module.code} - ${module.name}'),
                  subtitle: Text('${module.credits} Credits • ${module.lecturerName}'),
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
              },
            ),
    );
  }

  void _showAddModuleDialog(BuildContext context, {Module? module}) {
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
