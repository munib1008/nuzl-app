import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/conversation.dart';

final messagingRepositoryProvider =
    Provider((ref) => MessagingRepository(ref.read(apiClientProvider)));

/// Inbox — polled every 8s while a messaging screen is open (near-real-time).
final inboxProvider = StreamProvider.autoDispose<List<Conversation>>((ref) {
  final repo = ref.watch(messagingRepositoryProvider);
  return _poll(ref, const Duration(seconds: 8), repo.inbox);
});

/// Messages in one thread — polled every 4s while the thread is open.
final threadMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, id) {
  final repo = ref.watch(messagingRepositoryProvider);
  return _poll(ref, const Duration(seconds: 4), () => repo.messages(id));
});

/// Conversation header (other participant + subject) — fetched once per thread.
final threadHeaderProvider =
    FutureProvider.autoDispose.family<Conversation, String>((ref, id) =>
        ref.read(messagingRepositoryProvider).header(id));

/// Total unread message count for a nav badge.
final messagesUnreadProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/conversations/unread-count');
    final m = d is Map ? Map<String, dynamic>.from(d) : const {};
    return int.tryParse('${m['count'] ?? 0}') ?? 0;
  } catch (_) {
    return 0;
  }
});

/// Emits once immediately, then re-fetches on [every] until the provider is
/// disposed. A transient fetch error after the first success is swallowed so the
/// UI keeps the last good data instead of flickering to an error state.
Stream<T> _poll<T>(Ref ref, Duration every, Future<T> Function() fetch) {
  final ctrl = StreamController<T>();
  var closed = false;
  var hasData = false;
  Future<void> tick() async {
    try {
      final v = await fetch();
      if (!closed && !ctrl.isClosed) {
        ctrl.add(v);
        hasData = true;
      }
    } catch (e) {
      if (!closed && !hasData && !ctrl.isClosed) ctrl.addError(e);
    }
  }

  tick();
  final timer = Timer.periodic(every, (_) => tick());
  ref.onDispose(() {
    closed = true;
    timer.cancel();
    ctrl.close();
  });
  return ctrl.stream;
}

class MessagingRepository {
  MessagingRepository(this._api);
  final ApiClient _api;

  Future<List<Conversation>> inbox() async {
    final d = await _api.get('/conversations');
    return d is List
        ? d.map((e) => Conversation.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <Conversation>[];
  }

  Future<Conversation> header(String id) async {
    final d = await _api.get('/conversations/$id');
    return Conversation.fromJson(d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{});
  }

  Future<List<ChatMessage>> messages(String id, {String? after}) async {
    final d = await _api.get('/conversations/$id/messages',
        query: after == null ? null : {'after': after});
    return d is List
        ? d.map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <ChatMessage>[];
  }

  Future<ChatMessage> send(String id, String body) async {
    final d = await _api.post('/conversations/$id/messages', body: {'body': body});
    return ChatMessage.fromJson(d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{});
  }

  Future<void> markRead(String id) => _api.post('/conversations/$id/read');

  /// Start or reuse a 1:1 conversation with [otherUserId]; returns its id.
  Future<String> startDirect(String otherUserId, {String? contextTable, String? contextId}) async {
    final d = await _api.post('/conversations', body: {
      'userId': otherUserId,
      if (contextTable != null) 'contextTable': contextTable,
      if (contextId != null) 'contextId': contextId,
    });
    final m = d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    return '${m['id'] ?? ''}';
  }
}
