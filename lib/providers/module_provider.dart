import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/module.dart';
import '../services/firestore_service.dart';

class ModuleProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Module> _modules = [];
  StreamSubscription<List<Module>>? _subscription;

  List<Module> get modules => _modules;

  ModuleProvider() {
    _init();
  }

  void _init() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _subscription?.cancel();
      if (user != null) {
        _subscription = _firestoreService.getModulesStream(user.uid).listen((modules) {
          _modules = modules;
          notifyListeners();
        });
      } else {
        _modules = [];
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> addModule(Module module) async {
    await _firestoreService.addModule(module);
  }

  Future<void> updateModule(Module module) async {
    await _firestoreService.updateModule(module);
  }

  Future<void> deleteModule(String code) async {
    await _firestoreService.deleteModule(code);
  }

  Module? getModule(String code) {
    try {
        return _modules.firstWhere((m) => m.code == code);
    } catch (e) {
        return null;
    }
  }
}
