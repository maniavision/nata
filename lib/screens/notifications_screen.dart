import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../l10n/notification_text.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/notification_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/avatar_image.dart';
import '../widgets/nata_toast.dart';
import 'requests_screen.dart';
import 'chat_thread_screen.dart';
import 'traveler_results_screen.dart';
import '../services/app_badge.dart';
import '../services/screen_cache.dart';
import 'recipient_chat_screen.dart';

/// "2 min ago", "1 hr ago", "Yesterday", "Jun 12" ...
String notificationTimeLabel(AppLocalizations l, DateTime now, DateTime then) {
  final diff = now.difference(then);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);

  final today = DateTime(now.year, now.month, now.day);
  final thenDay = DateTime(then.year, then.month, then.day);
  final days = today.difference(thenDay).inDays;
  if (days == 0) return l.hoursAgo(diff.inHours);
  if (days == 1) return l.yesterdayLabel;
  return (then.year == now.year
          ? DateFormat('MMM d')
          : DateFormat('MMM d, yyyy'))
      .format(then);
}

/// The notifications opened from the bell on Home.
class NotificationsScreen extends StatefulWidget {
  /// Overrides for tests.
  final NotificationService? service;
  final DateTime Function()? now;

  /// Builds the Requests page a notification opens, on [tab]. Defaults to
  /// [RequestsScreen].
  final Widget Function(int tab)? requestsBuilder;

  /// Builds the chat a message notification opens. Defaults to
  /// [ChatFromNotification].
  final Widget Function(String conversationId)? chatBuilder;

  /// Builds the search a route alert opens. Defaults to
  /// [resultsForRouteAlert].
  final Widget? Function(Map<String, dynamic> payload)? routeResultsBuilder;

  const NotificationsScreen({
    super.key,
    this.service,
    this.now,
    this.requestsBuilder,
    this.chatBuilder,
    this.routeResultsBuilder,
  });

  /// Where the notifications are kept between visits (ScreenCache).
  static const cacheKey = 'notifications';

  /// Loads the notifications ahead of a first visit (from Home).
  static Future<void> preload([NotificationService? service]) async {
    if (ScreenCache.read<List<AppNotification>>(cacheKey) != null) return;
    final items = await (service ?? NotificationService()).list();
    ScreenCache.write(cacheKey, items);
  }

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// What was shown last time shows straight away; the list is refreshed
  /// behind it, and every change is kept for the next visit.
  List<AppNotification> _shown =
      ScreenCache.read<List<AppNotification>>(NotificationsScreen.cacheKey) ??
      const [];
  List<AppNotification> get _items => _shown;
  set _items(List<AppNotification> items) {
    _shown = items;
    ScreenCache.write(NotificationsScreen.cacheKey, items);
  }

  late bool _loading =
      ScreenCache.read<List<AppNotification>>(NotificationsScreen.cacheKey) ==
      null;
  bool _failed = false;

  /// Bumped when a delete fails, so the card comes back as a new swipeable.
  int _restores = 0;

  /// 0 = All, 1 = Requests, 2 = Trips, 3 = Payments
  int _filter = 0;

  static const _filterCategories = <NotificationCategory?>[
    null,
    NotificationCategory.requests,
    NotificationCategory.trips,
    NotificationCategory.payments,
  ];

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  NotificationService get _service => widget.service ?? NotificationService();

