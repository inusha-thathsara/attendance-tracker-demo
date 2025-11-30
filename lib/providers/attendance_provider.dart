import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/attendance_record.dart';
import '../models/enums.dart';
import '../services/firestore_service.dart';

class AttendanceProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<AttendanceRecord> _records = [];
  StreamSubscription<List<AttendanceRecord>>? _subscription;

  List<AttendanceRecord> get records => _records;

  AttendanceProvider() {
    _init();
  }

  void _init() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _subscription?.cancel();
      if (user != null) {
        _subscription = _firestoreService.getAttendanceStream(user.uid).listen((records) {
          _records = records;
          notifyListeners();
        });
      } else {
        _records = [];
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> markAttendance(String timetableEntryId, DateTime date, AttendanceStatus status) async {
    // Check if record exists for this entry and date
    final existingIndex = _records.indexWhere((r) => 
      r.timetableEntryId == timetableEntryId && 
      isSameDay(r.date, date)
    );

    if (existingIndex != -1) {
      // Update existing
      final existingRecord = _records[existingIndex];
      final newRecord = AttendanceRecord(
        id: existingRecord.id,
        timetableEntryId: timetableEntryId,
        date: date,
        status: status,
      );
      await _firestoreService.addAttendanceRecord(newRecord); // add works as set (upsert)
    } else {
      // Create new
      final newRecord = AttendanceRecord(
        id: const Uuid().v4(),
        timetableEntryId: timetableEntryId,
        date: date,
        status: status,
      );
      await _firestoreService.addAttendanceRecord(newRecord);
    }
  }

  AttendanceStatus? getStatus(String timetableEntryId, DateTime date) {
    try {
      final record = _records.firstWhere((r) => 
        r.timetableEntryId == timetableEntryId && 
        isSameDay(r.date, date)
      );
      return record.status;
    } catch (e) {
      return null;
    }
  }

  bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
  
  Map<String, double> getAttendanceStats() {
    return {};
  }
}
