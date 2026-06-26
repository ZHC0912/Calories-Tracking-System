import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../util/profile_options.dart';

/// Shared profile form fields, reused by onboarding and the profile editor so
/// validation and look stay identical.

class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final double min;
  final double max;
  final bool integer;

  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
    required this.min,
    required this.max,
    this.integer = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(integer ? r'[0-9]' : r'[0-9.]'),
        ),
      ],
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) return 'Required';
        final value = double.tryParse(text);
        if (value == null) return 'Enter a number';
        if (value <= min || value > max) {
          return 'Enter ${min.round()}–${max.round()}';
        }
        return null;
      },
    );
  }
}

class OptionDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<Option> options;
  final ValueChanged<String?> onChanged;

  const OptionDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class TimezoneDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const TimezoneDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure the current value is selectable even if not in the curated list.
    final values = {...commonTimezones, value}.toList();
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Timezone'),
      items: values
          .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
