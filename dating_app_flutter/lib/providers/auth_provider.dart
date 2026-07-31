import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService;
  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _token != null && _user != null;
  bool get isOnboarded => _user?.isOnboarded ?? false;
  ApiService get apiService => _apiService;

  AuthProvider(this._apiService);

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? gender,
    String? interestedIn,
    String? birthday,
  }) async {
    setLoading(true);
    clearError();

    try {
      final response = await _apiService.register({
        'name': name,
        'email': email,
        'password': password,
        'gender': gender,
        'interested_in': interestedIn,
        'birthday': birthday,
      });

      if (response['success'] == true) {
        _token = response['token'] as String?;
        await _apiService.saveToken(_token!);
        _user = User.fromJson(response['user'] as Map<String, dynamic>);
        notifyListeners();
        return true;
      } else {
        _error = response['error'] as String? ?? 'Registration failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Registration failed: $e';
      notifyListeners();
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> login(String email, String password) async {
    setLoading(true);
    clearError();

    try {
      final response = await _apiService.login(email, password);

      if (response['success'] == true) {
        _token = response['token'] as String?;
        await _apiService.saveToken(_token!);
        _user = User.fromJson(response['user'] as Map<String, dynamic>);
        notifyListeners();
        return true;
      } else {
        _error = response['error'] as String? ?? 'Login failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Login failed: $e';
      notifyListeners();
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> completeOnboarding({
    required String gender,
    required String interestedIn,
    required String birthday,
    String? bio,
    String? profilePic,
    double? latitude,
    double? longitude,
  }) async {
    setLoading(true);
    clearError();

    try {
      final response = await _apiService.updateProfile({
        'gender': gender,
        'interested_in': interestedIn,
        'birthday': birthday,
        'bio': bio,
        'profile_pic': profilePic,
        'latitude': latitude,
        'longitude': longitude,
      });

      if (response['success'] == true) {
        _user = User.fromJson(response['user'] as Map<String, dynamic>);
        notifyListeners();
        return true;
      } else {
        _error = response['error'] as String? ?? 'Onboarding failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Onboarding failed: $e';
      notifyListeners();
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> body) async {
    setLoading(true);
    clearError();

    try {
      final response = await _apiService.updateProfile(body);

      if (response['success'] == true) {
        _user = User.fromJson(response['user'] as Map<String, dynamic>);
        notifyListeners();
        return true;
      } else {
        _error = response['error'] as String? ?? 'Profile update failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Profile update failed: $e';
      notifyListeners();
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<void> loadProfile() async {
    if (_token == null) return;

    setLoading(true);
    try {
      final response = await _apiService.getProfile();

      if (response['success'] == true) {
        _user = User.fromJson(response['user'] as Map<String, dynamic>);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Failed to load profile: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _apiService.clearToken();
    notifyListeners();
  }
}
