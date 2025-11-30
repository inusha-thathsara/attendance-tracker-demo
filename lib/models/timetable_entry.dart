import 'package:flutter/material.dart';
import 'enums.dart';

class TimeTableEntry {
  final String id;
  final String subjectName;
  final EntryType type;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final int startTimeHour;
  final int startTimeMinute;
  final int endTimeHour;
  final int endTimeMinute;
  final String? location;
  final SessionMode? sessionMode;
  final String? moduleCode;
  final String? timetableId;

  SessionMode get mode => sessionMode ?? SessionMode.physical;

  TimeTableEntry({
    required this.id,
    required this.subjectName,
    required this.type,
    required this.dayOfWeek,
    required this.startTimeHour,
    required this.startTimeMinute,
    required this.endTimeHour,
    required this.endTimeMinute,
    this.location,
    this.sessionMode,
    this.moduleCode,
    this.timetableId,
  });

  // Firestore Serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectName': subjectName,
      'dayOfWeek': dayOfWeek,
      'startTimeHour': startTimeHour,
      'startTimeMinute': startTimeMinute,
      'endTimeHour': endTimeHour,
      'endTimeMinute': endTimeMinute,
      'type': type.name,
      'location': location,
      'sessionMode': sessionMode?.index ?? SessionMode.physical.index,
      'moduleCode': moduleCode,
      'timetableId': timetableId,
    };
  }

  factory TimeTableEntry.fromMap(Map<String, dynamic> map, String id) {
    return TimeTableEntry(
      id: id,
      subjectName: map['subjectName'] ?? '',
      dayOfWeek: map['dayOfWeek'] ?? 1,
      startTimeHour: map['startTimeHour'] ?? 8,
      startTimeMinute: map['startTimeMinute'] ?? 0,
      endTimeHour: map['endTimeHour'] ?? 9,
      endTimeMinute: map['endTimeMinute'] ?? 0,
      type: EntryType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => EntryType.lecture,
      ),
      location: map['location'],
      sessionMode: map['sessionMode'] != null
          ? SessionMode.values[map['sessionMode']]
          : SessionMode.physical,
      moduleCode: map['moduleCode'],
      timetableId: map['timetableId'],
    );
  }

  TimeOfDay get startTime => TimeOfDay(hour: startTimeHour, minute: startTimeMinute);
  TimeOfDay get endTime => TimeOfDay(hour: endTimeHour, minute: endTimeMinute);
}
