import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../models/profile.dart';
import '../../state/profile_provider.dart';
import '../../state/report_provider.dart';
import '../../util/profile_options.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/form_fields.dart';

/// Edit all profile fields and PUT them. Pre-filled from the current summary.
/// Reuses the same form fields as onboarding.
class ProfileEditScreen extends ConsumerStatefulWidget {
  final ProfileSummary current;
  const ProfileEditScreen({super.key, required this.current});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weight;
  late final TextEditingController _height;
  late final TextEditingController _age;

  String? _sex;
  late String _activity;
  late String _goal;
  late String _timezone;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _weight = TextEditingController(text: _numText(c.weightKg));
    _height = TextEditingController(text: _numText(c.heightCm));
    _age = TextEditingController(text: c.age?.toString() ?? '');
    _sex = c.sex;
    _activity = c.activityLevel ?? 'moderate';
    _goal = c.goal ?? 'maintain';
    _timezone = c.timezone;
  }

  String _numText(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.round().toString() : v.toString();
  }

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileApiProvider).update(
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
      if (mounted) Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
