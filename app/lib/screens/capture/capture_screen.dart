import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_client.dart';
import '../../state/analyze_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_banner.dart';
import 'confirm_screen.dart';

/// Step 1 of the core loop: pick/take a meal photo, optionally describe it, then
/// send it to `/analyze`. On success we stash the result and move to confirm.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _picker = ImagePicker();
  final _caption = TextEditingController();

  File? _image;
  bool _analyzing = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _image = File(picked.path);
          _error = null;
        });
      }
    } catch (_) {
      setState(() => _error = "Couldn't open the camera or gallery.");
    }
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null) return;
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final caption = _caption.text.trim();
      final response = await ref.read(analyzeApiProvider).analyze(
            image: image,
            caption: caption.isEmpty ? null : caption,
          );

      ref.read(analyzeDraftProvider.notifier).set(AnalyzeDraft(
            image: image,
            caption: caption.isEmpty ? null : caption,
            response: response,
          ));

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ConfirmScreen()),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not analyze the photo.');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Snap your meal')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ImageArea(
                image: _image,
                onTap: () => _pick(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _analyzing
                          ? null
                          : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _analyzing
                          ? null
                          : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _caption,
                enabled: !_analyzing,
                decoration: const InputDecoration(
                  labelText: 'Describe it (optional)',
                  hintText: 'e.g. nasi lemak 250g',
                  prefixIcon: Icon(Icons.edit_note),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 6),
              Text(
                'Adding grams (e.g. "250g") makes the estimate more accurate.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(_error!),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: (_image == null || _analyzing) ? null : _analyze,
                icon: _analyzing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_analyzing ? 'Analyzing…' : 'Analyze'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageArea extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;
  const _ImageArea({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: image == null ? onTap : null,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3EEE8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          clipBehavior: Clip.antiAlias,
          child: image == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        size: 44, color: AppTheme.accent),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to take a photo',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                )
              : Image.file(image!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
