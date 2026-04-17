import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/training_set.dart';
import '../../models/rep.dart';
import '../../providers/ble_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/athlete_provider.dart';
import '../../services/ble/ble_service.dart';
import '../../widgets/velocity_gauge.dart';
import '../../widgets/ble_status_dot.dart';
import '../summary/summary_screen.dart';

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  Exercise _selectedExercise = Exercise.squat;
  double   _loadKg           = 100;
  bool     _sessionStarted   = false;
  StreamSubscription? _repSub;

  @override
  void initState() {
    super.initState();
    _listenToReps();
  }

  void _listenToReps() {
    _repSub = BleService.instance.repCompletedStream.listen((rep) {
      ref.read(activeSessionProvider.notifier).addRep(rep);
    });
  }

  @override
  void dispose() {
    _repSub?.cancel();
    super.dispose();
  }

  Future<void> _startSet() async {
    final athleteId = ref.read(currentAthleteIdProvider);
    if (athleteId == null) {
      _showNoProfileSnackbar();
      return;
    }
    if (!_sessionStarted) {
      await ref.read(activeSessionProvider.notifier).startSession(athleteId);
      setState(() => _sessionStarted = true);
    }
    final setId = await ref.read(activeSessionProvider.notifier).startSet(
      exercise: _selectedExercise,
      loadKg: _loadKg,
      mode: TrainingMode.powerlifting,
    );
    await BleService.instance.startSession(setId);
  }

  Future<void> _stopSet() async {
    await BleService.instance.stopSession();
    if (!mounted) return;
    final sessionState = ref.read(activeSessionProvider);
    if (sessionState.currentReps.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SummaryScreen(
            exercise: _selectedExercise,
            loadKg: _loadKg,
            reps: sessionState.currentReps,
          ),
        ),
      );
    }
  }

  void _showNoProfileSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crée ton profil athlète d\'abord')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bleState    = ref.watch(bleConnectionProvider);
    final liveData    = ref.watch(liveVelocityProvider);
    final sessionState = ref.watch(activeSessionProvider);

    final velocity = liveData.valueOrNull?.velocity ?? 0.0;
    final isRecording = sessionState.isRecording;
    final reps = sessionState.currentReps;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isRecording ? 'Session en cours' : 'PowerVBT',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      const BleStatusDot(),
                      const SizedBox(width: 8),
                      bleState.valueOrNull == BleConnectionState.disconnected
                          ? GestureDetector(
                              onTap: () => BleService.instance.startScan(),
                              child: const Icon(Icons.bluetooth_searching,
                                  color: AppColors.textMuted, size: 20),
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                ],
              ),
            ),

            // ── Exercise + Load picker ───────────────────────
            if (!isRecording) ...[
              const SizedBox(height: 16),
              _ExercisePicker(
                selected: _selectedExercise,
                onChanged: (e) => setState(() => _selectedExercise = e),
              ),
              const SizedBox(height: 12),
              _LoadPicker(
                value: _loadKg,
                onChanged: (v) => setState(() => _loadKg = v),
              ),
            ] else
              _ActiveExercisePill(
                exercise: _selectedExercise,
                loadKg: _loadKg,
                repCount: reps.length,
              ),

            const SizedBox(height: 16),

            // ── Velocity gauge ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: VelocityGauge(velocity: velocity),
            ),

            const SizedBox(height: 12),

            // ── Rep history dots ─────────────────────────────
            if (isRecording && reps.isNotEmpty)
              _RepHistoryRow(reps: reps),

            const Spacer(),

            // ── Action button ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: isRecording
                    ? _StopButton(onTap: _stopSet)
                    : _StartButton(onTap: _startSet),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────

class _ExercisePicker extends StatelessWidget {
  final Exercise selected;
  final ValueChanged<Exercise> onChanged;
  const _ExercisePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: Exercise.values.map((e) {
          final isSelected = e == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.green.withOpacity(0.15) : AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.green : AppColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Text(e.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(
                      e.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.green : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LoadPicker extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _LoadPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Text('Charge', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const Spacer(),
            GestureDetector(
              onTap: () => onChanged((value - 2.5).clamp(0, 500)),
              child: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Text(
              '${value.toStringAsFixed(1)} kg',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => onChanged((value + 2.5).clamp(0, 500)),
              child: const Icon(Icons.add_circle_outline, color: AppColors.green),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveExercisePill extends StatelessWidget {
  final Exercise exercise;
  final double loadKg;
  final int repCount;
  const _ActiveExercisePill({
    required this.exercise,
    required this.loadKg,
    required this.repCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(exercise.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Série en cours', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                Text(exercise.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const Spacer(),
            Text(
              '${loadKg.toStringAsFixed(1)} kg',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.green),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                Text('$repCount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const Text('reps', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RepHistoryRow extends StatelessWidget {
  final List<Rep> reps;
  const _RepHistoryRow({required this.reps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HISTORIQUE SÉRIE',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: reps.take(8).map((r) {
              final color = AppColors.velocityColor(r.peakVelocity);
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(
                      r.peakVelocity.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      child: const Text('▶  Démarrer la série'),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.red.withOpacity(0.15),
        foregroundColor: AppColors.red,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.red.withOpacity(0.3)),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        elevation: 0,
      ),
      child: const Text('⏹  Terminer la série'),
    );
  }
}
