class Module {
  final String code;
  final String name;
  final double credits;
  final String lecturerName;
  final String? note;

  Module({
    required this.code,
    required this.name,
    required this.credits,
    required this.lecturerName,
    this.note,
  });

  // Firestore Serialization
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'credits': credits,
      'lecturerName': lecturerName,
      'note': note,
    };
  }

  factory Module.fromMap(Map<String, dynamic> map) {
    return Module(
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      credits: _parseCredits(map['credits']),
      lecturerName: map['lecturerName'] ?? '',
      note: map['note'],
    );
  }

  static double _parseCredits(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
