class Athlete {
  final int?   id;
  final String nickname;
  final double bodyweightKg;
  final String? photoPath;
  final String? category;
  final DateTime createdAt;

  const Athlete({
    this.id,
    required this.nickname,
    required this.bodyweightKg,
    this.photoPath,
    this.category,
    required this.createdAt,
  });

  Athlete copyWith({
    int? id,
    String? nickname,
    double? bodyweightKg,
    String? photoPath,
    String? category,
  }) {
    return Athlete(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      bodyweightKg: bodyweightKg ?? this.bodyweightKg,
      photoPath: photoPath ?? this.photoPath,
      category: category ?? this.category,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nickname': nickname,
    'bodyweight_kg': bodyweightKg,
    'photo_path': photoPath,
    'category': category,
    'created_at': createdAt.toIso8601String(),
  };

  factory Athlete.fromMap(Map<String, dynamic> map) => Athlete(
    id: map['id'],
    nickname: map['nickname'],
    bodyweightKg: map['bodyweight_kg'],
    photoPath: map['photo_path'],
    category: map['category'],
    createdAt: DateTime.parse(map['created_at']),
  );
}
