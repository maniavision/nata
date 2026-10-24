import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/message_service.dart';
import '../services/screen_cache.dart';
import '../services/unread_messages.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/avatar_image.dart';
import 'chat_thread_screen.dart';
import 'notifications_screen.dart' show notificationTimeLabel;

/// The user's conversations, one per delivery request.
class MessagesScreen extends StatefulWidget {
  /// Overrides for tests.
  final MessageService? service;
  final DateTime Function()? now;

  /// How often the list quietly refreshes while it is on screen.
  final Duration refreshEvery;

  const MessagesScreen({
    super.key,
    this.service,
    this.now,
    this.refreshEvery = const Duration(seconds: 15),
  });

  /// Where the conversations are kept between visits (ScreenCache).
  static const cacheKey = 'conversations';

  /// Loads the conversations ahead of a first visit (from Home).
  static Future<void> preload([MessageService? service]) async {
    if (ScreenCache.read<List<ConversationSummary>>(cacheKey) != null) return;
    final items = await (service ?? MessageService()).conversations();
    ScreenCache.write(cacheKey, items);
  }

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  List<ConversationSummary> _items = const [];
  bool _loading = true;
  bool _failed = false;

  /// 0 = All, 1 = Active, 2 = Completed
  int _filter = 0;
  final _searchCtrl = TextEditingController();
  String _query = '';

  Timer? _timer;
  bool _refreshing = false;

