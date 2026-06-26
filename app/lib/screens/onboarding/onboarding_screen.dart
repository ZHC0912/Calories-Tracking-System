import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../config.dart';
import '../../models/profile.dart';
import '../../state/profile_provider.dart';
import '../../state/report_provider.dart';
import '../../theme/app_theme.dart';
import '../../util/profile_options.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/form_fields.dart';

/// First-run guided setup. Collects body stats + goal + timezone and PUTs them,
/// then shows the backend-computed daily target. Skippable: the core loop works
/// without a profile (the target just stays hidden until this is finished).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _age = TextEditingController();

  String? _sex;
  String _activity = 'moderate';
  String _goal = 'maintain';
  String _timezone = defaultTimezone;

  bool _saving = false;
  String? _error;
  ProfileSummary? _result; // set after a successful save

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sex == null) {
      setState(() => _error = 'Please select your sex (used for the estimate).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final summary = await ref.read(profileApiProvider).update(
            ProfileUpdate(
              weightKg: double.parse(_weight.text.trim()),
              heightCm: double.parse(_height.text.trim()),
              age: int.parse(_age.text.trim()),
              sex: _sex,
              activityLevel: _activity,
              goal: _goal,
              timezone: _timezone,
            ),
          );
      ref.invalidate(profileProvider);
      ref.invalidate(todayReportProvider);
      if (mounted) setState(() => _result = summary);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your profile.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your profile'),
        actions: [
          if (result == null)
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Skip'),
            ),
        ],
      ),
      body: SafeArea(
        child: result != null
            ? _ResultView(
                summary: result,
                onDone: () => Navigator.of(context).pop(),
              )
            : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'A few details let the backend estimate your daily calorie target. '
              'You can skip and do this later.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: NumberField(
                    controller: _weight,
                    label: 'Weight',
                    suffix: 'kg',
                    min: 0,
                    max: 500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberField(
                    controller: _height,
                    label: 'Height',
                    suffix: 'cm',
                    min: 0,
                    max: 300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NumberField(
              controller: _age,
              label: 'Age',
              suffix: 'years',
              min: 0,
              max: 130,
              integer: true,
            ),
            const SizedBox(height: 20),
            OptionDropdown(
              label: 'Sex',
              value: _sex,
              options: sexes,
              onChanged: (v) => setState(() => _sex = v),
            ),
            const SizedBox(height: 12),
            OptionDropdown(
              label: 'Activity level',
              value: _activity,
              options: activityLevels,
              onChanged: (v) => setState(() => _activity = v!),
            ),
            const SizedBox(height: 12),
            OptionDropdown(
              label: 'Goal',
              value: _goal,
              options: goals,
              onChanged: (v) => setState(() => _goal = v!),
            ),
            const SizedBox(height: 12),
            TimezoneDropdown(
              value: _timezone,
              onChanged: (v) => setState(() => _timezone = v!),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save & see my target'),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                AppConfig.notMedicalAdvice,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final ProfileSummary summary;
  final VoidCallback onDone;
  const _ResultView({required this.summary, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Icon(Icons.check_circle, color: AppTheme.accent, size: 48),
          const SizedBox(height: 12),
          const Text(
            "You're all set",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          if (summary.targetKcal != null)
            _BigStat(
              label: 'Daily calorie target',
              value: '${summary.targetKcal!.round()} kcal',
            ),
          if (summary.bmi != null) ...[
            const SizedBox(height: 12),
            _BigStat(label: 'BMI', value: summary.bmi!.toStringAsFixed(1)),
            if (summary.bmiNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  summary.bmiNote!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Text(
            summary.note,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onDone, child: const Text('Start tracking')),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  const _BigStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}

