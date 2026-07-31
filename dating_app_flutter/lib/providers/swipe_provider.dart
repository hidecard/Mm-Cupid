import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class SwipeProvider with ChangeNotifier {
  final ApiService _apiService;
  List<User> _profiles = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  List<User> get profiles => _profiles;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  User? get currentUser => _currentIndex < _profiles.length
      ? _profiles[_currentIndex]
      : null;

  SwipeProvider(this._apiService);

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> fetchProfiles() async {
    if (_isLoading) return;

    setLoading(true);
    clearError();

    try {
      final response = await _apiService.getProfiles();

      if (response['success'] == true) {
        final List<dynamic> data = response['profiles'] as List<dynamic>? ?? [];

        _profiles = data.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
        _currentIndex = 0;
        _hasMore = _profiles.isNotEmpty;

        notifyListeners();
      } else {
        _error = response['error'] as String? ?? 'Failed to load profiles';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to load profiles: $e';
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    try {
      final response = await _apiService.getProfiles();

      if (response['success'] == true) {
        final List<dynamic> data = response['profiles'] as List<dynamic>? ?? [];
        _profiles.addAll(data.map((json) => User.fromJson(json as Map<String, dynamic>)).toList());
        _hasMore = data.isNotEmpty;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Failed to load more profiles: $e');
    }
  }

  Future<SwipeResult> swipeProfile(int likedId, String action) async {
    clearError();

    try {
      final response = await _apiService.swipe(likedId, action);

      if (response['success'] == true) {
        final matchData = response['match'] as Map<String, dynamic>?;
        final isMatched = matchData?['matched'] == true;

        return SwipeResult(
          success: true,
          isMatched: isMatched,
          matchId: matchData?['match_id'] as int?,
          roomId: matchData?['room_id'] as int?,
          matchedUser: matchData?['user'] != null
              ? _parseMatchedUser(matchData!['user'] as Map<String, dynamic>)
              : null,
        );
      } else {
        _error = response['error'] as String? ?? 'Swipe failed';
        notifyListeners();
        return SwipeResult(success: false);
      }
    } catch (e) {
      _error = 'Swipe failed: $e';
      notifyListeners();
      return SwipeResult(success: false);
    }
  }

  User? _parseMatchedUser(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: '',
      gender: null,
      interestedIn: null,
      birthday: null,
      bio: null,
      profilePic: json['profile_pic'] as String?,
      latitude: null,
      longitude: null,
      isOnboarded: true,
      createdAt: null,
    );
  }

  void advance() {
    if (_currentIndex < _profiles.length - 1) {
      _currentIndex++;
    }
    notifyListeners();
  }
}

class SwipeResult {
  final bool success;
  final bool isMatched;
  final int? matchId;
  final int? roomId;
  final User? matchedUser;

  SwipeResult({
    required this.success,
    this.isMatched = false,
    this.matchId,
    this.roomId,
    this.matchedUser,
  });
}
