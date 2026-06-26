import '../models/auth.dart';
import 'api_client.dart';

/// `POST /auth/register` and `POST /auth/login` (schemas/user.py).
/// Both take `{email, password}` and return a `{access_token, token_type}`.
class AuthApi {
  final ApiClient client;
  const AuthApi(this.client);

  Future<TokenResponse> register(String email, String password) =>
      _post('/auth/register', email, password);

  Future<TokenResponse> login(String email, String password) =>
      _post('/auth/login', email, password);

  Future<TokenResponse> _post(String path, String email, String password) async {
    try {
      final res = await client.dio.post(
        path,
        data: {'email': email, 'password': password},
      );
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return TokenResponse.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }
}
