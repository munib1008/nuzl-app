import 'package:flutter/foundation.dart';

/// A participant other than the current user (used for the conversation title/avatar).
@immutable
class ChatUser {
  const ChatUser({required this.id, required this.name, required this.role, this.avatarUrl});
  final String id;
  final String name;
  final String role;
  final String? avatarUrl;

  factory ChatUser.fromJson(Map<String, dynamic> j) {
    final avatar = '${j['avatar_url'] ?? ''}'.trim();
    return ChatUser(
      id: '${j['id'] ?? ''}',
      name: '${j['full_name'] ?? 'Member'}',
      role: '${j['role'] ?? ''}',
      avatarUrl: avatar.isEmpty ? null : avatar,
    );
  }
}

@immutable
class Conversation {
  const Conversation({
    required this.id,
    this.subject,
    this.isGroup = false,
    this.others = const [],
    this.lastPreview,
    this.lastAt,
    this.unread = 0,
  });

  final String id;
  final String? subject;
  final bool isGroup;
  final List<ChatUser> others;
  final String? lastPreview;
  final DateTime? lastAt;
  final int unread;

  /// Display name: an explicit subject, else the other participant(s), else a fallback.
  String get title {
    final s = subject?.trim() ?? '';
    if (s.isNotEmpty) return s;
    if (others.isNotEmpty) return others.map((o) => o.name).join(', ');
    return 'Conversation';
  }

  ChatUser? get primaryOther => others.isEmpty ? null : others.first;

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final others = (j['others'] is List)
        ? (j['others'] as List)
            .map((e) => ChatUser.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <ChatUser>[];
    return Conversation(
      id: '${j['id'] ?? ''}',
      subject: j['subject'] == null ? null : '${j['subject']}',
      isGroup: j['is_group'] == true,
      others: others,
      lastPreview: j['last_message_preview'] == null ? null : '${j['last_message_preview']}',
      lastAt: DateTime.tryParse('${j['last_message_at'] ?? ''}'),
      unread: int.tryParse('${j['unread'] ?? 0}') ?? 0,
    );
  }
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String? senderId;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: '${j['id'] ?? ''}',
        conversationId: '${j['conversation_id'] ?? ''}',
        senderId: j['sender_id'] == null ? null : '${j['sender_id']}',
        body: '${j['body'] ?? ''}',
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
