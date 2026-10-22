import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/request_service.dart';
import '../services/message_service.dart';
import '../services/trip_service.dart' show PickedReceipt;
import '../widgets/avatar_image.dart';
import '../widgets/camera_denied_sheet.dart';
import 'messages_screen.dart';
import '../widgets/nata_toast.dart';
import '../services/app_badge.dart';

/// Takes or chooses a photo to send. [camera] true = take one with the camera.
/// Replaceable in tests.
typedef ChatPhotoPicker =
    Future<PickedReceipt?> Function({required bool camera});

/// One conversation: the messages between a sender and a traveler.
class ChatThreadScreen extends StatefulWidget {
  final ConversationSummary conversation;

  /// Overrides for tests.
  final MessageService? service;
  final RequestService? requestService;
  final ChatPhotoPicker? photoPicker;
  final DateTime Function()? now;

  /// How often new messages are fetched while the chat is open and the live
  /// connection is not available.
  final Duration refreshEvery;

  /// With the live connection, a slower safety refresh.
  final Duration liveRefreshEvery;

  const ChatThreadScreen({
    super.key,
    required this.conversation,
    this.service,
    this.requestService,
    this.photoPicker,
    this.now,
    this.refreshEvery = const Duration(seconds: 4),
    this.liveRefreshEvery = const Duration(seconds: 30),
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen>
    with WidgetsBindingObserver {
  static const _green = Color(0xFF168A68);
  static const _maxPhotoBytes = 10 * 1024 * 1024;

  final _inputCtrl = TextEditingController();

  /// What the server has, oldest first.
  List<ChatMessage> _server = const [];

  /// Messages the user just sent that the server has not confirmed yet (or
  /// that failed). Kept apart so a refresh never wipes them.
  final List<ChatMessage> _local = [];
  final Map<String, Uint8List> _localPhotoBytes = {};
  final Map<String, PickedReceipt> _localPhotos = {};
  int _localCounter = 0;

  bool _loading = true;
  bool _failed = false;
  bool _loadingNow = false;
  String? _notice;

  Timer? _timer;

  /// New messages, read receipts and typing, as they happen.
  ChatLive? _live;

  /// The other person is typing (cleared a few seconds after the last sign).
  bool _otherTyping = false;
  Timer? _typingTimer;
  static const _typingShownFor = Duration(seconds: 4);

  MessageService get _service => widget.service ?? MessageService();
  DateTime get _now => (widget.now ?? DateTime.now)();
  String? get _me => _service.currentUserId;
  ConversationSummary get _c => widget.conversation;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addObserver(this);
    _connect();
    _startTimer();
  }

  void _connect() {
    try {
      _live = _service.live(
        _c.id,
        onChange: () {
          if (mounted) _load(quiet: true);
        },
        onTyping: () {
          if (!mounted) return;
          _typingTimer?.cancel();
          _typingTimer = Timer(_typingShownFor, () {
            if (mounted) setState(() => _otherTyping = false);
          });
          if (!_otherTyping) setState(() => _otherTyping = true);
        },
      );
    } catch (e) {
      debugPrint('[Chat] live unavailable: $e');
      _live = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _typingTimer?.cancel();
    unawaited(_live?.close());
    _inputCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      _live == null ? widget.refreshEvery : widget.liveRefreshEvery,
      (_) {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent == false) return;
        _load(quiet: true);
      },
    );
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

  Future<void> _load({bool quiet = false}) async {
    if (_loadingNow) return;
    _loadingNow = true;
    try {
      final messages = await _service.messages(_c.id);
      if (!mounted) return;
      final me0 = _me;
      final theyWrote =
          messages.length > _server.length && messages.last.authorId != me0;
      setState(() {
        _server = messages;
        _loading = false;
        _failed = false;
        if (theyWrote) _otherTyping = false;
      });
      // Anything the other person wrote is now seen.
      final me = _me;
      if (messages.any((m) => m.authorId != me && m.readAt == null)) {
        // Reading the chat also reads its message notifications: the app
        // icon badge goes down with them.
        unawaited(_service.markRead(_c.id).whenComplete(AppBadge.refresh));
      }
    } catch (_) {
      if (!mounted || quiet) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    } finally {
      _loadingNow = false;
    }
  }

  void _retryLoad() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _load();
  }

  // ── Sending ────────────────────────────────────────────────────────────────
  ChatMessage _newLocal({String? body, String? attachmentPath}) {
    return ChatMessage(
      id: 'local-${_localCounter++}',
      conversationId: _c.id,
      authorId: _me ?? '',
      body: body,
      attachmentPath: attachmentPath,
      readAt: null,
      createdAt: _now,
      delivery: MessageDelivery.sending,
    );
  }

  void _replaceLocal(
    String localId,
    ChatMessage? sent, {
    MessageDelivery? delivery,
  }) {
    if (!mounted) return;
    setState(() {
      final i = _local.indexWhere((m) => m.id == localId);
      if (i < 0) return;
      if (sent != null) {
        _local.removeAt(i);
        _localPhotoBytes.remove(localId);
        _localPhotos.remove(localId);
        if (!_server.any((m) => m.id == sent.id)) {
          _server = [..._server, sent];
        }
      } else {
        _local[i] = _local[i].copyWith(delivery: delivery);
      }
    });
  }

  Future<void> _sendText() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    final local = _newLocal(body: text);
    setState(() => _local.add(local));
    await _deliver(local);
  }