  Future<void> _load() async {
    try {
      final items = await _service.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _failed = false;
      });
      unawaited(AppBadge.refresh());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _load();
  }

  bool get _hasUnread => _items.any((n) => !n.isRead);

  List<AppNotification> get _visible {
    final category = _filterCategories[_filter];
    return category == null
        ? _items
        : _items.where((n) => n.category == category).toList();
  }

  /// Marks it read and, when it is about a request, opens that side of
  /// Requests; a new message opens its chat.
  void _open(AppNotification n) {
    _markRead(n);
    if (n.event == 'trip_match') {
      final results =
          widget.routeResultsBuilder?.call(n.payload) ??
          resultsForRouteAlert(n.payload);
      if (results != null) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => results));
      }
      return;
    }
    final request = n.payload['request_id'] as String?;
    if ((n.event == 'recipient_message' || n.event == 'recipient_message_in') &&
        request != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecipientChatScreen(
            requestId: request,
            asRecipient: n.event == 'recipient_message_in',
          ),
        ),
      );
      return;
    }
    final chat = n.payload['conversation_id'] as String?;
    if (n.event == 'message_new' && chat != null && chat.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              widget.chatBuilder?.call(chat) ??
              ChatFromNotification(conversationId: chat),
        ),
      );
      return;
    }
    final tab = requestsTabFor(n);
    if (tab == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            widget.requestsBuilder?.call(tab) ??
            RequestsScreen(initialTab: tab),
      ),
    );
  }

  // Optimistic: the dot disappears at once; if saving fails it comes back.
  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    _replace(n.id, (x) => x.copyWith(isRead: true));
    try {
      await _service.markRead(n.id);
    } catch (_) {
      if (mounted) _replace(n.id, (x) => x.copyWith(isRead: false));
    }
    unawaited(AppBadge.refresh());
  }

  Future<void> _markAllRead() async {
    if (!_hasUnread) return;
    final before = _items;
    setState(() => _items = [for (final n in _items) n.copyWith(isRead: true)]);
    try {
      await _service.markAllRead();
    } catch (_) {
      if (mounted) setState(() => _items = before);
    }
    unawaited(AppBadge.refresh());
  }

  // Optimistic: the card goes at once; if deleting fails it comes back.
  Future<void> _delete(AppNotification n) async {
    final before = _items;
    setState(
      () => _items = [
        for (final x in _items)
          if (x.id != n.id) x,
      ],
    );
    try {
      await _service.delete(n.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = before;
        _restores++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        nataToast(context.l10n.errNotifDelete, tone: ToastTone.error),
      );
    }
    unawaited(AppBadge.refresh());
  }

  void _replace(String id, AppNotification Function(AppNotification) f) {
    setState(() => _items = [for (final n in _items) n.id == id ? f(n) : n]);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildFilters(),
                Expanded(child: _buildBody()),
              ],
            ),
            // No tab is highlighted: this page belongs to none of them.
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AppBottomNav(current: -1, isTabRoot: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('notif-back'),
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                size: 22,
                color: AppColors.foreground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.notifications,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.foreground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              key: const ValueKey('notif-mark-all'),
              onTap: _hasUnread ? _markAllRead : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l.markAllRead,
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _hasUnread
                        ? AppColors.accent
                        : AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final l = context.l10n;
    final labels = [l.notifFilterAll, l.requests, l.trips, l.paymentsFilter];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = _filter == i;
          return GestureDetector(
            key: ValueKey('notif-filter-$i'),
            onTap: () => setState(() => _filter = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(999),
                border: active ? null : Border.all(color: AppColors.border),
              ),
              child: Text(
                labels[i],
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: active
                      ? AppColors.primaryForeground
                      : AppColors.mutedForeground,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final l = context.l10n;
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2.5,
        ),
      );
    }
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(height: 10),
              Text(
                l.couldNotLoadNotifications,
                key: const ValueKey('notif-error'),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _retry, child: Text(l.retry)),
            ],
          ),
        ),
      );
    }

    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    bool isToday(AppNotification n) =>
        DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day) == today;

    final visible = _visible;
    final todayItems = visible.where(isToday).toList();
    final earlier = visible.where((n) => !isToday(n)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          if (visible.isEmpty) _buildEmpty(),
          if (todayItems.isNotEmpty) ...[
            _sectionTitle(l.notifToday),
            for (final n in todayItems) _card(n, now),
          ],
          if (earlier.isNotEmpty) ...[
            if (todayItems.isNotEmpty) const SizedBox(height: 8),
            _sectionTitle(l.notifEarlier),
            for (final n in earlier) _card(n, now),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final l = context.l10n;
    return Padding(
      key: const ValueKey('notif-empty'),
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 40,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(height: 10),
          Text(
            l.noNotifications,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.noNotificationsSub,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.mutedForeground,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.7,
        color: AppColors.mutedForeground,
      ),
    ),
  );

  // ── Leading icon / avatar per type ─────────────────────────────────────────
  Widget _leading(AppNotification n) {
    Widget circle(IconData icon, Color color) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );

    if (n.type == 'message') {
      final fallback = circle(Icons.chat_bubble_rounded, AppColors.primary);
      if (n.imageUrl == null) return fallback;
      return SizedBox(
        width: 40,
        height: 40,
        child: ClipOval(
          child: AvatarImage(path: n.imageUrl, fallback: fallback),
        ),
      );
    }
    switch (n.type) {
      case 'request':
        return circle(Icons.check_circle_rounded, AppColors.accent);
      case 'payment':
        return circle(
          Icons.account_balance_wallet_rounded,
          const Color(0xFF168A68),
        );
      case 'trip':
        return circle(Icons.luggage_rounded, AppColors.primary);
      case 'verification':
        return circle(Icons.verified_user_rounded, const Color(0xFFE5A83B));
      default:
        return circle(Icons.notifications_rounded, AppColors.mutedForeground);
    }
  }

  Widget _card(AppNotification n, DateTime now) {
    final l = context.l10n;
    final (title, body) = notificationText(l, n);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('notif-swipe-${n.id}-$_restores'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _delete(n),
        background: _deleteBackground(),
        child: _cardBody(n, now, title, body),
      ),
    );
  }

  /// Behind a card being swiped left: the delete action.
  Widget _deleteBackground() => Container(
    alignment: AlignmentDirectional.centerEnd,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: AppColors.destructive,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 6),
        Text(
          context.l10n.notifDelete,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _cardBody(AppNotification n, DateTime now, String title, String body) {
    final l = context.l10n;
    return GestureDetector(
      key: ValueKey('notif-${n.id}'),
      onTap: () => _open(n),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _leading(n),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      if (!n.isRead) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            key: ValueKey('notif-unread-${n.id}'),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: n.type == 'message' ? 1 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    notificationTimeLabel(l, now, n.createdAt),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
