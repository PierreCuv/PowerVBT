import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/rep.dart';
import '../../models/training_set.dart';
import '../../providers/session_provider.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  final Exercise     exercise;
  final double       loadKg;
  final List<Rep>    reps;

  const SummaryScreen({
    super.key,
    required this.exercise,
    required this.loadKg,
    required this.reps,
  });

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  double _rpe = 8.0;

  double get _peakVelocity =>
      widget.reps.isEmpty ? 0 : widget.reps.map((r) => r.peakVelocity).reduce((a, b) => a > b ? a : b);

  double get _meanVelocity =>
      widget.reps.isEmpty ? 0 : widget.reps.map((r) => r.meanVelocity).reduce((a, b) => a + b) / widget.reps.length;

  double get _fatigueIndex {
    if (widget.reps.length < 2) return 0;
    final first = widget.reps.first.peakVelocity;
    final last  = widget.reps.last.peakVelocity;
    return first > 0 ? ((first - last) / first) * 100 : 0;
  }

  double get _estimated1RM => widget.loadKg * (1 + widget.reps.length / 30.0);

  int get _rir => (10 - _rpe).round().clamp(0, 5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résumé série'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(activeSessionProvider.notifier).discardCurrentSet();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Subtitle ──────────────────────────────────
              Text(
                '${widget.exercise.emoji} ${widget.exercise.label}  ·  '
                '${widget.loadKg.toStringAsFixed(1)} kg  ·  '
                '${widget.reps.length} reps',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // ── Summary stats ─────────────────────────────
              Row(
                children: [
                  _StatCard(label: 'Pic m/s',  value: _peakVelocity.toStringAsFixed(2), color: AppColors.velocityColor(_peakVelocity)),
                  const SizedBox(width: 10),
                  _StatCard(label: 'Moy m/s',  value: _meanVelocity.toStringAsFixed(2),  color: AppColors.velocityColor(_meanVelocity)),
                  const SizedBox(width: 10),
                  _StatCard(label: 'Fatigue',  value: '-${_fatigueIndex.toStringAsFixed(0)}%', color: _fatigueIndex > 15 ? AppColors.red : AppColors.yellow),
                  const SizedBox(width: 10),
                  _StatCard(label: '1RM est.', value: '~${_estimated1RM.toStringAsFixed(0)}', color: AppColors.blue),
                ],
              ),
              const SizedBox(height: 20),

              // ── Rep table ─────────────────────────────────
              const Text('DÉTAIL DES REPS',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              _RepTable(reps: widget.reps),
              const SizedBox(height: 20),

              // ── RPE picker ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('RPE ressenti', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        Text('RIR : $_rir', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0].map((v) {
                        final sel = _rpe == v;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _rpe = v),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 36,
                              decoration: BoxDecoration(
                                color: sel ? AppColors.orange : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  v % 1 == 0 ? v.toInt().toString() : v.toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? Colors.black : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Save button ───────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  child: const Text('✓  Enregistrer la série'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    await ref.read(activeSessionProvider.notifier).finishSet(rpe: _rpe, rir: _rir);
    if (!mounted) return;
    Navigator.pop(context);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

class _RepTable extends StatelessWidget {
  final List<Rep> reps;
  const _RepTable({required this.reps});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: const [
                SizedBox(width: 28, child: Text('#', style: TextStyle(fontSize: 10, color: AppColors.textMuted))),
                Expanded(child: Center(child: Text('Vitesse', style: TextStyle(fontSize: 10, color: AppColors.textMuted)))),
                SizedBox(width: 48, child: Text('m/s', style: TextStyle(fontSize: 10, color: AppColors.textMuted), textAlign: TextAlign.right)),
                SizedBox(width: 40, child: Text('TUT', style: TextStyle(fontSize: 10, color: AppColors.textMuted), textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...reps.asMap().entries.map((e) {
            final rep   = e.value;
            final color = AppColors.velocityColor(rep.peakVelocity);
            final maxV  = reps.map((r) => r.peakVelocity).reduce((a, b) => a > b ? a : b);
            final pct   = maxV > 0 ? rep.peakVelocity / maxV : 0.0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6)),
                    child: Center(child: Text('${e.key + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.toDouble(),
                        backgroundColor: AppColors.surface,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 38,
                    child: Text(
                      rep.peakVelocity.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${(rep.tutMs / 1000).toStringAsFixed(1)}s',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