  Future<void> _deliver(ChatMessage local) async {
    try {
      var attachmentPath = local.attachmentPath;
      final photo = _localPhotos[local.id];
      if (photo != null) {
        attachmentPath = await _service.uploadAttachment(_c.id, photo);
      }
      final sent = await _service.send(
        _c.id,
        body: local.body,
        attachmentPath: attachmentPath,
      );
      _replaceLocal(local.id, sent);
    } catch (_) {
      _replaceLocal(local.id, null, delivery: MessageDelivery.failed);
    }
  }

  void _retry(ChatMessage failed) {
    if (failed.delivery != MessageDelivery.failed) return;
    _replaceLocal(failed.id, null, delivery: MessageDelivery.sending);
    _deliver(failed);
  }

  Future<void> _sendPhoto({required bool camera}) async {
    try {
      final picked = await (widget.photoPicker ?? _defaultPhotoPicker)(
        camera: camera,
      );
      if (picked == null || !mounted) return;
      if (picked.sizeBytes > _maxPhotoBytes) {
        setState(() => _notice = context.l10n.chatPhotoFailed);
        return;
      }
      final local = _newLocal(attachmentPath: 'pending');
      setState(() {
        _notice = null;
        _local.add(local);
        _localPhotoBytes[local.id] = picked.bytes;
        _localPhotos[local.id] = picked;
      });
      await _deliver(local);
    } catch (e) {
      if (mounted && isCameraDenied(e)) {
        await showCameraDeniedSheet(context);
      } else if (mounted) {
        setState(() => _notice = context.l10n.chatCameraFailed);
      }
    }
  }

  static Future<PickedReceipt?> _defaultPhotoPicker({
    required bool camera,
  }) async {
    final photo = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (photo == null) return null;
    final name = photo.name.isEmpty ? 'photo.jpg' : photo.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    return PickedReceipt(
      bytes: await photo.readAsBytes(),
      name: name,
      extension: ext,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  List<ChatMessage> get _all {
    final list = [..._server, ..._local];
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildDeliveryCard(),
          Expanded(child: _buildBody()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final c = _c;
    final fallback = Container(
      color: AppColors.secondary,
      child: const Icon(Icons.person, color: AppColors.primary),
    );
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.95),
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.7),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              key: const ValueKey('chat-back'),
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _green, width: 2),
              ),
              child: ClipOval(
                child: AvatarImage(path: c.otherAvatarPath, fallback: fallback),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.displayName,
                          key: const ValueKey('chat-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
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
                  Text(
                    _otherTyping
                        ? context.l10n.chatTyping
                        : c.itemDescription.isEmpty
                        ? c.routeLabel
                        : '${c.routeLabel} · ${c.itemDescription}',
                    key: const ValueKey('chat-subtitle'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: _otherTyping ? AppColors.accent : _green,
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

  // ── Delivery card ──────────────────────────────────────────────────────────
  /// Where the delivery stands (paid, picked up, delivered), and for the
  /// sender a way to see the delivery code.
  Widget _buildDeliveryCard() {
    final l = context.l10n;
    final status = _c.requestStatus;
    final step = switch (status) {
      'paid' => 1,
      'handed_off' => 2,
      'delivered' => 3,
      _ => 0,
    };
    if (step == 0) return const SizedBox.shrink();
    final labels = [l.statusPaid, l.pickedUp, l.statusDelivered];
    final showCode = !_c.iAmTraveler && step < 3;

    return Container(
      key: const ValueKey('chat-delivery-card'),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: i < step ? _green : AppColors.border,
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      i < step
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: i < step ? _green : AppColors.mutedForeground,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labels[i],
                      style: GoogleFonts.dmSans(
                        fontWeight: i < step
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 10,
                        color: i < step
                            ? AppColors.foreground
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (showCode) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                key: const ValueKey('chat-view-code'),
                onPressed: _showCode,
                icon: const Icon(Icons.key_rounded, size: 16),
                label: Text(
                  l.viewCode,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showCode() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    DeliveryCode? code;
    try {
      code = await (widget.requestService ?? RequestService()).deliveryCode(
        _c.requestId,
      );
    } catch (e) {
      debugPrint('[Chat] delivery code: $e');
    }
    if (!mounted) return;
    if (code == null) {
      messenger.showSnackBar(
        nataToast(l.errRequestFailed, tone: ToastTone.error),
      );
      return;
    }
    final value = code.code;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('chat-code-dialog'),
        title: Text(l.deliveryCode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.split('').join(' '),
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 32,
                letterSpacing: 4,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.chatCodeNote,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.close),
          ),
        ],
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
                l.couldNotLoadChat,
                key: const ValueKey('chat-error'),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _retryLoad, child: Text(l.retry)),
            ],
          ),
        ),
      );
    }

