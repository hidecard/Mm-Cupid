import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String baseUrl = 'https://mm-cupid.vercel.app';
  static const String _tokenKey = 'auth_token';

  String? _token;

  String? get token => _token;

  ApiService([String? token]) : _token = token;

  static Future<ApiService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return ApiService(token);
  }

  static void setBaseUrl(String url) {
    baseUrl = url;
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Map<String, String> _headers({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/$endpoint'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/$endpoint'),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/$endpoint'),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      try {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['error'] ?? 'Request failed with status ${response.statusCode}',
        };
      } catch (_) {
        return {
          'success': false,
          'error': 'Request failed with status ${response.statusCode}',
        };
      }
    }
  }

  // --- Auth Endpoints ---
  Future<Map<String, dynamic>> register(Map<String, dynamic> body) =>
      post('auth/register', body: body);

  Future<Map<String, dynamic>> login(String email, String password) =>
      post('auth/login', body: {'email': email, 'password': password});

  // --- Profile Endpoints ---
  Future<Map<String, dynamic>> getProfile() => get('profile');

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) =>
      put('profile', body: body);

  // --- Discovery Endpoints ---
  Future<Map<String, dynamic>> getProfiles([Map<String, String>? queryParams]) {
    var endpoint = 'profiles';
    if (queryParams != null && queryParams.isNotEmpty) {
      final params = queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      endpoint = 'profiles?$params';
    }
    return get(endpoint);
  }

  // --- Swipe & Match Endpoints ---
  Future<Map<String, dynamic>> swipe(int likedId, String action) =>
      post('swipe', body: {'liked_id': likedId, 'action': action});

  Future<Map<String, dynamic>> getMatches() => get('matches');

  Future<Map<String, dynamic>> getChatRoom(int matchId) =>
      get('chat-room/$matchId');

  // --- Chat Endpoints ---
  Future<Map<String, dynamic>> getMessages(int roomId) =>
      get('messages/$roomId');

  Future<Map<String, dynamic>> sendMessage(int roomId, String messageText) =>
      post('message', body: {'room_id': roomId, 'message_text': messageText});
}
