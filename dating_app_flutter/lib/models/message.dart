class Message {
  final int id;
  final int roomId;
  final int senderId;
  final String messageText;
  final DateTime createdAt;
  final String? senderName;
  final String? senderPic;

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.messageText,
    required this.createdAt,
    this.senderName,
    this.senderPic,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      roomId: json['room_id'] is int
          ? json['room_id']
          : int.parse(json['room_id'].toString()),
      senderId: json['sender_id'] is int
          ? json['sender_id']
          : int.parse(json['sender_id'].toString()),
      messageText: json['message_text'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      senderName: json['sender_name'] as String?,
      senderPic: json['sender_pic'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'message_text': messageText,
      'created_at': createdAt.toIso8601String(),
      'sender_name': senderName,
      'sender_pic': senderPic,
    };
  }

  bool isFromMe(int currentUserId) {
    return senderId == currentUserId;
  }
}
