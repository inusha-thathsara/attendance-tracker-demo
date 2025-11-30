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
      credits: (map['credits'] ?? 0).toDouble(),
      lecturerName: map['lecturerName'] ?? '',
      note: map['note'],
    );
  }
}
