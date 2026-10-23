import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trip_service.dart' show PickedReceipt;

/// One row of the Messages list (`public.list_conversations`).
class ConversationSummary {
  final String id;
  final String requestId;
  final String otherUserId;
  final String otherFirstName;
  final String otherLastName;
  final String? otherAvatarPath;
  final bool otherVerified;

  /// True when the signed-in user is the traveler (so the other person is the
  /// sender of the parcel).
  final bool iAmTraveler;
  final String departureCity;
  final String arrivalCity;
  final String itemDescription;

  /// `nata.delivery_requests.status`.
  final String requestStatus;
  final String? lastBody;
  final String? lastAttachmentPath;
  final DateTime? lastMessageAt;
  final String? lastAuthorId;
  final int unreadCount;
  final DateTime createdAt;

  const ConversationSummary({
    required this.id,
    required this.requestId,
    required this.otherUserId,
    required this.otherFirstName,
    required this.otherLastName,
    required this.otherAvatarPath,
    required this.otherVerified,
    required this.iAmTraveler,
    required this.departureCity,
    required this.arrivalCity,
    required this.itemDescription,
    required this.requestStatus,
    required this.lastBody,
    required this.lastAttachmentPath,
    required this.lastMessageAt,
    required this.lastAuthorId,
    required this.unreadCount,
    required this.createdAt,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> j) {
    String? clean(Object? v) {
      final t = (v as String?)?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return ConversationSummary(
      id: j['conversation_id'] as String,
      requestId: j['request_id'] as String,
      otherUserId: (j['other_user_id'] as String?) ?? '',
      otherFirstName: (j['other_first_name'] as String?)?.trim() ?? '',
      otherLastName: (j['other_last_name'] as String?)?.trim() ?? '',
      otherAvatarPath: clean(j['other_avatar_path']),
      otherVerified: (j['other_verified'] as bool?) ?? false,
      iAmTraveler: (j['i_am_traveler'] as bool?) ?? false,
      departureCity: (j['departure_city'] as String?)?.trim() ?? '',
      arrivalCity: (j['arrival_city'] as String?)?.trim() ?? '',
      itemDescription: (j['item_description'] as String?)?.trim() ?? '',
      requestStatus: (j['request_status'] as String?) ?? 'pending',
      lastBody: clean(j['last_body']),
      lastAttachmentPath: clean(j['last_attachment_path']),
      lastMessageAt: j['last_message_at'] == null
          ? null
          : DateTime.parse(j['last_message_at'] as String).toLocal(),
      lastAuthorId: j['last_author_id'] as String?,
      unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    );
  }

  /// "Amara K." (first name and the initial of the last name).
  String get displayName {
    if (otherLastName.isEmpty) {
      return otherFirstName.isEmpty ? '—' : otherFirstName;
    }
    return '$otherFirstName ${otherLastName[0].toUpperCase()}.'.trim();
  }

  String get routeLabel => '$departureCity → $arrivalCity';

  bool get hasUnread => unreadCount > 0;

  /// Still in progress: waiting for an answer, accepted, paid or handed over.
  bool get isActive => const {
    'pending',
    'accepted',
    'paid',
    'handed_off',
  }.contains(requestStatus);

  bool get isCompleted => requestStatus == 'delivered';

  /// Chat opens once the sender has paid (the money is then in escrow) and
  /// closes once the item is delivered; what was said stays readable. The
  /// database enforces the same (nata.chat_unlocked, 20240164).
  bool get chatUnlocked => const {'paid', 'handed_off'}.contains(requestStatus);

  /// Paid, and the money is held until delivery is confirmed.
  bool get escrowFunded => const {'paid', 'handed_off'}.contains(requestStatus);

  /// The time the list is ordered and labelled by.
  DateTime get activityAt => lastMessageAt ?? createdAt;

  bool get hasMessages => lastBody != null || lastAttachmentPath != null;
}

/// How a message is doing on its way to the server (only for the user's own).
enum MessageDelivery { sent, sending, failed }

/// One message in a conversation (`nata.messages`).
class ChatMessage {
  final String id;
  final String conversationId;
  final String authorId;
  final String? body;
  final String? attachmentPath;
  final DateTime? readAt;
  final DateTime createdAt;
  final MessageDelivery delivery;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.authorId,
    required this.body,
    required this.attachmentPath,
    required this.readAt,
    required this.createdAt,
    this.delivery = MessageDelivery.sent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    String? clean(Object? v) {
      final t = (v as String?);
      return (t == null || t.trim().isEmpty) ? null : t;
    }

    return ChatMessage(
      id: j['id'] as String,
      conversationId: j['conversation_id'] as String,
      authorId: j['author_id'] as String,
      body: clean(j['body']),
      attachmentPath: clean(j['attachment_path']),
      readAt: j['read_at'] == null
          ? null
          : DateTime.parse(j['read_at'] as String).toLocal(),
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    );
  }

  ChatMessage copyWith({MessageDelivery? delivery, String? id}) => ChatMessage(
    id: id ?? this.id,
    conversationId: conversationId,
    authorId: authorId,
    body: body,
    attachmentPath: attachmentPath,
    readAt: readAt,
    createdAt: createdAt,
    delivery: delivery ?? this.delivery,
  );

  bool get hasAttachment => attachmentPath != null;
  bool get isRead => readAt != null;
}

/// Conversations and messages of the signed-in user.
///
/// Needs `supabase/migrations/20240113_messaging.sql`.
class MessageService {
  final SupabaseClient _client;

