import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../state/analyze_provider.dart'; // logApiProvider lives here
import '../../state/profile_provider.dart';
import '../../state/report_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_banner.dart';

/// Known MET activities (must match the backend's MET_TABLE in core/exercise.py)
/// for the time-based path; the calorie path accepts any activity name.
const List<String> _metActivities = [
  'walking',
  'brisk walking',
  'running',
  'jogging',
  'cycling',
  'swimming',
  'hiking',
  'badminton',
  'basketball',
  'football',
  'yoga',
  'weight training',
  'dancing',
  'skipping rope',
];

/// Log exercise two ways, mirroring the backend: activity + minutes (backend
/// computes kcal via METs and the user's weight) or a direct kcal entry.
class ExerciseScreen extends ConsumerStatefulWidget {
  const ExerciseScreen({super.key});

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  // 0 = by time (METs), 1 = by calories (direct).
  int _mode = 0;

  String _activity = _metActivities.first;
  final _customActivity = TextEditingController();
  final _minutes = TextEditingController();
  final _kcal = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _customActivity.dispose();
    _minutes.dispose();
    _kcal.dispose();
    super.dispose();
  }

  Future<void> _log() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_mode == 0) {
        final mins = double.tryParse(_minutes.text.trim());
        if (mins == null || mins <= 0) {
          throw const ApiException('Enter how many minutes you exercised.');
        }
        await ref
            .read(logApiProvider)
            .logExercise(activity: _activity, minutes: mins);
      } else {
        final activity = _customActivity.text.trim();
        final kcal = double.tryParse(_kcal.text.trim());
        if (activity.isEmpty) {
          throw const ApiException('Enter the activity name.');
        }
        if (kcal == null || kcal <= 0) {
          throw const ApiException('Enter the calories burned.');
        }
        await ref
            .read(logApiProvider)
            .logExercise(activity: activity, kcal: kcal);
      }

      ref.invalidate(todayReportProvider);
      if (!mounted) return;
      _minutes.clear();
      _kcal.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise logged')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not log the exercise.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(todayReportProvider);
    final profileAsync = ref.watch(profileProvider);
    final hasWeight = profileAsync.maybeWhen(
      data: (p) => p.weightKg != null,
      orElse: () => true, // don't block the UI while loading
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Log exercise')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            reportAsync.maybeWhen(
              data: (r) => _BurnedToday(kcal: r.totalBurnedKcal),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    label: Text('By time'),
                    icon: Icon(Icons.timer_outlined)),
                ButtonSegment(
                    value: 1,
                    label: Text('By calories'),
                    icon: Icon(Icons.local_fire_department_outlined)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 20),
            if (_mode == 0)
              _buildTimeMode(hasWeight)
            else
              _buildCalorieMode(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _log,
              icon: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(_saving ? 'Logging…' : 'Log exercise'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeMode(bool hasWeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasWeight)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Add your weight in Profile to compute calories from time — or '
              'use "By calories" instead.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ),
        DropdownButtonFormField<String>(
          value: _activity,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Activity'),
          items: _metActivities
              .map((a) => DropdownMenuItem(value: a, child: Text(_titleCase(a))))
              .toList(),
          onChanged: (v) => setState(() => _activity = v!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _minutes,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Duration',
            suffixText: 'min',
            prefixIcon: Icon(Icons.timer_outlined),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Calories are computed by the backend from METs and your weight.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildCalorieMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _customActivity,
          decoration: const InputDecoration(
            labelText: 'Activity',
            hintText: 'e.g. rowing',
            prefixIcon: Icon(Icons.fitness_center),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _kcal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Calories burned',
            suffixText: 'kcal',
            prefixIcon: Icon(Icons.local_fire_department_outlined),
          ),
        ),
      ],
    );
  }
}

class _BurnedToday extends StatelessWidget {
  final double kcal;
  const _BurnedToday({required this.kcal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: AppTheme.accent),
          const SizedBox(width: 10),
          Text('Burned today',
              style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(
            '${kcal.round()} kcal',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

String _titleCase(String s) =>
    s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
