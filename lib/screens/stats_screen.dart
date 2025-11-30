import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/timetable_provider.dart';
import '../models/enums.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final timetableProvider = Provider.of<TimetableProvider>(context);
    
    // Calculate stats
    // We need to group records by subject name (from timetable entry)
    // This is inefficient but works for small data
    final Map<String, Map<String, int>> stats = {}; // Subject -> {Present: 0, Absent: 0}

    for (var record in attendanceProvider.records) {
      // Find subject name
      // This is slow, O(N*M). Better to have a map or store subject name in record.
      // But for personal use it's fine.
      try {
        final entry = timetableProvider.entries.firstWhere((e) => e.id == record.timetableEntryId);
        
        // Only consider physical sessions
        if (entry.mode != SessionMode.physical) continue;

        final subject = entry.subjectName;
        
        if (!stats.containsKey(subject)) {
          stats[subject] = {'Present': 0, 'Absent': 0, 'Cancelled': 0};
        }
        
        if (record.status == AttendanceStatus.present) {
          stats[subject]!['Present'] = stats[subject]!['Present']! + 1;
        } else if (record.status == AttendanceStatus.absent) {
          stats[subject]!['Absent'] = stats[subject]!['Absent']! + 1;
        } else {
           stats[subject]!['Cancelled'] = stats[subject]!['Cancelled']! + 1;
        }
      } catch (e) {
        // Entry might have been deleted
        continue;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: stats.isEmpty 
        ? const Center(child: Text('No attendance records yet.'))
        : ListView.builder(
            itemCount: stats.length,
            itemBuilder: (context, index) {
              final subject = stats.keys.elementAt(index);
              final data = stats[subject]!;
              final present = data['Present']!;
              final absent = data['Absent']!;
              final total = present + absent;
              final percentage = total == 0 ? 0.0 : (present / total * 100);

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: total == 0 ? 0 : present / total,
                        backgroundColor: Colors.red.shade100,
                        color: Colors.green,
                        minHeight: 10,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Present: $present', style: const TextStyle(color: Colors.green)),
                          Text('Absent: $absent', style: const TextStyle(color: Colors.red)),
                          Text('${percentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
