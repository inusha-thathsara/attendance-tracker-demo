import 'enums.dart';

class AttendanceRecord {
  final String id;
  final String timetableEntryId;
  final DateTime date;
  final AttendanceStatus status;

  AttendanceRecord({
    required this.id,
    required this.timetableEntryId,
    required this.date,
    required this.status,
  });

  // Firestore Serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timetableEntryId': timetableEntryId,
      'date': date.toIso8601String(),
      'status': status.index,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceRecord(
      id: id,
      timetableEntryId: map['timetableEntryId'] ?? '',
      date: DateTime.parse(map['date']),
      status: AttendanceStatus.values[map['status'] ?? 0],
    );
  }
}
