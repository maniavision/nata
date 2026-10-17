import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Which filter tab a notification belongs to (besides "All").
enum NotificationCategory { requests, trips, payments, other }

/// One entry of the signed-in user's notifications (`nata.notifications`).
class AppNotification {
  final String id;

  /// 'request', 'trip', 'payment', 'message', 'verification' or 'system'.
  final String type;
  final String title;
  final String body;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;

  /// What happened (e.g. 'request_accepted'), with the names, route or
  /// amount to write it in the user's language. Empty for older rows, which
  /// only have [title] and [body].
  final Map<String, dynamic> payload;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.isRead,
    required this.createdAt,
    this.payload = const {},
  });

  String? get event => payload['event'] as String?;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final image = (j['image_url'] as String?)?.trim();
    return AppNotification(
      id: j['id'] as String,
      type: (j['type'] as String?) ?? 'system',
      title: (j['title'] as String?) ?? '',
      body: (j['body'] as String?) ?? '',
      imageUrl: (image == null || image.isEmpty) ? null : image,
      isRead: (j['is_read'] as bool?) ?? false,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      payload: j['payload'] is Map
          ? Map<String, dynamic>.from(j['payload'] as Map)
          : const {},
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    imageUrl: imageUrl,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    payload: payload,
  );

  NotificationCategory get category {
    switch (type) {
      case 'request':
        return NotificationCategory.requests;
      case 'trip':
        return NotificationCategory.trips;
      case 'payment':
        return NotificationCategory.payments;
      default:
        return NotificationCategory.other;
    }
  }
}

/// Reads and updates the signed-in user's notifications.
///
/// Needs `supabase/migrations/20240112_notifications.sql`.
class NotificationService {
  final SupabaseClient _client;

  NotificationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Not signed in');
    return id;
  }

  /// Newest first.
  Future<List<AppNotification>> list({int limit = 100}) async {
    final uid = _userId; // fail first if nobody is signed in
    final rows =
        await _client
                .schema('nata')
                .from('notifications')
                .select(
                  'id, type, title, body, image_url, is_read, created_at, payload',
                )
                .eq('user_id', uid)
                .order('created_at', ascending: false)
                .limit(limit)
            as List<dynamic>;
    return rows
        .map(
          (r) => AppNotification.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  Future<void> markRead(String id) async {
    try {
      await _client
          .schema('nata')
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('[NotificationService] markRead error: $e');
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    try {
      await _client
          .schema('nata')
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[NotificationService] markAllRead error: $e');
      rethrow;
    }
  }
}
