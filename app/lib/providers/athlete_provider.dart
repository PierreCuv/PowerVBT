import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/athlete.dart';
import '../services/database/database_service.dart';

// Currently selected athlete ID
final currentAthleteIdProvider = StateProvider<int?>((ref) => null);

// Current athlete data
final currentAthleteProvider = FutureProvider<Athlete?>((ref) async {
  final id = ref.watch(currentAthleteIdProvider);
  if (id == null) return null;
  return DatabaseService.instance.getAthlete(id);
});

// All athletes
final allAthletesProvider = FutureProvider<List<Athlete>>(
  (_) => DatabaseService.instance.getAllAthletes(),
);

// Athlete notifier for CRUD
class AthleteNotifier extends StateNotifier<AsyncValue<Athlete?>> {
  AthleteNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadSavedAthlete();
  }

  final Ref ref;

  Future<void> _loadSavedAthlete() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('current_athlete_id');
    if (id != null) {
      final athlete = await DatabaseService.instance.getAthlete(id);
      state = AsyncValue.data(athlete);
      ref.read(currentAthleteIdProvider.notifier).state = id;
    } else {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> createAthlete({
    required String nickname,
    required double bodyweightKg,
    String? photoPath,
    String? category,
  }) async {
    final id = await DatabaseService.instance.insertAthlete(
      Athlete(
        nickname: nickname,
        bodyweightKg: bodyweightKg,
        photoPath: photoPath,
        category: category,
        createdAt: DateTime.now(),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_athlete_id', id);
    ref.read(currentAthleteIdProvider.notifier).state = id;
    await _loadSavedAthlete();
  }

  Future<void> updateAthlete(Athlete athlete) async {
    await DatabaseService.instance.updateAthlete(athlete);
    state = AsyncValue.data(athlete);
  }

  Future<void> switchAthlete(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_athlete_id', id);
    ref.read(currentAthleteIdProvider.notifier).state = id;
    await _loadSavedAthlete();
  }
}

final athleteNotifierProvider =
    StateNotifierProvider<AthleteNotifier, AsyncValue<Athlete?>>(
  (ref) => AthleteNotifier(ref),
);
