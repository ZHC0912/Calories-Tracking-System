import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../config.dart';
import '../../models/auth.dart';
import '../../models/food_item.dart';
import '../../state/analyze_provider.dart';
import '../../state/report_provider.dart';
import '../../theme/app_theme.dart';
import '../../util/formatters.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/honesty_tag.dart';

/// The hero screen. Shows what `/analyze` recognized and lets the user correct
/// the dish and choose a portion (precise grams, or a quick Small/Medium/Large
/// bucket) before logging. Calorie numbers shown here are a client-side preview;
/// the backend recomputes the authoritative values when the meal is logged.
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key});

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  AnalyzeDraft? _draft;
  final List<_EditableItem> _items = [];

  bool _logging = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(analyzeDraftProvider);
    _draft = draft;
    if (draft != null) {
      for (final item in draft.response.items) {
        _items.add(_EditableItem.from(item));
      }
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  // --- portion / calorie preview math --------------------------------------

  /// User-entered grams if it's a valid positive number, else null.
  double? _enteredGrams(_EditableItem item) {
    final value = double.tryParse(item.gramsCtrl.text.trim());
    if (value != null && value > 0) return value;
    return null;
  }

  double? _previewKcal(_EditableItem item) {
    final perGram = (item.baseKcal != null && item.baseGrams > 0)
        ? item.baseKcal! / item.baseGrams
        : null;
    final grams = _enteredGrams(item);
    if (grams != null) return perGram != null ? perGram * grams : null;
    if (item.bucket != null) return null; // bucket grams resolved server-side
    return item.baseKcal; // untouched
  }

  String _honestyLabel(_EditableItem item) {
    final grams = _enteredGrams(item);
    if (grams != null) return 'from ${gramsText(grams)}';
    if (item.bucket != null) return '${_bucketLabel(item.bucket!)} portion';
    return gramSourceLabel(item.baseGramSource, item.baseGrams);
  }

  double? get _totalKcal {
    double sum = 0;
    var any = false;
    for (final item in _items) {
      final k = _previewKcal(item);
      if (k != null) {
        sum += k;
        any = true;
      }
    }
    return any ? sum : null;
  }

  bool get _canLog =>
      !_logging &&
      _items.isNotEmpty &&
      _items.every((i) => i.dish.trim().isNotEmpty);

  // --- logging -------------------------------------------------------------

  Future<void> _log() async {
    final draft = _draft;
    if (draft == null || !_canLog) return;

    setState(() {
      _logging = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final items = _items.map((item) {
        final grams = _enteredGrams(item);
        return LogFoodItem(
          dish: item.dish.trim(),
          grams: grams,
          // grams wins; only send a bucket when no explicit grams.
          bucket: grams == null ? item.bucket : null,
        );
      }).toList();

      await ref.read(logApiProvider).logFood(
            items: items,
            image: draft.image,
          );

      // Clear the draft and refresh today's report so home shows the new meal.
      ref.read(analyzeDraftProvider.notifier).clear();
      ref.invalidate(todayReportProvider);

      navigator.popUntil((r) => r.isFirst); // back to home
      messenger.showSnackBar(
        const SnackBar(content: Text('Meal logged')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not log the meal.');
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    if (draft == null) {
      // No in-progress meal (e.g. after a hot restart) — nothing to confirm.
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm meal')),
        body: const Center(child: Text('Nothing to confirm.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm meal')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.file(draft.image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_items.isEmpty)
                    _AllRemoved()
                  else
                    ..._items.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildItemCard(entry.key, entry.value),
                      );
                    }),
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    ErrorBanner(_error!),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Calorie numbers are estimates and are finalized when you '
                    'log. ${AppConfig.notMedicalAdvice}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            _BottomBar(
              totalKcal: _totalKcal,
              canLog: _canLog,
              logging: _logging,
              onLog: _log,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, _EditableItem item) {
    final lowConfidence = item.confidence < AppConfig.lowConfidenceThreshold;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Low-confidence confirm prompt leads the card.
            if (lowConfidence && !item.dishConfirmed) ...[
              _ConfirmDishPrompt(
                dish: item.dish,
                onYes: () => setState(() => item.dishConfirmed = true),
                onNo: () => setState(() => item.editingDish = true),
              ),
              const SizedBox(height: 12),
            ],

            // Dish name (display or inline edit), with remove action.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildDishField(item)),
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, color: Colors.grey.shade500),
                  onPressed: () => setState(() {
                    item.dispose();
                    _items.removeAt(index);
                  }),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              'Portion',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Quick path: size buckets.
            Wrap(
              spacing: 8,
              children: ['small', 'medium', 'large'].map((b) {
                final selected =
                    item.bucket == b && _enteredGrams(item) == null;
                return ChoiceChip(
                  label: Text(_bucketLabel(b)),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    item.bucket = selected ? null : b;
                    if (item.bucket != null) item.gramsCtrl.clear();
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Precise path: explicit grams. Typing clears the bucket.
            TextField(
              controller: item.gramsCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Grams (precise)',
                hintText: 'e.g. 250',
                suffixText: 'g',
                prefixIcon: Icon(Icons.scale_outlined),
              ),
              onChanged: (_) => setState(() {
                if (_enteredGrams(item) != null) item.bucket = null;
              }),
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                HonestyTag(label: _honestyLabel(item)),
                const Spacer(),
                Text(
                  kcalText(_previewKcal(item)),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
            if (_previewKcal(item) == null && item.bucket != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Calories for this portion are calculated when you log.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishField(_EditableItem item) {
    if (item.editingDish) {
      return TextField(
        controller: item.dishCtrl,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Dish',
          isDense: true,
          suffixIcon: IconButton(
            icon: const Icon(Icons.check, color: AppTheme.accent),
            onPressed: () => setState(() {
              item.dish = item.dishCtrl.text.trim();
              item.editingDish = false;
              item.dishConfirmed = true;
            }),
          ),
        ),
        onChanged: (v) => item.dish = v,
        onSubmitted: (v) => setState(() {
          item.dish = v.trim();
          item.editingDish = false;
          item.dishConfirmed = true;
        }),
      );
    }
    return Row(
      children: [
        Flexible(
          child: Text(
            item.dish.isEmpty ? 'Unnamed dish' : item.dish,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Edit dish',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade500),
          onPressed: () => setState(() {
            item.dishCtrl.text = item.dish;
            item.editingDish = true;
          }),
        ),
      ],
    );
  }
}

String _bucketLabel(String bucket) {
  switch (bucket) {
    case 'small':
      return 'Small';
    case 'medium':
      return 'Medium';
    case 'large':
      return 'Large';
    default:
      return bucket;
  }
}

/// Mutable working copy of an analyzed item while the user confirms it.
class _EditableItem {
  String dish;
  final double baseGrams;
  final double? baseKcal;
  final double confidence;
  final String baseGramSource;

  final TextEditingController gramsCtrl;
  final TextEditingController dishCtrl;
  String? bucket;
  bool dishConfirmed;
  bool editingDish;

  _EditableItem({
    required this.dish,
    required this.baseGrams,
    required this.baseKcal,
    required this.confidence,
    required this.baseGramSource,
  })  : gramsCtrl = TextEditingController(),
        dishCtrl = TextEditingController(text: dish),
        bucket = null,
        dishConfirmed = false,
        editingDish = false;

  factory _EditableItem.from(FoodItem item) => _EditableItem(
        dish: item.dish,
        baseGrams: item.grams,
        baseKcal: item.kcal,
        confidence: item.confidence,
        baseGramSource: item.gramSource,
      );

  void dispose() {
    gramsCtrl.dispose();
    dishCtrl.dispose();
  }
}

class _ConfirmDishPrompt extends StatelessWidget {
  final String dish;
  final VoidCallback onYes;
  final VoidCallback onNo;
  const _ConfirmDishPrompt({
    required this.dish,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "We're not fully sure — is this $dish?",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: onYes,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text("Yes, that's it"),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onNo,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text('No, change'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final double? totalKcal;
  final bool canLog;
  final bool logging;
  final VoidCallback onLog;

  const _BottomBar({
    required this.totalKcal,
    required this.canLog,
    required this.logging,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                kcalText(totalKcal),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton.icon(
              onPressed: canLog ? onLog : null,
              icon: logging
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(logging ? 'Logging…' : 'Log meal'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllRemoved extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.remove_circle_outline,
              size: 36, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            'No items left to log',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'Go back to retake the photo.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
