// models/chat_models.dart

class ChatUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? profileImage;
  final bool isOnline;
  final DateTime lastSeen;


  ChatUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profileImage,
    required this.isOnline,
    required this.lastSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'profileImage': profileImage,
      'isOnline': isOnline,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
    };
  }

  factory ChatUser.fromMap(Map<String, dynamic> map) {
    return ChatUser(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'parent',
      profileImage: map['profileImage'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] ?? 0),
    );
  }
}

class ChatRoom {
  final String id;
  final String name;
  final String type;
  final List<String> participantIds;
  final List<String> adminIds;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastSenderId;

  ChatRoom({
    required this.id,
    required this.name,
    required this.type,
    required this.participantIds,
    required this.adminIds,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSenderId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'participantIds': participantIds,
      'adminIds': adminIds,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.millisecondsSinceEpoch,
      'lastSenderId': lastSenderId,
    };
  }

  factory ChatRoom.fromMap(Map<String, dynamic> map) {
    return ChatRoom(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'direct',
      participantIds: List<String>.from(map['participantIds'] ?? []),
      adminIds: List<String>.from(map['adminIds'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'])
          : null,
      lastSenderId: map['lastSenderId'],
    );
  }
}

class ChatMessage {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderName;
  final String content;
  final String type;
  final DateTime timestamp;
  final bool isRead;
  final List<String> readBy;

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.readBy = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'readBy': readBy,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      chatRoomId: map['chatRoomId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      isRead: map['isRead'] ?? false,
      readBy: List<String>.from(map['readBy'] ?? []),
    );
  }
}