/// Mirrors the backend `TokenResponse` (schemas/user.py): the JWT returned by
/// `POST /auth/register` and `POST /auth/login`.
class TokenResponse {
  final String accessToken;
  final String tokenType;

  const TokenResponse({required this.accessToken, this.tokenType = 'bearer'});

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
    );
  }
}

/// The request body for `POST /log/food`'s `items` field — one confirmed item.
/// (Sent as JSON inside the multipart `items` form field; see LogApi.)
///
/// `grams` (explicit) wins over `bucket`; if both are null the backend uses its
/// own portion estimate for the dish. Calorie numbers are recomputed server-side
/// from this — the client never sends nutrient values.
class LogFoodItem {
  final String dish;
  final double? grams;
  final String? bucket; // "small" | "medium" | "large"

  const LogFoodItem({required this.dish, this.grams, this.bucket});

  Map<String, dynamic> toJson() => {
        'dish': dish,
        if (grams != null) 'grams': grams,
        if (bucket != null) 'bucket': bucket,
      };
}
