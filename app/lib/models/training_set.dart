import 'rep.dart';

enum Exercise { squat, bench, deadlift, other }
enum TrainingMode { powerlifting, strength }

extension ExerciseExt on Exercise {
  String get label {
    switch (this) {
      case Exercise.squat:    return 'Squat';
      case Exercise.bench:    return 'Bench Press';
      case Exercise.deadlift: return 'Deadlift';
      case Exercise.other:    return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case Exercise.squat:    return '🦵';
      case Exercise.bench:    return '💪';
      case Exercise.deadlift: return '🔱';
      case Exercise.other:    return '🏋️';
    }
  }

  // Minimum velocity threshold (MVT) for 1RM estimation
  double get mvt {
    switch (this) {
      case Exercise.squat:    return 0.17;
      case Exercise.bench:    return 0.17;
      case Exercise.deadlift: return 0.12;
      case Exercise.other:    return 0.17;
    }
  }
}

class TrainingSet {
  final int?         id;
  final int          sessionId;
  final Exercise     exercise;
  final double       loadKg;
  final TrainingMode mode;
  final double?      rpe;
  final int?         rir;
  final bool         isManual;
  final DateTime     createdAt;
  final List<Rep>    reps;

  const TrainingSet({
    this.id,
    required this.sessionId,
    required this.exercise,
    required this.loadKg,
    required this.mode,
    this.rpe,
    this.rir,
    this.isManual = false,
    required this.createdAt,
    this.reps = const [],
  });

  // ── Computed metrics ────────────────────────────────────

  int get repCount => reps.length;

  double get peakVelocity =>
      reps.isEmpty ? 0 : reps.map((r) => r.peakVelocity).reduce((a, b) => a > b ? a : b);

  double get meanVelocity =>
      reps.isEmpty ? 0 : reps.map((r) => r.meanVelocity).reduce((a, b) => a + b) / reps.length;

  // Velocity drop between first and last rep (fatigue index)
  double get fatigueIndex {
    if (reps.length < 2) return 0;
    final first = reps.first.peakVelocity;
    final last  = reps.last.peakVelocity;
    return first > 0 ? ((first - last) / first) * 100 : 0;
  }

  // Epley 1RM estimation
  double get estimatedOneRM {
    if (reps.isEmpty) return loadKg;
    return loadKg * (1 + repCount / 30.0);
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'exercise': exercise.name,
    'load_kg': loadKg,
    'mode': mode.name,
    'rpe': rpe,
    'rir': rir,
    'is_manual': isManual ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  factory TrainingSet.fromMap(Map<String, dynamic> map, {List<Rep> reps = const []}) => TrainingSet(
    id: map['id'],
    sessionId: map['session_id'],
    exercise: Exercise.values.firstWhere((e) => e.name == map['exercise'], orElse: () => Exercise.other),
    loadKg: map['load_kg'],
    mode: TrainingMode.values.firstWhere((m) => m.name == map['mode'], orElse: () => TrainingMode.strength),
    rpe: map['rpe'],
    rir: map['rir'],
    isManual: map['is_manual'] == 1,
    createdAt: DateTime.parse(map['created_at']),
    reps: reps,
  );
}
