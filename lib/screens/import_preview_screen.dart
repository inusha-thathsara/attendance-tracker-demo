import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/pdf_parser_service.dart';
import '../services/firestore_service.dart';
import '../models/timetable_entry.dart';
import '../models/module.dart';
import '../models/enums.dart';
import '../models/timetable.dart';
import '../providers/timetable_provider.dart';
import '../providers/module_provider.dart';
import '../firebase_options.dart';
import 'package:uuid/uuid.dart';

class ImportPreviewScreen extends StatefulWidget {
  const ImportPreviewScreen({super.key});

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> with SingleTickerProviderStateMixin {
  final _parserService = PdfParserService();
  final _firestoreService = FirestoreService();
  List<TimeTableEntry> _parsedClasses = [];
  List<Module> _parsedModules = [];
  bool _isLoading = false;
  List<String> _apiKeys = [];
  late TabController _tabController;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    

    // Listen to auth state changes to handle web refresh or initial load
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _loadUserApiKeys(user.uid);
      }
    });
  }

  Future<void> _loadUserApiKeys([String? uid]) async {
    try {
      final keys = await _firestoreService.getApiKeys(uid);
      if (mounted) {
        setState(() {
          _apiKeys = keys;
        });
      }
    } catch (e) {
      debugPrint('Error loading API keys: $e');
    }
  }

  Future<void> _saveUserApiKeys(List<String> keys) async {
    await _firestoreService.saveApiKeys(keys);
    if (mounted) {
      setState(() {
        _apiKeys = keys;
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickAndParse() async {
    if (_apiKeys.isEmpty) {
      _showApiKeyDialog();
      return;
    }

    try {
      final fileResult = await _parserService.pickTimetableFile();
      if (fileResult == null) return;

      setState(() {
        _isLoading = true;
      });

      String mimeType = 'application/pdf';
      if (['jpg', 'jpeg'].contains(fileResult.extension)) {
        mimeType = 'image/jpeg';
      } else if (fileResult.extension == 'png') {
        mimeType = 'image/png';
      }

      final parsedData = await _parserService.parseFile(fileResult.bytes, _apiKeys, mimeType);
      
      if (mounted) {
        if (parsedData != null) {
          setState(() {
            _parsedModules = parsedData.modules;
            _parsedClasses = parsedData.classes;
          });
          if (_parsedModules.isEmpty && _parsedClasses.isEmpty) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No data found in file')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            action: SnackBarAction(
              label: 'Manage Keys',
              onPressed: () => _showApiKeyDialog(),
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showApiKeyDialog() {
    final newKeyController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('API Key Settings'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add multiple Gemini API keys. The app will automatically rotate through them if one fails (e.g. rate limit).'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newKeyController,
                          decoration: const InputDecoration(
                            labelText: 'New API Key',
                            border: OutlineInputBorder(),
                            hintText: 'AIza...',
                            isDense: true,
                          ),
                          obscureText: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (newKeyController.text.isNotEmpty) {
                            setStateDialog(() {
                              _apiKeys.add(newKeyController.text.trim());
                              newKeyController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Active Keys:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_apiKeys.isEmpty)
                    const Text('No keys added yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _apiKeys.length,
                      itemBuilder: (context, index) {
                        final key = _apiKeys[index];
                        final maskedKey = key.length > 8 
                            ? '${key.substring(0, 4)}...${key.substring(key.length - 4)}' 
                            : '***';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(maskedKey, style: const TextStyle(fontFamily: 'monospace')),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () {
                              setStateDialog(() {
                                _apiKeys.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
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
                  _saveUserApiKeys(_apiKeys);
                  Navigator.pop(context);
                },
                child: const Text('Save Keys'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _saveAll() async {
    final timetableProvider = Provider.of<TimetableProvider>(context, listen: false);
    final moduleProvider = Provider.of<ModuleProvider>(context, listen: false);

    // For imported modules, we need to be careful not to overwrite existing ones seamlessly?
    // Or just add them. addModule writes to Firestore.
    for (var module in _parsedModules) {
      await moduleProvider.addModule(module);
    }

    for (var entry in _parsedClasses) {
      // If we created a new timetable above, the current ID in provider is updated.
      // But entries might need to be linked to THAT id.
      // addEntry uses _currentTimetableId.
      await timetableProvider.addEntry(entry);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${_parsedModules.length} modules and ${_parsedClasses.length} classes')),
      );
    }
  }

  void _editModule(int index) {
    final module = _parsedModules[index];
    final codeController = TextEditingController(text: module.code);
    final nameController = TextEditingController(text: module.name);
    final creditsController = TextEditingController(text: module.credits.toString());
    final lecturerController = TextEditingController(text: module.lecturerName);
    final noteController = TextEditingController(text: module.note);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Module'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Code')),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: creditsController, decoration: const InputDecoration(labelText: 'Credits'), keyboardType: TextInputType.number),
              TextField(controller: lecturerController, decoration: const InputDecoration(labelText: 'Lecturer')),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _parsedModules[index] = Module(
                  code: codeController.text,
                  name: nameController.text,
                  credits: double.tryParse(creditsController.text) ?? 0,
                  lecturerName: lecturerController.text,
                  note: noteController.text,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editClass(int index) {
    final entry = _parsedClasses[index];
    final subjectController = TextEditingController(text: entry.subjectName);
    final locationController = TextEditingController(text: entry.location);
    final moduleCodeController = TextEditingController(text: entry.moduleCode);
    
    EntryType selectedType = entry.type;
    int selectedDay = entry.dayOfWeek;
    TimeOfDay startTime = entry.startTime;
    TimeOfDay endTime = entry.endTime;
    SessionMode selectedMode = entry.mode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Edit Class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: subjectController, decoration: const InputDecoration(labelText: 'Subject')),
                TextField(controller: moduleCodeController, decoration: const InputDecoration(labelText: 'Module Code')),
                DropdownButtonFormField<EntryType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: EntryType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                  onChanged: (v) => setStateDialog(() => selectedType = v!),
                ),
                DropdownButtonFormField<int>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text(_getDayName(i + 1)))).toList(),
                  onChanged: (v) => setStateDialog(() => selectedDay = v!),
                ),
                ListTile(
                  title: Text('Start: ${startTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: startTime);
                    if (t != null) setStateDialog(() => startTime = t);
                  },
                ),
                ListTile(
                  title: Text('End: ${endTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: endTime);
                    if (t != null) setStateDialog(() => endTime = t);
                  },
                ),
                TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
                DropdownButtonFormField<SessionMode>(
                  value: selectedMode,
                  decoration: const InputDecoration(labelText: 'Mode'),
                  items: SessionMode.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                  onChanged: (v) => setStateDialog(() => selectedMode = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _parsedClasses[index] = TimeTableEntry(
                    id: entry.id,
                    subjectName: subjectController.text,
                    type: selectedType,
                    dayOfWeek: selectedDay,
                    startTimeHour: startTime.hour,
                    startTimeMinute: startTime.minute,
                    endTimeHour: endTime.hour,
                    endTimeMinute: endTime.minute,
                    location: locationController.text,
                    sessionMode: selectedMode,
                    moduleCode: moduleCodeController.text,
                    timetableId: entry.timetableId,
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayName(int day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[day - 1];
  }

  bool _hasConflicts(TimeTableEntry entry) {
    for (var other in _parsedClasses) {
      if (other == entry) continue;
      if (other.dayOfWeek != entry.dayOfWeek) continue;
      if (other.moduleCode == entry.moduleCode) continue; // Same module overlap is merged, not a conflict

      final start1 = entry.startTimeHour * 60 + entry.startTimeMinute;
      final end1 = entry.endTimeHour * 60 + entry.endTimeMinute;
      final start2 = other.startTimeHour * 60 + other.startTimeMinute;
      final end2 = other.endTimeHour * 60 + other.endTimeMinute;

      if (start1 < end2 && start2 < end1) {
        return true;
      }
    }
    return false;
  }

  Future<void> _deleteModule(int index) async {
    final module = _parsedModules[index];
    final associatedClasses = _parsedClasses.where((c) => c.moduleCode == module.code).length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module?'),
        content: Text('Are you sure you want to delete "${module.name}"?\n\nThis will also delete $associatedClasses associated classes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _parsedModules.removeAt(index);
        _parsedClasses.removeWhere((c) => c.moduleCode == module.code);
      });
    }
  }

  Future<void> _deleteClass(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class?'),
        content: const Text('Are you sure you want to delete this class?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _parsedClasses.removeAt(index);
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_parsedModules.isEmpty && _parsedClasses.isEmpty) return true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved imported data. Are you sure you want to leave?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Import Timetable (AI)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'API Key Settings',
              onPressed: _showApiKeyDialog,
            ),
          ],
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
            if (_parsedModules.isEmpty && _parsedClasses.isEmpty && !_isLoading)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'AI-generated results may be inaccurate. Please carefully review all extracted data before approving.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickAndParse,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Select File & Parse with AI'),
                    ),
                  ],
                ),
              ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'Analyzing file... Estimated time: 1-3 minutes (depends on file size)',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Modules Tab
                  ListView.builder(
                    itemCount: _parsedModules.length,
                    itemBuilder: (context, index) {
                      final module = _parsedModules[index];
                      return ListTile(
                        title: Text('${module.code} - ${module.name}'),
                        subtitle: Text('${module.credits} credits • ${module.lecturerName}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editModule(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteModule(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Classes Tab
                  ListView.builder(
                    itemCount: _parsedClasses.length,
                    itemBuilder: (context, index) {
                      final entry = _parsedClasses[index];
                      final hasConflict = _hasConflicts(entry);
                      return ListTile(
                        tileColor: hasConflict ? Colors.red.withOpacity(0.1) : null,
                        leading: hasConflict ? const Icon(Icons.warning, color: Colors.red) : null,
                        title: Text('${entry.moduleCode} - ${entry.subjectName}'),
                        subtitle: Text('${entry.type.name} • ${_getDayName(entry.dayOfWeek)} ${entry.startTime.format(context)} - ${entry.endTime.format(context)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editClass(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteClass(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (_parsedModules.isNotEmpty || _parsedClasses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _saveAll,
                  child: const Text('Approve & Save All'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