    final messages = _all;
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l.chatEmpty,
            key: const ValueKey('chat-empty'),
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      );
    }

    // Oldest first, with a date chip wherever the day changes; the list is
    // shown upside down so it sits at the newest message without scrolling.
    final entries = <Object>[];
    DateTime? lastDay;
    for (final m in messages) {
      final day = DateTime(
        m.createdAt.year,
        m.createdAt.month,
        m.createdAt.day,
      );
      if (lastDay != day) {
        entries.add(day);
        lastDay = day;
      }
      entries.add(m);
    }
    final reversed = entries.reversed.toList();
    if (_otherTyping) reversed.insert(0, const _TypingMarker());

    return ListView.builder(
      key: const ValueKey('chat-list'),
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: reversed.length,
      itemBuilder: (context, i) {
        final e = reversed[i];
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: e is _TypingMarker
              ? const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TypingBubble(),
                )
              : e is DateTime
              ? _buildDateChip(e)
              : _buildBubble(e as ChatMessage),
        );
      },
    );
  }

  Widget _buildDateChip(DateTime day) {
    final l = context.l10n;
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    final label = diff == 0
        ? l.notifToday
        : diff == 1
        ? l.yesterdayLabel
        : (day.year == now.year
                  ? DateFormat.MMMd(Localizations.localeOf(context).toString())
                  : DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ))
              .format(day);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1.0,
            color: AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }

  // ── Bubbles ────────────────────────────────────────────────────────────────
  Widget _buildBubble(ChatMessage m) {
    final mine = m.authorId == _me;
    final maxWidth = MediaQuery.of(context).size.width * (mine ? 0.78 : 0.72);

    final content = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (m.hasAttachment) ...[
          _AttachmentView(
            message: m,
            service: widget.service,
            localBytes: _localPhotoBytes[m.id],
          ),
          if (m.body != null) const SizedBox(height: 8),
        ],
        if (m.body != null)
          Text(
            m.body!,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.5,
              color: mine ? AppColors.primaryForeground : AppColors.foreground,
            ),
          ),
        const SizedBox(height: 4),
        _buildStatusLine(m, mine),
      ],
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 16 : 4),
          topRight: Radius.circular(mine ? 4 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
        border: mine ? null : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: mine
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: mine ? 6 : 4,
            offset: mine ? const Offset(0, 2) : Offset.zero,
          ),
        ],
      ),
      child: content,
    );

    if (mine) {
      final tappable = m.delivery == MessageDelivery.failed;
      return Row(
        key: ValueKey('msg-${m.id}'),
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: tappable ? () => _retry(m) : null,
            child: bubble,
          ),
        ],
      );
    }

    return Row(
      key: ValueKey('msg-${m.id}'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: ClipOval(
            child: AvatarImage(
              path: _c.otherAvatarPath,
              fallback: Container(color: AppColors.secondary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: bubble),
      ],
    );
  }

  Widget _buildStatusLine(ChatMessage m, bool mine) {
    final l = context.l10n;
    final time = DateFormat('h:mm a').format(m.createdAt);
    String text = time;
    Color color = mine
        ? AppColors.primaryForeground.withValues(alpha: 0.7)
        : AppColors.mutedForeground;
    if (mine) {
      switch (m.delivery) {
        case MessageDelivery.sending:
          text = '$time · ${l.msgSending}';
        case MessageDelivery.failed:
          text = l.msgFailed;
          color = const Color(0xFFFFB4AB);
        case MessageDelivery.sent:
          text = '$time · ${m.isRead ? l.msgRead : l.msgSent}';
      }
    }
    return Text(text, style: GoogleFonts.dmSans(fontSize: 10, color: color));
  }

  // ── Input bar ──────────────────────────────────────────────────────────────
  /// Before payment: no input, just why.
  Widget _buildLockedFooter() {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('chat-locked'),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.6),
          border: const Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            const Icon(
              Icons.lock_rounded,
              size: 16,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.chatLockedUntilPayment,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final l = context.l10n;
    if (!_c.chatUnlocked) return _buildLockedFooter();
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _notice!,
                  key: const ValueKey('chat-notice'),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.destructive,
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  key: const ValueKey('chat-camera'),
                  onTap: () => _sendPhoto(camera: true),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.input,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('chat-input'),
                            controller: _inputCtrl,
                            onChanged: (v) {
                              if (v.trim().isNotEmpty) _live?.typing();
                            },
                            minLines: 1,
                            maxLines: 4,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.foreground,
                            ),
                            decoration: InputDecoration(
                              hintText: l.typeMessage,
                              hintStyle: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: AppColors.mutedForeground,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 11,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        GestureDetector(
                          key: const ValueKey('chat-gallery'),
                          onTap: () => _sendPhoto(camera: false),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.attach_file_rounded,
                              size: 18,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: const ValueKey('chat-send'),
                  onTap: _sendText,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A photo inside a bubble. Photos live in a private bucket, so a temporary
/// link is fetched first. A photo that is still being sent is shown from memory.
class _AttachmentView extends StatefulWidget {
  final ChatMessage message;
  final MessageService? service;
  final Uint8List? localBytes;

  const _AttachmentView({
    required this.message,
    required this.service,
    required this.localBytes,
  });

  @override
  State<_AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends State<_AttachmentView> {
  Future<String>? _url;

  @override
  void initState() {
    super.initState();
    if (widget.localBytes == null) {
      _url = (widget.service ?? MessageService()).attachmentUrl(
        widget.message.attachmentPath!,
      );
    }
  }

  Widget _placeholder({bool loading = false}) => Container(
    width: 200,
    height: 140,
    color: AppColors.secondary,
    alignment: Alignment.center,
    child: loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.chatPhotoLoadFailed,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
  );

  void _openFullScreen(ImageProvider image) {
    showDialog<void>(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Dialog.fullscreen(
          backgroundColor: Colors.black.withValues(alpha: 0.92),
          child: SafeArea(
            child: InteractiveViewer(
              child: Center(
                child: Image(
                  image: image,
                  errorBuilder: (c, e, st) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = widget.localBytes;
    Widget photo;
    if (bytes != null) {
      photo = Image.memory(
        bytes,
        width: 200,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _placeholder(),
      );
    } else {
      photo = FutureBuilder<String>(
        future: _url,
        builder: (context, snap) {
          if (snap.hasError) return _placeholder();
          if (!snap.hasData) return _placeholder(loading: true);
          final provider = NetworkImage(snap.data!);
          return GestureDetector(
            key: ValueKey('photo-${widget.message.id}'),
            onTap: () => _openFullScreen(provider),
            child: Image(
              image: provider,
              width: 200,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _placeholder(),
              loadingBuilder: (c, child, progress) =>
                  progress == null ? child : _placeholder(loading: true),
            ),
          );
        },
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: photo);
  }
}

class _TypingMarker {
  const _TypingMarker();
}

/// "The other person is typing": three dots pulsing in an incoming bubble
/// (designed in Sleek, "Chat Thread (Typing)").
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('chat-typing'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Opacity(
                // Each dot brightens in turn.
                opacity:
                    0.35 +
                    0.65 *
                        (1 -
                                ((_anim.value * 3 - i) % 3 - 0.5).abs().clamp(
                                  0.0,
                                  1.0,
                                ))
                            .clamp(0.0, 1.0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.mutedForeground,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the chat [conversationId] (from a notification or a push): finds
/// the conversation, then shows it; the Messages list if it can't.
class ChatFromNotification extends StatefulWidget {
  final String conversationId;
  final MessageService? service;

  const ChatFromNotification({
    super.key,
    required this.conversationId,
    this.service,
  });

  @override
  State<ChatFromNotification> createState() => _ChatFromNotificationState();
}

class _ChatFromNotificationState extends State<ChatFromNotification> {
  late final Future<ConversationSummary?> _found = _find();

  Future<ConversationSummary?> _find() async {
    try {
      final all = await (widget.service ?? MessageService()).conversations();
      for (final c in all) {
        if (c.id == widget.conversationId) return c;
      }
    } catch (e) {
      debugPrint('[Chat] open from notification: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConversationSummary?>(
      future: _found,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }
        final c = snap.data;
        if (c == null) return MessagesScreen(service: widget.service);
        return ChatThreadScreen(conversation: c, service: widget.service);
      },
    );
  }
}