  MessageService get _service => widget.service ?? MessageService();
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    // What this page showed last time, straight away; then the latest.
    final cached = ScreenCache.read<List<ConversationSummary>>(
      MessagesScreen.cacheKey,
    );
    if (cached != null) {
      _items = cached;
      _loading = false;
    }
    _load(quiet: cached != null);
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.refreshEvery, (_) {
      if (!mounted) return;
      // Nothing to refresh while a chat is open on top of this list.
      if (ModalRoute.of(context)?.isCurrent == false) return;
      _load(quiet: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _load(quiet: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
    }
  }

  /// [quiet] refreshes keep what is on screen if they fail.
  Future<void> _load({bool quiet = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final items = await _service.conversations();
      ScreenCache.write(MessagesScreen.cacheKey, items);
      UnreadMessages.update(items);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || quiet) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    } finally {
      _refreshing = false;
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _load();
  }

  Future<void> _open(ConversationSummary c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatThreadScreen(conversation: c, service: widget.service),
      ),
    );
    // What was read (or sent) in the chat shows up straight away.
    if (mounted) _load(quiet: true);
  }

  // ── Derived lists ──────────────────────────────────────────────────────────
  int get _unreadTotal => _items.fold(0, (sum, c) => sum + c.unreadCount);
  int get _activeCount => _items.where((c) => c.isActive).length;
  int get _completedCount => _items.where((c) => c.isCompleted).length;

  bool _matches(ConversationSummary c) {
    if (_query.isEmpty) return true;
    final haystack = [
      c.otherFirstName,
      c.otherLastName,
      c.displayName,
      c.departureCity,
      c.arrivalCity,
      c.itemDescription,
      c.lastBody ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(_query);
  }

  List<ConversationSummary> get _visible => _items.where((c) {
    switch (_filter) {
      case 1:
        if (!c.isActive) return false;
      case 2:
        if (!c.isCompleted) return false;
    }
    return _matches(c);
  }).toList();

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
                _buildFilterRow(),
                Expanded(child: _buildBody()),
              ],
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AppBottomNav(current: 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.messagesTitle,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.4,
              color: AppColors.foreground,
            ),
          ),
          if (!_loading && !_failed)
            Text(
              _unreadTotal > 0
                  ? l.unreadMessagesCount(_unreadTotal)
                  : l.messagesCaughtUp,
              key: const ValueKey('messages-subtitle'),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: _unreadTotal > 0
                    ? AppColors.accent
                    : AppColors.mutedForeground,
                fontWeight: _unreadTotal > 0
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.input,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('messages-search'),
                    controller: _searchCtrl,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.foreground,
                    ),
                    decoration: InputDecoration(
                      hintText: l.searchChats,
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    key: const ValueKey('messages-search-clear'),
                    onTap: _searchCtrl.clear,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final l = context.l10n;
    final labels = [
      l.filterAllCount(_items.length),
      l.filterActiveCount(_activeCount),
      l.filterCompletedCount(_completedCount),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        itemCount: labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = _filter == i;
          return GestureDetector(
            key: ValueKey('messages-filter-$i'),
            onTap: () => setState(() => _filter = i),
            // The row is 40 high and stretches each chip to it: keep the
            // label in the middle.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                labels[i],
                style: GoogleFonts.dmSans(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                  color: active
                      ? AppColors.primaryForeground
                      : AppColors.foreground,
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
                l.couldNotLoadMessages,
                key: const ValueKey('messages-error'),
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

    final visible = _visible;
    final now = _now;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: visible.isEmpty ? 1 : visible.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (visible.isEmpty) return _buildEmpty();
          final c = visible[i];
          return _ConversationTile(
            conversation: c,
            currentUserId: _service.currentUserId,
            timeLabel: notificationTimeLabel(l, now, c.activityAt),
            onTap: () => _open(c),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    final l = context.l10n;
    final noChatsAtAll = _items.isEmpty;
    return Padding(
      key: ValueKey(noChatsAtAll ? 'messages-empty' : 'messages-no-match'),
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 40,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(height: 10),
          Text(
            noChatsAtAll ? l.noConversations : l.noChatMatches,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.foreground,
            ),
          ),
          if (noChatsAtAll) ...[
            const SizedBox(height: 4),
            Text(
              l.noConversationsSub,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.mutedForeground,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Conversation tile ──────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final ConversationSummary conversation;
  final String? currentUserId;
  final String timeLabel;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.timeLabel,
    required this.onTap,
  });

  static const _green = Color(0xFF168A68);
  static const _greenBg = Color(0xFFE4F4EE);

  String _preview(BuildContext context) {
    final l = context.l10n;
    final c = conversation;
    if (!c.hasMessages) return l.chatEmpty;
    final text = c.lastBody ?? '📷 ${l.chatPhotoLabel}';
    return c.lastAuthorId != null && c.lastAuthorId == currentUserId
        ? l.chatYouPrefix(text)
        : text;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = conversation;
    final unread = c.hasUnread;
    final fallback = Container(
      color: AppColors.secondary,
      child: const Icon(Icons.person, color: AppColors.primary),
    );

    return GestureDetector(
      key: ValueKey('conversation-${c.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: unread
              ? AppColors.accent.withValues(alpha: 0.05)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unread
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.border,
            width: unread ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: unread ? AppColors.accent : AppColors.border,
                  width: unread ? 2 : 1,
                ),
              ),
              child: ClipOval(
                child: AvatarImage(path: c.otherAvatarPath, fallback: fallback),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: AppColors.foreground,
                                ),
                              ),
                            ),
                            if (c.otherVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: _green,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: unread
                              ? AppColors.accent
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.isCompleted
                                ? AppColors.input
                                : (c.isActive ? _greenBg : AppColors.secondary),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.routeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              color: c.isCompleted
                                  ? AppColors.mutedForeground
                                  : (c.isActive ? _green : AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (c.escrowFunded) ...[
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 11,
                          color: _green,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Expanded(
                        child: Text(
                          c.isCompleted
                              ? '${l.tripCompleted} ✓'
                              : c.escrowFunded
                              ? l.escrowFunded
                              : c.itemDescription,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontWeight: c.isCompleted
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 10,
                            color: c.isCompleted
                                ? _green
                                : AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _preview(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 12,
                      color: unread
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (unread)
              Container(
                key: ValueKey('unread-${c.id}'),
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.all(Radius.circular(9)),
                ),
                child: Text(
                  '${c.unreadCount}',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: AppColors.accentForeground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
