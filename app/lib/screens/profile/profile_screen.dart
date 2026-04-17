import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../models/athlete.dart';
import '../../providers/athlete_provider.dart';
import '../../providers/session_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athleteState = ref.watch(athleteNotifierProvider);

    return athleteState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (athlete) => athlete == null
          ? _CreateProfileView()
          : _ProfileView(athlete: athlete),
    );
  }
}

// ── Create Profile ──────────────────────────────────────────

class _CreateProfileView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateProfileView> createState() => _CreateProfileViewState();
}

class _CreateProfileViewState extends ConsumerState<_CreateProfileView> {
  final _nicknameCtrl = TextEditingController();
  final _weightCtrl   = TextEditingController(text: '80');
  String? _photoPath;
  bool _loading = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _create() async {
    if (_nicknameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await ref.read(athleteNotifierProvider.notifier).createAthlete(
      nickname: _nicknameCtrl.text.trim(),
      bodyweightKg: double.tryParse(_weightCtrl.text) ?? 80,
      photoPath: _photoPath,
    );
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text('⚡', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('Crée ton profil', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Pour commencer à tracker tes performances',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 40),

              // Photo
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.card,
                    border: Border.all(color: AppColors.green, width: 2),
                    image: _photoPath != null
                        ? DecorationImage(image: FileImage(File(_photoPath!)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _photoPath == null
                      ? const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary)
                      : null,
                ),
              ),
              const SizedBox(height: 28),

              TextField(
                controller: _nicknameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pseudo athlète',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Poids de corps (kg)',
                  prefixIcon: Icon(Icons.monitor_weight_outlined, color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Créer mon profil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile View ────────────────────────────────────────────

class _ProfileView extends ConsumerWidget {
  final Athlete athlete;
  const _ProfileView({required this.athlete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(personalRecordsProvider(athlete.id!));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Hero ────────────────────────────────────
              const SizedBox(height: 12),
              _AvatarWidget(athlete: athlete),
              const SizedBox(height: 12),
              Text(athlete.nickname,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Text('${athlete.bodyweightKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Badge('🦵 SBD'),
                  const SizedBox(width: 8),
                  _Badge('⚡ PowerVBT'),
                ],
              ),
              const SizedBox(height: 24),

              // ── Strength Profile ─────────────────────────
              records.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => const SizedBox.shrink(),
                data: (prs) => _StrengthProfile(prs: prs, bodyweight: athlete.bodyweightKg),
              ),
              const SizedBox(height: 16),

              // ── Edit button ──────────────────────────────
              OutlinedButton.icon(
                onPressed: () => _showEditSheet(context, ref, athlete),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Modifier le profil'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, Athlete athlete) {
    final weightCtrl = TextEditingController(text: athlete.bodyweightKg.toString());
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Modifier le profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Poids de corps (kg)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final newWeight = double.tryParse(weightCtrl.text) ?? athlete.bodyweightKg;
                  ref.read(athleteNotifierProvider.notifier)
                      .updateAthlete(athlete.copyWith(bodyweightKg: newWeight));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  final Athlete athlete;
  const _AvatarWidget({required this.athlete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88, height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.green, AppColors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: athlete.photoPath != null
            ? DecorationImage(image: FileImage(File(athlete.photoPath!)), fit: BoxFit.cover)
            : null,
      ),
      child: athlete.photoPath == null
          ? Center(
              child: Text(
                athlete.nickname.isNotEmpty ? athlete.nickname[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.black),
              ),
            )
          : null,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _StrengthProfile extends StatelessWidget {
  final Map<String, double> prs;
  final double bodyweight;
  const _StrengthProfile({required this.prs, required this.bodyweight});

  String _grade(double rm, double bw) {
    if (rm == 0 || bw == 0) return '—';
    final ratio = rm / bw;
    if (ratio >= 2.5) return 'A+';
    if (ratio >= 2.0) return 'A';
    if (ratio >= 1.7) return 'B+';
    if (ratio >= 1.4) return 'B';
    if (ratio >= 1.2) return 'C+';
    return 'C';
  }

  Color _gradeColor(String grade) {
    if (grade.startsWith('A')) return AppColors.green;
    if (grade.startsWith('B')) return AppColors.yellow;
    return AppColors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final lifts = [
      ('🦵 Squat', prs['squat'] ?? 0.0),
      ('💪 Bench', prs['bench'] ?? 0.0),
      ('🔱 Deadlift', prs['deadlift'] ?? 0.0),
    ];

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
          const Text('PROFIL DE FORCE',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          ...lifts.map((lift) {
            final grade = _grade(lift.$2, bodyweight);
            final gradeColor = _gradeColor(grade);
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text(lift.$1, style: const TextStyle(fontSize: 13)),
                  const Spacer(),
                  Text(
                    lift.$2 > 0 ? '${lift.$2.toStringAsFixed(1)} kg' : '—',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: gradeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(grade,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: gradeColor)),
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