  /// Signed links to private photos, kept until shortly before they expire so
  /// the same photo keeps the same address (which lets images be cached).
  final Map<String, ({String url, DateTime expires})> _urlCache = {};

  static const _bucket = 'chat-attachments';
  static const _signedUrlLifetime = Duration(hours: 1);

  MessageService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// The signed-in user, or null.
  String? get currentUserId => _client.auth.currentUser?.id;

  String get _userId {
    final id = currentUserId;
    if (id == null) throw Exception('Not signed in');
    return id;
  }

  /// Every conversation of the user, most recent activity first.
  Future<List<ConversationSummary>> conversations() async {
    _userId; // fail clearly when nobody is signed in
    final rows = await _client.rpc('list_conversations') as List<dynamic>;
    return rows
        .map(
          (r) =>
              ConversationSummary.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  /// The latest [limit] messages of a conversation, oldest first.
  Future<List<ChatMessage>> messages(
    String conversationId, {
    int limit = 300,
  }) async {
    final rows =
        await _client
                .schema('nata')
                .from('messages')
                .select(
                  'id, conversation_id, author_id, body, attachment_path, '
                  'read_at, created_at',
                )
                .eq('conversation_id', conversationId)
                .order('created_at', ascending: false)
                .limit(limit)
            as List<dynamic>;
    final list = rows
        .map((r) => ChatMessage.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    return list.reversed.toList();
  }

  /// Sends a text and/or a photo (at least one). Returns the saved message.
  Future<ChatMessage> send(
    String conversationId, {
    String? body,
    String? attachmentPath,
  }) async {
    final text = body?.trim();
    final hasText = text != null && text.isNotEmpty;
    if (!hasText && attachmentPath == null) {
      throw ArgumentError('A message needs text or a photo');
    }
    final row = await _client
        .schema('nata')
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'author_id': _userId,
          'body': hasText ? text : null,
          'attachment_path': attachmentPath,
        })
        .select(
          'id, conversation_id, author_id, body, attachment_path, '
          'read_at, created_at',
        )
        .single();
    return ChatMessage.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// Live updates for one open conversation over Supabase Realtime, on the
  /// private channel "chat:<id>" (only its two members may join it; see
  /// migration 20240158): [onChange] when a message arrives or one is read,
  /// [onTyping] when the other person is typing. Null if it can't connect;
  /// the chat then keeps refreshing on a timer.
  ChatLive? live(
    String conversationId, {
    required void Function() onChange,
    required void Function() onTyping,
  }) {
    final me = currentUserId;
    if (me == null) return null;
    try {
      final channel = _client.channel(
        'chat:$conversationId',
        opts: const RealtimeChannelConfig(private: true),
      );
      channel
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'nata',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) => onChange(),
        )
        ..onBroadcast(
          event: 'typing',
          callback: (payload) {
            if (payload['user'] != me) onTyping();
          },
        )
        ..subscribe();
      return _RealtimeChatLive(_client, channel, me);
    } catch (e) {
      debugPrint('[MessageService] live error: $e');
      return null;
    }
  }

  /// Marks what the other person wrote as read.
  Future<void> markRead(String conversationId) async {
    try {
      await _client.rpc(
        'mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
    } catch (e) {
      debugPrint('[MessageService] markRead error: $e');
    }
  }

  /// Uploads a photo to the private chat bucket; returns its storage path.
  Future<String> uploadAttachment(
    String conversationId,
    PickedReceipt photo,
  ) async {
    final path =
        '$conversationId/${DateTime.now().millisecondsSinceEpoch}.${photo.extension.toLowerCase()}';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          photo.bytes,
          fileOptions: FileOptions(contentType: photo.contentType),
        );
    return path;
  }

  /// A temporary link to a photo in the private bucket.
  Future<String> attachmentUrl(String path) async {
    final cached = _urlCache[path];
    if (cached != null &&
        cached.expires.isAfter(
          DateTime.now().add(const Duration(minutes: 5)),
        )) {
      return cached.url;
    }
    final url = await _client.storage
        .from(_bucket)
        .createSignedUrl(path, _signedUrlLifetime.inSeconds);
    _urlCache[path] = (
      url: url,
      expires: DateTime.now().add(_signedUrlLifetime),
    );
    return url;
  }
}

/// An open chat's live connection (see [MessageService.live]).
abstract class ChatLive {
  /// Tells the other person this user is typing. Sent at most every few
  /// seconds however often it is called.
  void typing();

  Future<void> close();
}

class _RealtimeChatLive implements ChatLive {
  _RealtimeChatLive(this._client, this._channel, this._me);

  final SupabaseClient _client;
  final RealtimeChannel _channel;
  final String _me;
  DateTime _lastTyping = DateTime.fromMillisecondsSinceEpoch(0);

  static const _typingEvery = Duration(seconds: 2);

  @override
  void typing() {
    final now = DateTime.now();
    if (now.difference(_lastTyping) < _typingEvery) return;
    _lastTyping = now;
    _channel
        .sendBroadcastMessage(event: 'typing', payload: {'user': _me})
        .catchError((Object e) {
          debugPrint('[MessageService] typing error: $e');
          return ChannelResponse.error;
        });
  }

  @override
  Future<void> close() => _client.removeChannel(_channel);
}
