import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../state/auth_provider.dart';

/// Loads a stored meal image from the authenticated `GET /images/{ref}` route,
/// attaching the bearer token. Falls back to a friendly placeholder when there
/// is no image, the user isn't authed, or the fetch fails.
class MealThumbnail extends ConsumerWidget {
  final String? imagePath;
  final double size;

  const MealThumbnail({super.key, required this.imagePath, this.size = 52});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(authControllerProvider).token;
    final path = imagePath;

    final radius = BorderRadius.circular(12);
    if (path == null || token == null) {
      return _placeholder(radius);
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        '${AppConfig.baseUrl}/images/$path',
        height: size,
        width: size,
        fit: BoxFit.cover,
        headers: {'Authorization': 'Bearer $token'},
        errorBuilder: (_, __, ___) => _placeholder(radius),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: size,
            width: size,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEE8),
              borderRadius: radius,
            ),
            child: const Center(
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder(BorderRadius radius) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE8),
        borderRadius: radius,
      ),
      child: Icon(Icons.restaurant, color: Colors.grey.shade500),
    );
  }
}
