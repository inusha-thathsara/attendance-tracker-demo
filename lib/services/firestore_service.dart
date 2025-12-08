import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/timetable_entry.dart';
import '../models/timetable.dart';
import '../models/module.dart';
import 'package:attendance_tracker/models/attendance_record.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

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

    // 1. Fetch all entries for THIS timetable to know what we are about to remove
    final entriesSnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('timetable')
        .where('timetableId', isEqualTo: id)
        .get();

    final entriesToDelete = entriesSnapshot.docs;
    final modulesInThisTimetable = entriesToDelete
        .map((e) => e.data()['moduleCode'] as String?)
        .where((code) => code != null && code.isNotEmpty)
        .toSet()
        .cast<String>();

    // 2. Fetch ALL other entries to see what is being preserved
    // We can't do "where timetableId != id" easily in Firestore without composite index often.
    // Easier to just fetch all entries and filter in memory since user won't have millions of entries.
    final allEntriesSnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('timetable')
        .get();
        
    final otherModulesUsage = allEntriesSnapshot.docs
        .where((doc) => doc.data()['timetableId'] != id)
        .map((doc) => doc.data()['moduleCode'] as String?)
        .where((code) => code != null && code.isNotEmpty)
        .toSet();

    // 3. Identify orphaned modules (In this timetable BUT NOT in others)
    final modulesToDelete = modulesInThisTimetable
        .where((code) => !otherModulesUsage.contains(code))
        .toList();

    debugPrint('Deleting Timetable $id');
    debugPrint('Found ${entriesToDelete.length} entries to delete.');
    debugPrint('Found ${modulesToDelete.length} orphan modules to delete: $modulesToDelete');

    final batch = _db.batch();

    // Delete Entries
    for (var doc in entriesToDelete) {
      batch.delete(doc.reference);
    }
    
    // Delete Orphan Modules
    for (var code in modulesToDelete) {
      final moduleRef = _db
          .collection('users')
          .doc(userId)
          .collection('modules')
          .doc(code);
      batch.delete(moduleRef);
    }
    
    // Delete Timetable
    final timetableRef = _db
        .collection('users')
        .doc(userId)
        .collection('timetables')
        .doc(id);
    batch.delete(timetableRef);

    await batch.commit();
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
  // --- Settings (API Key) ---

  Future<List<String>> getApiKeys([String? uid]) async {
    final targetId = uid ?? userId;
    if (targetId == null) return [];
    final doc = await _db
        .collection('users')
        .doc(targetId)
        .collection('settings')
        .doc('gemini')
        .get();
    
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data['apiKeys'] != null) {
        return List<String>.from(data['apiKeys']);
      } else if (data['apiKey'] != null) {
        // Migration: If old single key exists, return it as a list
        return [data['apiKey'] as String];
      }
    }
    return [];
  }

  Future<void> saveApiKeys(List<String> apiKeys, [String? uid]) async {
    final targetId = uid ?? userId;
    if (targetId == null) return;
    await _db
        .collection('users')
        .doc(targetId)
        .collection('settings')
        .doc('gemini')
        .set({'apiKeys': apiKeys});
  }

  // --- Profile (Avatar) ---

  Future<String?> getAvatarKey([String? uid]) async {
    final targetId = uid ?? userId;
    if (targetId == null) return null;
    final doc = await _db
        .collection('users')
        .doc(targetId)
        .collection('settings')
        .doc('profile')
        .get();

    if (doc.exists && doc.data() != null) {
      return doc.data()!['avatarKey'] as String?;
    }
    return null;
  }

  Future<void> saveAvatarKey(String key, [String? uid]) async {
    final targetId = uid ?? userId;
    if (targetId == null) return;
    await _db
        .collection('users')
        .doc(targetId)
        .collection('settings')
        .doc('profile')
        .set({'avatarKey': key}, SetOptions(merge: true));
  }

  // --- Sharing ---

  Future<String> shareTimetable(
    Timetable timetable,
    List<Module> modules,
    List<TimeTableEntry> entries,
  ) async {
    if (userId == null) throw Exception('User must be logged in to share');

    // Create a lean representation of the data
    final shareData = {
      'timetable': timetable.toMap(),
      'modules': modules.map((m) => m.toMap()).toList(),
      'entries': entries.map((e) => e.toMap()).toList(),
      'sharedBy': userId,
      'sharedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))), // For TTL
    };

    final docRef = await _db.collection('shared_timetables').add(shareData);
    return docRef.id;
  }

  Future<Map<String, dynamic>> fetchSharedTimetable(String shareId) async {
    final doc = await _db.collection('shared_timetables').doc(shareId).get();
    if (!doc.exists) {
      throw Exception('Shared timetable not found');
    }

    final data = doc.data() as Map<String, dynamic>;

    // Lazy Expiration Check (Alternative to Firestore TTL)
    if (data.containsKey('expiresAt')) {
      final Timestamp expiresAt = data['expiresAt'];
      if (expiresAt.toDate().isBefore(DateTime.now())) {
        throw Exception('This shared link has expired.');
      }
    }

    return data;
  }

  Future<void> deleteSharedTimetable(String shareId) async {
    await _db.collection('shared_timetables').doc(shareId).delete();
  }
}
