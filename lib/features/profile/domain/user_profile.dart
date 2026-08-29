class UserProfile {
  const UserProfile({
    required this.name,
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.sex,
  });

  final String name;
  final double weightKg;
  final double heightCm;
  final int age;
  final String sex;

  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
        name: map['name'] as String,
        weightKg: (map['weight_kg'] as num).toDouble(),
        heightCm: (map['height_cm'] as num).toDouble(),
        age: map['age'] as int,
        sex: map['sex'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': 1,
        'name': name,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'age': age,
        'sex': sex,
        'updated_at': DateTime.now().toIso8601String(),
      };
}
