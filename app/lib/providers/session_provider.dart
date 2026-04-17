import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/training_set.dart';
import '../models/rep.dart';
import '../models/session.dart';
import '../services/database/database_service.dart';

// Active session state
class ActiveSessionState {
  final Session?       session;
  final TrainingSet?   currentSet;
  final List<Rep>      currentReps;
  final bool           isRecording;

  const ActiveSessionState({
    this.session,
    this.currentSet,
    this.currentReps = const [],
    this.isRecording = false,
  });

  ActiveSessionState copyWith({
    Session? session,
    TrainingSet? currentSet,
    List<Rep>? currentReps,
    bool? isRecording,
  }) {
    return ActiveSessionState(
      session: session ?? this.session,
      currentSet: currentSet ?? this.currentSet,
      currentReps: currentReps ?? this.currentReps,
      isRecording: isRecording ?? this.isRecording,
    );
  }
}

class ActiveSessionNotifier extends StateNotifier<ActiveSessionState> {
  ActiveSessionNotifier() : super(const ActiveSessionState());

  Future<void> startSession(int athleteId) async {
    final sessionId = await DatabaseService.instance.insertSession(
      Session(athleteId: athleteId, date: DateTime.now()),
    );
    final session = await DatabaseService.instance.getSessionsForAthlete(athleteId)
        .then((s) => s.firstWhere((s) => s.id == sessionId));
    state = state.copyWith(session: session);
  }

  Future<int> startSet({
    required Exercise exercise,
    required double loadKg,
    required TrainingMode mode,
  }) async {
    if (state.session == null) throw Exception('No active session');
    final set = TrainingSet(
      sessionId: state.session!.id!,
      exercise: exercise,
      loadKg: loadKg,
      mode: mode,
      createdAt: DateTime.now(),
    );
    final setId = await DatabaseService.instance.insertSet(set);
    state = state.copyWith(
      currentSet: TrainingSet.fromMap(set.toMap()..['id'] = setId),
      currentReps: [],
      isRecording: true,
    );
    return setId;
  }

  Future<void> addRep(Rep rep) async {
    await DatabaseService.instance.insertRep(rep);
    state = state.copyWith(
      currentReps: [...state.currentReps, rep],
    );
  }

  Future<void> finishSet({double? rpe, int? rir}) async {
    if (state.currentSet?.id != null && rpe != null && rir != null) {
      await DatabaseService.instance.updateSetRpe(
        state.currentSet!.id!, rpe, rir,
      );
    }
    state = state.copyWith(isRecording: false);
  }

  void discardCurrentSet() {
    state = state.copyWith(
      currentSet: null,
      currentReps: [],
      isRecording: false,
    );
  }
}

final activeSessionProvider =
    StateNotifierProvider<ActiveSessionNotifier, ActiveSessionState>(
  (ref) => ActiveSessionNotifier(),
);

// Session history
final sessionHistoryProvider = FutureProvider.family<List<Session>, int>(
  (ref, athleteId) => DatabaseService.instance.getSessionsForAthlete(athleteId),
);

// Personal records
final personalRecordsProvider = FutureProvider.family<Map<String, double>, int>(
  (ref, athleteId) => DatabaseService.instance.getPersonalRecords(athleteId),
);
