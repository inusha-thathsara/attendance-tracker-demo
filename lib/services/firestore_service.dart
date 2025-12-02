import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/timetable_entry.dart';
import '../models/timetable.dart';
import '../models/module.dart';
import '../models/attendance_record.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  // --- Timetable ---

  // --- Timetables ---

  Stream<List<Timetable>> getTimetablesStream([String? uid]) {
    final targetId = uid ?? userId;
    if (targetId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(targetId)
        .collection('timetables')
        .orderBy('startDate')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Timetable.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> addTimetable(Timetable timetable) async {
    if (userId == null) return;
    
    // If setting as current, unset others
    if (timetable.isCurrent) {
      await _unsetCurrentTimetables();
    }

    await _db
        .collection('users')
        .doc(userId)
        .collection('timetables')
        .doc(timetable.id)
        .set(timetable.toMap());
  }

  Future<void> updateTimetable(Timetable timetable) async {
    if (userId == null) return;

    if (timetable.isCurrent) {
      await _unsetCurrentTimetables();
    }

    await _db
        .collection('users')
        .doc(userId)
        .collection('timetables')
        .doc(timetable.id)
        .update(timetable.toMap());
  }

  Future<void> deleteTimetable(String id) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('timetables')
        .doc(id)
        .delete();
        
    // Also delete associated entries? Or keep them orphaned?
    // For now, let's keep them but they won't show up if filtering by ID.
  }

  Future<void> _unsetCurrentTimetables() async {
    if (userId == null) return;
    final batch = _db.batch();
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('timetables')
        .where('isCurrent', isEqualTo: true)
        .get();
    
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isCurrent': false});
    }
    await batch.commit();
  }

  // --- Timetable Entries ---

  Stream<List<TimeTableEntry>> getTimetableStream(String? timetableId, [String? uid]) {
    final targetId = uid ?? userId;
    if (targetId == null) return Stream.value([]);
    
    Query query = _db
        .collection('users')
        .doc(targetId)
        .collection('timetable');

    if (timetableId != null) {
      query = query.where('timetableId', isEqualTo: timetableId);
    } else {
      // Legacy support: fetch entries with no timetableId or handle as default
      // For now, if timetableId is null, maybe fetch everything or specific legacy logic
      // Let's assume we filter by null if passed explicit null, but usually we pass an ID.
      // If we want "all", we wouldn't filter. 
      // But the requirement implies we want to show entries FOR a specific timetable.
      // If timetableId is 'default' or null, we might query where timetableId is null.
       query = query.where('timetableId', isNull: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return TimeTableEntry.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Stream<List<TimeTableEntry>> getAllTimetableEntriesStream([String? uid]) {
    final targetId = uid ?? userId;
    if (targetId == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(targetId)
        .collection('timetable')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TimeTableEntry.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> addTimeTableEntry(TimeTableEntry entry) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('timetable')
        .doc(entry.id)
        .set(entry.toMap());
  }

  Future<void> updateTimeTableEntry(TimeTableEntry entry) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('timetable')
        .doc(entry.id)
        .update(entry.toMap());
  }

  Future<void> deleteTimeTableEntry(String id) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('timetable')
        .doc(id)
        .delete();
  }

  // --- Modules ---

  Stream<List<Module>> getModulesStream([String? uid]) {
    final targetId = uid ?? userId;
    if (targetId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(targetId)
        .collection('modules')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Module.fromMap(doc.data());
      }).toList();
    });
  }

  Future<void> addModule(Module module) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(module.code)
        .set(module.toMap());
  }

  Future<void> updateModule(Module module) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(module.code)
        .update(module.toMap());
  }

  Future<void> deleteModule(String code) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('modules')
        .doc(code)
        .delete();
  }

  // --- Attendance ---

  Stream<List<AttendanceRecord>> getAttendanceStream([String? uid]) {
    final targetId = uid ?? userId;
    if (targetId == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(targetId)
        .collection('attendance')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AttendanceRecord.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> addAttendanceRecord(AttendanceRecord record) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('attendance')
        .doc(record.id)
        .set(record.toMap());
  }

  Future<void> deleteAttendanceRecord(String id) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('attendance')
        .doc(id)
        .delete();
  }
}
