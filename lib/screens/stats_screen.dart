import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/timetable_provider.dart';
import '../models/enums.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  double _targetPercentage = 0.8; // Default 80%
  String _sortBy = 'name'; // 'name' or 'percentage'
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final timetableProvider = Provider.of<TimetableProvider>(context);
    
    // Calculate stats
    final Map<String, Map<String, dynamic>> stats = {}; // Subject -> {Present: 0, Absent: 0, Code: ''}

    for (var record in attendanceProvider.records) {
      try {
        final entry = timetableProvider.entries.firstWhere((e) => e.id == record.timetableEntryId);
        
        // Only consider physical sessions
        if (entry.mode != SessionMode.physical) continue;

        final subject = entry.subjectName;
        
        if (!stats.containsKey(subject)) {
          stats[subject] = {
            'Present': 0, 
            'Absent': 0, 
            'Cancelled': 0,
            'Code': entry.moduleCode ?? ''
          };
        }
        
        if (record.status == AttendanceStatus.present) {
          stats[subject]!['Present'] = (stats[subject]!['Present'] as int) + 1;
        } else if (record.status == AttendanceStatus.absent) {
          stats[subject]!['Absent'] = (stats[subject]!['Absent'] as int) + 1;
        } else {
           stats[subject]!['Cancelled'] = (stats[subject]!['Cancelled'] as int) + 1;
        }
      } catch (e) {
        continue;
      }
    }

    // Sort stats
    final sortedKeys = stats.keys.toList();
    sortedKeys.sort((a, b) {
      if (_sortBy == 'name') {
        return _sortAscending ? a.compareTo(b) : b.compareTo(a);
      } else if (_sortBy == 'code') {
        final codeA = stats[a]!['Code'] as String;
        final codeB = stats[b]!['Code'] as String;
        return _sortAscending ? codeA.compareTo(codeB) : codeB.compareTo(codeA);
      } else {
        final statsA = stats[a]!;
        final totalA = (statsA['Present'] as int) + (statsA['Absent'] as int);
        final pctA = totalA == 0 ? 0.0 : (statsA['Present'] as int) / totalA;
        
        final statsB = stats[b]!;
        final totalB = (statsB['Present'] as int) + (statsB['Absent'] as int);
        final pctB = totalB == 0 ? 0.0 : (statsB['Present'] as int) / totalB;
        
        return _sortAscending ? pctA.compareTo(pctB) : pctB.compareTo(pctA);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = true;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    const Text('Name'),
                    if (_sortBy == 'name')
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'percentage',
                child: Row(
                  children: [
                    const Text('Percentage'),
                    if (_sortBy == 'percentage')
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'code',
                child: Row(
                  children: [
                    const Text('Code'),
                    if (_sortBy == 'code')
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Target Slider Section
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Target Attendance", style: Theme.of(context).textTheme.titleMedium),
                    Text("${(_targetPercentage * 100).toInt()}%", 
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ],
                ),
                Slider(
                  value: _targetPercentage,
                  min: 0.5,
                  max: 1.0,
                  divisions: 10,
                  label: "${(_targetPercentage * 100).toInt()}%",
                  onChanged: (val) => setState(() => _targetPercentage = val),
                ),
                const Text(
                  "Adjust to see how many classes you can skip or need to attend.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          // Stats List
          Expanded(
            child: stats.isEmpty 
              ? const Center(child: Text('No attendance records yet.'))
              : ListView.builder(
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final subject = sortedKeys[index];
                    final data = stats[subject]!;
                    final present = data['Present'] as int;
                    final absent = data['Absent'] as int;
                    final code = data['Code'] as String;
                    final total = present + absent;
                    final percentage = total == 0 ? 0.0 : (present / total);

                    // Calculator Logic
                    String adviceText = "";
                    Color adviceColor = Colors.grey;
                    
                    if (total > 0) {
                      if (_targetPercentage == 1.0) {
                        if (absent > 0) {
                          adviceText = "Target 100% is no longer possible (missed $absent).";
                          adviceColor = Colors.red;
                        } else {
                          adviceText = "Don't miss any classes to maintain 100%.";
                          adviceColor = Colors.green;
                        }
                      } else if (percentage >= _targetPercentage) {
                        // Safe to skip
                        // Formula: floor(P/T - N)
                        int safeToSkip = ((present / _targetPercentage) - total).floor();
                        if (safeToSkip > 1) {
                          adviceText = "You can safely skip the next $safeToSkip classes.";
                          adviceColor = Colors.green;
                        } else if (safeToSkip == 1) {
                          adviceText = "You can safely skip the next 1 class.";
                          adviceColor = Colors.green;
                        } else {
                          adviceText = "You are on track, but don't skip the next class.";
                          adviceColor = Colors.green.shade700;
                        }
                      } else {
                        // Need to attend
                        // Formula: ceil((TN - P) / (1 - T))
                        int needToAttend = ((_targetPercentage * total - present) / (1 - _targetPercentage)).ceil();
                        if (needToAttend > 0) {
                          adviceText = "Attend next $needToAttend class${needToAttend > 1 ? 'es' : ''} to reach target.";
                          adviceColor = Colors.orange.shade800;
                        } else {
                           adviceText = "You are just below target.";
                           adviceColor = Colors.orange;
                        }
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              code.isNotEmpty ? "$code - $subject" : subject,
                              style: Theme.of(context).textTheme.titleLarge
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: total == 0 ? 0 : percentage,
                              backgroundColor: Colors.red.shade100,
                              color: percentage >= _targetPercentage ? Colors.green : Colors.red,
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Present: $present', style: const TextStyle(color: Colors.green)),
                                Text('Absent: $absent', style: const TextStyle(color: Colors.red)),
                                Text('${(percentage * 100).toStringAsFixed(1)}%', 
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: percentage >= _targetPercentage ? Colors.green : Colors.red
                                  )
                                ),
                              ],
                            ),
                            if (total > 0) ...[
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Icon(
                                    percentage >= _targetPercentage ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                    size: 16,
                                    color: adviceColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      adviceText,
                                      style: TextStyle(
                                        color: adviceColor,
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FontStyle.italic
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
