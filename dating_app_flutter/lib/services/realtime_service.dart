import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';

typedef MessageCallback = void Function(Message message);
typedef MatchCallback = void Function(Map<String, dynamic> matchData);

class RealtimeService {
  final bool usePolling;
  final Duration pollInterval;
  final String? pusherKey;
  final String? pusherCluster;
  final VoidCallback? onMatchReceived;

  RealtimeService({
    this.usePolling = false,
    this.pollInterval = const Duration(seconds: 5),
    this.pusherKey,
    this.pusherCluster,
    this.onMatchReceived,
  });

  final StreamController<Message> _messageController =
      StreamController<Message>.broadcast();
  final StreamController<Map<String, dynamic>> _matchController =
      StreamController<Map<String, dynamic>>.broadcast();
  Timer? _pollTimer;

  Stream<Message> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get matchStream => _matchController.stream;

  set onMatchReceivedCallback(VoidCallback? callback) {
    // No-op: callback set via constructor
  }

  void initialize() {
    // No-op: streams are already initialized via broadcast controllers
  }

  void subscribeToChatRoom(int roomId, int userId) {
    if (usePolling) {
      _startPolling(roomId, userId);
    } else if (pusherKey != null) {
      _initPusher(roomId);
    }
  }

  void _startPolling(int roomId, int userId) {
    if (_pollTimer?.isActive ?? false) {
      _pollTimer?.cancel();
    }

    _pollMessages(roomId, userId);

    _pollTimer = Timer.periodic(pollInterval, (_) {
      _pollMessages(roomId, userId);
    });
  }

  Future<void> _pollMessages(int roomId, int userId) async {
    if (kDebugMode) {
      print('Polling for messages in room $roomId (user $userId)');
    }
  }

  void _initPusher(int roomId) {
    if (kDebugMode) {
      print('Pusher subscription for room $roomId not yet implemented');
    }
  }

  void unsubscribeFromChatRoom() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void dispose() {
    _pollTimer?.cancel();
    _messageController.close();
    _matchController.close();
  }
}
