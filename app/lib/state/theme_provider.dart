import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'auth_provider.dart';

/// The user-selected accent color, persisted on-device so it survives restarts.
/// Starts at [AppTheme.defaultAccent] and updates once the stored value loads.
class AccentController extends Notifier<Color> {
  static const _key = 'accent_color';

  @override
  Color build() {
    _load();
    return AppTheme.defaultAccent;
  }

  Future<void> _load() async {
    final raw = await ref.read(secureStorageProvider).read(key: _key);
    final argb = raw == null ? null : int.tryParse(raw);
    if (argb != null) state = Color(argb);
  }

  /// Apply a new accent immediately and persist it.
  Future<void> setAccent(Color color) async {
    state = color;
    await ref
        .read(secureStorageProvider)
        .write(key: _key, value: color.toARGB32().toString());
  }
}

final accentColorProvider =
    NotifierProvider<AccentController, Color>(AccentController.new);
