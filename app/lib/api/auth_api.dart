import '../models/auth.dart';
import 'api_client.dart';

/// `POST /auth/register` and `POST /auth/login` (schemas/user.py).
/// Register takes `{email, password, username}`; login takes `{username,
/// password}` (the backend matches it against a username or an email). Both
/// return a `{access_token, token_type}`.
class AuthApi {
  final ApiClient client;
  const AuthApi(this.client);

  Future<TokenResponse> register(
    String email,
    String password,
    String username,
  ) =>
      _post('/auth/register', {
        'email': email,
        'password': password,
        'username': username,
      });

  Future<TokenResponse> login(String username, String password) =>
      _post('/auth/login', {
        'username': username,
        'password': password,
      });

  Future<TokenResponse> _post(String path, Map<String, dynamic> data) async {
    try {
      final res = await client.dio.post(path, data: data);
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
