import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class UserProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  String? _avatarKey;

  String? get avatarKey => _avatarKey;

  Future<void> loadAvatarKey() async {
    _avatarKey = await _firestoreService.getAvatarKey();
    notifyListeners();
  }

  Future<void> setAvatarKey(String key) async {
    _avatarKey = key;
    notifyListeners();
    await _firestoreService.saveAvatarKey(key);
  }
}
