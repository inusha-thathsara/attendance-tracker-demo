import 'package:cloud_firestore/cloud_firestore.dart';

class Timetable {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;

  Timetable({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isCurrent = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isCurrent': isCurrent,
    };
  }

  factory Timetable.fromMap(Map<String, dynamic> map, String id) {
    return Timetable(
      id: id,
      name: map['name'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isCurrent: map['isCurrent'] ?? false,
    );
  }
}
