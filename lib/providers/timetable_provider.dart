import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/timetable_entry.dart';
import '../models/timetable.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class TimetableProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  
  List<TimeTableEntry> _entries = [];
  List<Timetable> _timetables = [];
  String? _currentTimetableId;
  
  StreamSubscription<List<TimeTableEntry>>? _entriesSubscription;
  StreamSubscription<List<Timetable>>? _timetablesSubscription;

  List<TimeTableEntry> get entries => _entries;
  List<Timetable> get timetables => _timetables;
  
  Timetable? get currentTimetable {
    if (_currentTimetableId == null) return null;
    try {
      return _timetables.firstWhere((t) => t.id == _currentTimetableId);
    } catch (_) {
      return null;
    }
  }

  TimetableProvider() {
    _init();
  }

  void _init() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _entriesSubscription?.cancel();
      _timetablesSubscription?.cancel();
      
      if (user != null) {
        // Listen to timetables
        _timetablesSubscription = _firestoreService.getTimetablesStream(user.uid).listen((timetables) {
          _timetables = timetables;
          
          // Determine current timetable
          if (_currentTimetableId == null && timetables.isNotEmpty) {
             // Try to find one marked as current
             final current = timetables.where((t) => t.isCurrent).firstOrNull;
             _currentTimetableId = current?.id ?? timetables.first.id;
          } else if (_currentTimetableId != null && !timetables.any((t) => t.id == _currentTimetableId)) {
            // Current was deleted
            _currentTimetableId = timetables.isNotEmpty ? timetables.first.id : null;
          }
          
          _subscribeToEntries(user.uid);
          notifyListeners();
        });
      } else {
        _entries = [];
        _timetables = [];
        _currentTimetableId = null;
        _notificationService.cancelAllNotifications();
        notifyListeners();
      }
    });
  }

  void _subscribeToEntries(String uid) {
    _entriesSubscription?.cancel();
    _entriesSubscription = _firestoreService.getTimetableStream(_currentTimetableId, uid).listen((entries) {
      _entries = entries;
      _rescheduleAllNotifications();
      notifyListeners();
    });
  }

  Future<void> _rescheduleAllNotifications() async {
    await _notificationService.cancelAllNotifications();
    for (var entry in _entries) {
      await _notificationService.scheduleClassNotification(entry);
    }
  }

  void setCurrentTimetable(String id) {
    if (_currentTimetableId != id) {
      _currentTimetableId = id;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _subscribeToEntries(user.uid);
      }
      notifyListeners();
    }
  }

  Future<void> addTimetable(Timetable timetable) async {
    await _firestoreService.addTimetable(timetable);
    // If it's the first one or marked current, switch to it
    if (_timetables.isEmpty || timetable.isCurrent) {
      setCurrentTimetable(timetable.id);
    }
  }

  Future<void> updateTimetable(Timetable timetable) async {
    await _firestoreService.updateTimetable(timetable);
    if (timetable.isCurrent) {
      setCurrentTimetable(timetable.id);
    }
  }

  Future<void> deleteTimetable(String id) async {
    await _firestoreService.deleteTimetable(id);
  }

  @override
  void dispose() {
    _entriesSubscription?.cancel();
    _timetablesSubscription?.cancel();
    super.dispose();
  }

  Future<void> addEntry(TimeTableEntry entry) async {
    // Ensure entry is linked to current timetable
    final entryWithTimetable = TimeTableEntry(
      id: entry.id,
      subjectName: entry.subjectName,
      type: entry.type,
      dayOfWeek: entry.dayOfWeek,
      startTimeHour: entry.startTimeHour,
      startTimeMinute: entry.startTimeMinute,
      endTimeHour: entry.endTimeHour,
      endTimeMinute: entry.endTimeMinute,
      location: entry.location,
      sessionMode: entry.sessionMode,
      moduleCode: entry.moduleCode,
      timetableId: _currentTimetableId,
    );
    await _firestoreService.addTimeTableEntry(entryWithTimetable);
    // Notification will be handled by the stream listener
  }

  Future<void> updateEntry(TimeTableEntry entry) async {
    await _firestoreService.updateTimeTableEntry(entry);
    // Notification will be handled by the stream listener
  }

  Future<void> deleteEntry(String id) async {
    await _firestoreService.deleteTimeTableEntry(id);
    await _notificationService.cancelNotification(id);
  }

  Future<void> deleteEntriesByModule(String moduleCode) async {
    final entriesToDelete = _entries.where((e) => e.moduleCode == moduleCode).toList();
    for (var entry in entriesToDelete) {
      await deleteEntry(entry.id);
    }
  }

  List<TimeTableEntry> getEntriesForDay(int dayOfWeek) {
    return _entries.where((e) => e.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) {
        if (a.startTimeHour != b.startTimeHour) {
          return a.startTimeHour.compareTo(b.startTimeHour);
        }
        return a.startTimeMinute.compareTo(b.startTimeMinute);
      });
  }
}
