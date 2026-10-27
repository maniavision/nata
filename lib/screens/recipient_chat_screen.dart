import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/chat_presence.dart';
import '../services/request_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/nata_toast.dart';

/// The traveler's chat with the recipient (designed in Sleek, "Recipient
/// Chat"). The recipient isn't on Nata: they read and reply from the
/// private link texted to them (20240181_recipient_link.sql). Refreshed
/// every few seconds; their messages also come as a push.
///
/// With [asRecipient], the same chat seen by a recipient who is on Nata and
/// opened their link in the app (Sleek, "Parcel Chat (Recipient)"): the
/// traveler, the parcel's status and the handover code (20240186).
class RecipientChatScreen extends StatefulWidget {
  final String requestId;
  final bool asRecipient;

  /// Shown until the chat has loaded.
  final String recipientName;

  final RequestService? service;
  final DateTime Function()? now;
  final Duration refreshEvery;

  const RecipientChatScreen({
    super.key,
    required this.requestId,
    this.asRecipient = false,
    this.recipientName = '',
    this.service,
    this.now,
    this.refreshEvery = const Duration(seconds: 8),
  });

  @override
  State<RecipientChatScreen> createState() => _RecipientChatScreenState();
}

class _RecipientChatScreenState extends State<RecipientChatScreen> {
  RecipientChat? _chat;
  bool _failed = false;
  bool _sending = false;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;

  RequestService get _service => widget.service ?? RequestService();
  DateTime get _now => (widget.now ?? DateTime.now)();

  String get _presence => ChatPresence.recipient(widget.requestId);

  @override
  void initState() {
    super.initState();
    ChatPresence.enter(_presence);
    _load();
    _timer = Timer.periodic(widget.refreshEvery, (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _load();
    });
  }

  @override
  void dispose() {
    ChatPresence.leave(_presence);
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final chat = widget.asRecipient
          ? await _service.myRecipientChat(widget.requestId)
          : await _service.recipientChat(widget.requestId);
      if (!mounted) return;
      final grew = chat.messages.length != (_chat?.messages.length ?? 0);
      setState(() {
        _chat = chat;
        _failed = false;
      });
      if (grew) _toBottom();
    } catch (e) {
      debugPrint('[RecipientChat] load: $e');
      if (mounted && _chat == null) setState(() => _failed = true);
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.recipientSendFailed;
    try {
      if (widget.asRecipient) {
        await _service.sendAsRecipient(widget.requestId, body);
      } else {
        await _service.sendRecipientMessage(widget.requestId, body);
      }
      _input.clear();
      await _load();
    } catch (e) {
      debugPrint('[RecipientChat] send: $e');
      messenger.showSnackBar(nataToast(failed, tone: ToastTone.error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _when(DateTime at) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = _now;
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return sameDay
        ? DateFormat.Hm(locale).format(at)
        : DateFormat.MMMd(locale).add_Hm().format(at);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chat = _chat;
    final name = widget.asRecipient
        ? (chat?.travelerName ?? '')
        : chat?.recipientName.isNotEmpty == true
        ? chat!.recipientName
        : widget.recipientName;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(name, chat),
            Expanded(child: _body(name, chat)),
            if (chat != null && chat.open)
              _composer()
            else if (chat != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l.recipientChatClosed,
                  key: const ValueKey('recipient-chat-closed'),
                  textAlign: TextAlign.center,
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

  Widget _header(String name, RecipientChat? chat) {
    final l = context.l10n;
    final subtitle = chat == null
        ? ''
        : widget.asRecipient
        ? l.parcelChatSubtitle(chat.senderName)
        : l.recipientChatSubtitle(chat.senderName, chat.item);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('recipient-chat-back'),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.foreground,
          ),
          ClipOval(
            child: SizedBox(
              width: 40,
              height: 40,
              child: AvatarImage(
                path: widget.asRecipient ? chat?.travelerAvatar : null,
                fallback: Container(
                  alignment: Alignment.center,
                  color: AppColors.secondary,
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.asRecipient ? name : l.recipientChatTitle(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.foreground,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
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

  Widget _body(String name, RecipientChat? chat) {
    final l = context.l10n;
    if (chat == null) {
      return Center(
        child: _failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.couldNotLoadChat,
                    key: const ValueKey('recipient-chat-error'),
                    style: GoogleFonts.dmSans(color: AppColors.mutedForeground),
                  ),
                  TextButton(onPressed: _load, child: Text(l.retry)),
                ],
              )
            : const CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2.5,
              ),
      );
    }
    final seen = chat.seenAt;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        if (widget.asRecipient)
          _parcelCard(chat)
        else
          Container(
            key: const ValueKey('recipient-chat-banner'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sms_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.recipientChatBanner(name),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        seen == null
                            ? l.recipientSeenNever
                            : l.recipientSeenAt(_when(seen)),
                        key: const ValueKey('recipient-chat-seen'),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (chat.messages.isEmpty && !widget.asRecipient)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              l.recipientChatEmpty(name),
              key: const ValueKey('recipient-chat-empty'),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        for (final m in chat.messages) _bubble(m),
      ],
    );
  }

  /// The recipient's view: where the parcel is, and the handover code.
  Widget _parcelCard(RecipientChat chat) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final status = chat.status == 'handed_off'
        ? l.parcelOnTheWay
        : chat.status == 'paid'
        ? l.parcelWaitingPickup
        : '';
    final parts = [
      if (status.isNotEmpty) status,
      if (chat.fromCity.isNotEmpty && chat.toCity.isNotEmpty)
        '${chat.fromCity} → ${chat.toCity}',
      if (chat.arrivalDate != null)
        l.parcelArrives(DateFormat.MMMd(locale).format(chat.arrivalDate!)),
    ];
    final code = chat.code;
    return Container(
      key: const ValueKey('recipient-chat-parcel'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parts.join(' · '),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          if (code != null && code.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l.parcelCodeLabel.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 1.2,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              key: const ValueKey('recipient-chat-code'),
              children: [
                for (final c in code.characters) ...[
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      c,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.primaryForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l.parcelCodeNote,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bubble(RecipientMessage m) {
    // Each side's own messages on the right.
    final mine = widget.asRecipient ? m.fromRecipient : !m.fromRecipient;
    return Padding(
      key: ValueKey('recipient-message-${m.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: mine ? AppColors.primary : AppColors.secondary,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                ),
                child: Text(
                  m.body,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.4,
                    color: mine
                        ? AppColors.primaryForeground
                        : AppColors.foreground,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _when(m.at),
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const ValueKey('recipient-chat-input'),
                controller: _input,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
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
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: const ValueKey('recipient-chat-send'),
            onTap: _send,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _sending
                    ? AppColors.accent.withValues(alpha: 0.5)
                    : AppColors.accent,
                shape: BoxShape.circle,
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
    );
  }
}
