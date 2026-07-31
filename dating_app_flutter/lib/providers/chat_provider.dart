import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';

class ChatProvider with ChangeNotifier {
  final ApiService _apiService;
  final RealtimeService _realtimeService;
  final int _currentUserId;

  final Map<int, List<Message>> _messagesByRoom = {};
  final Set<int> _subscribedRooms = {};
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _matchSubscription;

  bool _isLoading = false;
  String? _error;
  int? _activeRoomId;
  VoidCallback? _onMatchReceived;

  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get activeRoomId => _activeRoomId;
  List<Message> get messages => _messagesByRoom[_activeRoomId] ?? [];

  ChatProvider(this._apiService, this._realtimeService, this._currentUserId);

  void setOnMatchReceived(VoidCallback? callback) {
    _onMatchReceived = callback;
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> subscribeToRoom(int roomId) async {
    if (_subscribedRooms.contains(roomId)) return;

    _activeRoomId = roomId;
    _subscribedRooms.add(roomId);

    if (_messageSubscription != null) {
      await _messageSubscription!.cancel();
    }

    _realtimeService.initialize();
    _realtimeService.subscribeToChatRoom(roomId, _currentUserId);

    _messageSubscription = _realtimeService.messageStream.listen((message) {
      _addMessage(message);
    });

    _matchSubscription ??= _realtimeService.matchStream.listen((matchData) {
      _onMatchReceived?.call();
    });

    await loadMessages(roomId);
  }

  Future<void> loadMessages(int roomId) async {
    setLoading(true);
    clearError();

    try {
      final response = await _apiService.getMessages(roomId);

      if (response['success'] == true) {
        final List<dynamic> data = response['messages'] as List<dynamic>? ?? [];
        _messagesByRoom[roomId] = data
            .map((json) => Message.fromJson(json as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } else {
        _error = response['error'] as String? ?? 'Failed to load messages';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to load messages: $e';
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  void _addMessage(Message message) {
    final roomId = message.roomId;
    if (!_messagesByRoom.containsKey(roomId)) {
      _messagesByRoom[roomId] = [];
    }
    _messagesByRoom[roomId]!.add(message);

    if (roomId == _activeRoomId) {
      notifyListeners();
    } else {
      // Notify to show in-app (e.g., badge)
      if (kDebugMode) print('New message in room $roomId');
    }
  }

  Future<bool> sendMessage(int roomId, String messageText) async {
    if (messageText.trim().isEmpty) return false;

    clearError();

    try {
      final response = await _apiService.sendMessage(roomId, messageText);

      if (response['success'] == true) {
        final message = Message.fromJson(response['message'] as Map<String, dynamic>);
        _addMessage(message);
        notifyListeners();
        return true;
      } else {
        _error = response['error'] as String? ?? 'Failed to send message';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to send message: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> leaveRoom() async {
    if (_messageSubscription != null) {
      await _messageSubscription!.cancel();
      _messageSubscription = null;
    }
    _realtimeService.unsubscribeFromChatRoom();
    _subscribedRooms.remove(_activeRoomId);
    _activeRoomId = null;
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _matchSubscription?.cancel();
    _realtimeService.dispose();
    super.dispose();
  }
}
