import 'training_set.dart';

class Session {
  final int?          id;
  final int           athleteId;
  final DateTime      date;
  final String?       notes;
  final List<TrainingSet> sets;

  const Session({
    this.id,
    required this.athleteId,
    required this.date,
    this.notes,
    this.sets = const [],
  });

  // Best SBD total from this session (using estimated 1RM per lift)
  double get sbdTotal {
    double squat    = 0;
    double bench    = 0;
    double deadlift = 0;
    for (final s in sets) {
      if (s.exercise == Exercise.squat    && s.estimatedOneRM > squat)    squat    = s.estimatedOneRM;
      if (s.exercise == Exercise.bench    && s.estimatedOneRM > bench)    bench    = s.estimatedOneRM;
      if (s.exercise == Exercise.deadlift && s.estimatedOneRM > deadlift) deadlift = s.estimatedOneRM;
    }
    return squat + bench + deadlift;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'athlete_id': athleteId,
    'date': date.toIso8601String(),
    'notes': notes,
  };

  factory Session.fromMap(Map<String, dynamic> map, {List<TrainingSet> sets = const []}) => Session(
    id: map['id'],
    athleteId: map['athlete_id'],
    date: DateTime.parse(map['date']),
    notes: map['notes'],
    sets: sets,
  );
}
