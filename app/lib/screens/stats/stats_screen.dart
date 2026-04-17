import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../models/training_set.dart';
import '../../providers/session_provider.dart';
import '../../providers/athlete_provider.dart';
import '../../services/database/database_service.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  Exercise _selectedExercise = Exercise.squat;

  @override
  Widget build(BuildContext context) {
    final athleteId = ref.watch(currentAthleteIdProvider);
    if (athleteId == null) {
      return const _NoProfilePlaceholder();
    }

    final records = ref.watch(personalRecordsProvider(athleteId));

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App bar ──────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.bg,
              title: const Text('Statistiques'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _LiftTabs(
                  selected: _selectedExercise,
                  onChanged: (e) => setState(() => _selectedExercise = e),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Personal Record ──────────────────────
                  records.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Erreur: $e'),
                    data: (prs) => _PersonalRecordCard(
                      exercise: _selectedExercise,
                      estimatedRM: prs[_selectedExercise.name] ?? 0,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Velocity trend ───────────────────────
                  _VelocityTrendCard(
                    athleteId: athleteId,
                    exercise: _selectedExercise,
                  ),
                  const SizedBox(height: 16),

                  // ── Best SBD session ─────────────────────
                  _BestSBDCard(athleteId: athleteId),

                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiftTabs extends StatelessWidget {
  final Exercise selected;
  final ValueChanged<Exercise> onChanged;
  const _LiftTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final lifts = [Exercise.squat, Exercise.bench, Exercise.deadlift];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: lifts.map((e) {
          final sel = e == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.blue : AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  e.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PersonalRecordCard extends StatelessWidget {
  final Exercise exercise;
  final double   estimatedRM;
  const _PersonalRecordCard({required this.exercise, required this.estimatedRM});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Record estimé (1RM)',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(
                  estimatedRM > 0
                      ? '${estimatedRM.toStringAsFixed(1)} kg'
                      : 'Pas encore de données',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('PR', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _VelocityTrendCard extends StatelessWidget {
  final int      athleteId;
  final Exercise exercise;
  const _VelocityTrendCard({required this.athleteId, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService.instance.getVelocityTrend(athleteId, exercise.name),
      builder: (context, snapshot) {
        final data = snapshot.data ?? [];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('VITESSE PIC — 30 JOURS',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              SizedBox(
                height: 80,
                child: data.isEmpty
                    ? const Center(child: Text('Pas encore de données',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
                    : LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: data.asMap().entries.map((e) =>
                                FlSpot(e.key.toDouble(), (e.value['peak_vel'] as double?) ?? 0)
                              ).toList(),
                              isCurved: true,
                              color: AppColors.blue,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppColors.blue.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BestSBDCard extends StatelessWidget {
  final int athleteId;
  const _BestSBDCard({required this.athleteId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: DatabaseService.instance.getPersonalRecords(athleteId),
      builder: (context, snapshot) {
        final prs = snapshot.data ?? {};
        final squat    = prs['squat']    ?? 0;
        final bench    = prs['bench']    ?? 0;
        final deadlift = prs['deadlift'] ?? 0;
        final total    = squat + bench + deadlift;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.blue.withOpacity(0.15), AppColors.card],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.blue.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Text('📋', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text('MEILLEUR TOTAL SBD',
                      style: TextStyle(fontSize: 10, color: AppColors.blue, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              _SBDRow('🦵 Squat',    squat),
              _SBDRow('💪 Bench',    bench),
              _SBDRow('🔱 Deadlift', deadlift),
              const Divider(color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(color: AppColors.textSecondary)),
                  Text(
                    total > 0 ? '${total.toStringAsFixed(0)} kg' : '—',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.blue),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SBDRow extends StatelessWidget {
  final String label;
  final double value;
  const _SBDRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value > 0 ? '${value.toStringAsFixed(1)} kg' : '—',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _NoProfilePlaceholder extends StatelessWidget {
  const _NoProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🏋️', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text('Crée ton profil pour voir\ntes statistiques',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
