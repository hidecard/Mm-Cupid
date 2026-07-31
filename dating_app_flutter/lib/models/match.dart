class Match {
  final int matchId;
  final DateTime matchedAt;
  final int? roomId;
  final MatchedUser user;

  Match({
    required this.matchId,
    required this.matchedAt,
    this.roomId,
    required this.user,
  });

  factory Match.fromJson(Map<String, dynamic> json, int currentUserId) {
    final userJson = json['user'] as Map<String, dynamic>? ?? {};
    return Match(
      matchId: json['match_id'] is int
          ? json['match_id']
          : int.parse(json['match_id'].toString()),
      matchedAt: json['matched_at'] != null
          ? DateTime.parse(json['matched_at'].toString())
          : DateTime.now(),
      roomId: json['room_id'] != null
          ? (json['room_id'] is int
              ? json['room_id']
              : int.parse(json['room_id'].toString()))
          : null,
      user: MatchedUser.fromJson(userJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'match_id': matchId,
      'matched_at': matchedAt.toIso8601String(),
      'room_id': roomId,
      'user': user.toJson(),
    };
  }
}

class MatchedUser {
  final int id;
  final String name;
  final String? profilePic;

  MatchedUser({
    required this.id,
    required this.name,
    this.profilePic,
  });

  factory MatchedUser.fromJson(Map<String, dynamic> json) {
    return MatchedUser(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] as String? ?? '',
      profilePic: json['profile_pic'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profile_pic': profilePic,
    };
  }
}
