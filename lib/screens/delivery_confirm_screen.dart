import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/payment_service.dart';
import 'delivery_task_screen.dart';
import 'review_screen.dart';

const _green = Color(0xFF168A68);
const _greenBg = Color(0xFFE4F4EE);

/// Delivery & Payout Release, opened from the delivery task's "Confirm
/// Delivery & Claim": the traveler confirms the handoff with the recipient's
/// 4-digit PIN or a handoff photo, picks where the payout goes, and releases
/// it (after the 3-day dispute window).
///
/// The delivery is sample data, so the PIN is checked on the device and no
/// money moves yet; the payout accounts are the traveler's own
/// (nata.payout_accounts).
class DeliveryConfirmScreen extends StatefulWidget {
  final AcceptedDelivery delivery;

  /// The handoff photo attached on the delivery task page, if any.
  final Uint8List? handoverPhoto;

  /// Overrides for tests.
  final PaymentService? paymentService;
  final PhotoPicker? photoPicker;

  /// Where to go once the payout is released (default: rate the sender).
  final WidgetBuilder? next;

  const DeliveryConfirmScreen({
    super.key,
    required this.delivery,
    this.handoverPhoto,
    this.paymentService,
    this.photoPicker,
    this.next,
  });

  @override
  State<DeliveryConfirmScreen> createState() => _DeliveryConfirmScreenState();
}

class _DeliveryConfirmScreenState extends State<DeliveryConfirmScreen> {
  final _pinCtrls = List.generate(4, (_) => TextEditingController());
  final _pinFocus = List.generate(4, (_) => FocusNode());

  late Uint8List? _photo = widget.handoverPhoto;
  List<PayoutAccount> _accounts = const [];
  String? _payoutAccountId;
  bool _loadingAccounts = true;
  bool _releasing = false;

  AcceptedDelivery get d => widget.delivery;

  String get _pin => _pinCtrls.map((c) => c.text).join();
  bool get _pinComplete => _pin.length == 4;

  /// A complete PIN that matches the recipient's (any complete PIN when the
  /// delivery has none to check against).
  bool get _pinValid =>
      _pinComplete && (d.deliveryPin == null || _pin == d.deliveryPin);

  bool get _handoffConfirmed => _pinValid || _photo != null;

  bool get _canRelease =>
      _handoffConfirmed &&
      !_releasing &&
      (_accounts.isEmpty || _payoutAccountId != null);

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    for (final c in _pinCtrls) {
      c.dispose();
    }
    for (final f in _pinFocus) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await (widget.paymentService ?? PaymentService())
          .payoutAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        // Start on the default account.
        _payoutAccountId = accounts.isEmpty
            ? null
            : accounts
                  .firstWhere((a) => a.isDefault, orElse: () => accounts.first)
                  .id;
        _loadingAccounts = false;
      });
    } catch (e) {
      // Shown as "no payout account": the payout waits for one.
      debugPrint('[DeliveryConfirm] payout accounts: $e');
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _changePhoto() async {
    final photo = await (widget.photoPicker ?? DeliveryTaskScreen.pickPhoto)(
      context,
    );
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  void _onPinChanged(int i, String value) {
    if (value.isNotEmpty && i < 3) _pinFocus[i + 1].requestFocus();
    if (value.isEmpty && i > 0) _pinFocus[i - 1].requestFocus();
    setState(() {});
  }

  Future<void> _release() async {
    if (!_canRelease) return;
    setState(() => _releasing = true);
    // Releasing the escrow payout is not connected yet (sample data).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: widget.next ?? (context) => const ReviewScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(l),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + bottom),
                children: [
                  _stepBanner(l),
                  const SizedBox(height: 16),
                  _pinCard(l),
                  const SizedBox(height: 16),
                  _photoCard(l),
                  const SizedBox(height: 16),
                  _payoutCard(l),
                  const SizedBox(height: 16),
                  _disputeCard(l),
                  const SizedBox(height: 16),
                  _releaseButton(l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _header(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('delivery-confirm-back'),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 20,
                color: AppColors.foreground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              l.deliveryPayoutRelease,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.4,
                color: AppColors.foreground,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: _green,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step banner ────────────────────────────────────────────────────────────
  Widget _stepBanner(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _greenBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.confirmDeliveryStep.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.6,
                    color: _green,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.itemArrivedAtDestination,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.confirmHandoffNote,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.625,
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

  // ── Option 1: PIN ──────────────────────────────────────────────────────────
  Widget _pinCard(AppLocalizations l) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardHeader(
            l.pinOptionTitle,
            _chip(
              l.instantRelease,
              color: AppColors.accent,
              bg: AppColors.accent.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l.pinOptionNote,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [for (var i = 0; i < 4; i++) _pinBox(i)],
              ),
            ),
          ),
          if (_pinComplete) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _pinValid ? Icons.check_circle_rounded : Icons.error_rounded,
                  size: 14,
                  color: _pinValid ? _green : AppColors.destructive,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _pinValid ? l.pinConfirmed : l.pinMismatch,
                    key: const ValueKey('delivery-confirm-pin-status'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: _pinValid ? _green : AppColors.destructive,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pinBox(int i) {
    final filled = _pinCtrls[i].text.isNotEmpty;
    return SizedBox(
      width: 52,
      height: 52,
      child: TextField(
        key: ValueKey('delivery-confirm-pin-$i'),
        controller: _pinCtrls[i],
        focusNode: _pinFocus[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        onChanged: (v) => _onPinChanged(i, v),
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: AppColors.foreground,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.input,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: filled ? AppColors.accent : AppColors.border,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
        ),
      ),
    );
  }

  // ── Option 2: photo ────────────────────────────────────────────────────────
  Widget _photoCard(AppLocalizations l) {
    final photo = _photo;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardHeader(
            l.photoOptionTitle,
            _chip(
              l.alternative,
              color: AppColors.mutedForeground,
              bg: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: photo == null
                      ? const Icon(
                          Icons.add_a_photo_rounded,
                          color: AppColors.primary,
                        )
                      : Image.memory(photo, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photo == null
                          ? l.noHandoffPhoto
                          : l.handoverPhotoAttached,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      photo == null
                          ? l.handoffPhotoHint
                          : '${l.sealIntactPhoto} · '
                                '${(photo.length / (1024 * 1024)).toStringAsFixed(1)} MB',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                key: const ValueKey('delivery-confirm-photo'),
                onTap: _changePhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.input,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    photo == null ? l.add : l.change,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Payout destination ─────────────────────────────────────────────────────
  Widget _payoutCard(AppLocalizations l) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: _sectionTitle(l.payoutDestination)),
                const SizedBox(width: 8),
                Text(
                  l.payoutAmount(d.payout),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingAccounts)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_accounts.isEmpty)
            Text(
              l.noPayoutAccountForRelease,
              key: const ValueKey('delivery-confirm-no-account'),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            )
          else
            for (final a in _accounts) ...[
              _accountOption(l, a),
              if (a != _accounts.last) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _accountOption(AppLocalizations l, PayoutAccount a) {
    final selected = a.id == _payoutAccountId;
    final mobile = a.kind == PayoutAccountKind.mobileMoney;
    return GestureDetector(
      key: ValueKey('delivery-confirm-account-${a.id}'),
      onTap: () => setState(() => _payoutAccountId = a.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.05)
              : AppColors.input.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: mobile
                    ? const Color(0xFF00A859).withValues(alpha: 0.15)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                mobile
                    ? Icons.smartphone_rounded
                    : Icons.account_balance_rounded,
                size: 18,
                color: mobile
                    ? const Color(0xFF00A859)
                    : AppColors.primaryForeground,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${a.institutionName} (•••• ${a.accountLast4})',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.foreground,
                    ),
                  ),
                  Text(
                    mobile ? l.mobileMoneyPayoutSpeed : l.bankPayoutSpeed,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? AppColors.accent : AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  // ── Dispute window ─────────────────────────────────────────────────────────
  Widget _disputeCard(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.disputeProtectionWindow,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              _chip(
                l.threeDaysActive,
                color: AppColors.primary,
                bg: AppColors.primary.withValues(alpha: 0.1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.disputeProtectionNote,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              height: 1.625,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            key: const ValueKey('delivery-confirm-dispute'),
            onTap: () {},
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l.reportIssue,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Release ────────────────────────────────────────────────────────────────
  Widget _releaseButton(AppLocalizations l) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        key: const ValueKey('delivery-confirm-release'),
        onPressed: _canRelease ? _release : null,
        icon: _releasing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.account_balance_wallet_rounded, size: 18),
        label: Text(
          l.confirmReleasePayout(d.payout),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.muted,
          disabledForegroundColor: AppColors.mutedForeground,
          elevation: 1,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  // ── Pieces ─────────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1)),
      ],
    ),
    child: child,
  );

  Widget _sectionTitle(String text) => Text(
    text.toUpperCase(),
    style: GoogleFonts.manrope(
      fontWeight: FontWeight.w700,
      fontSize: 12,
      letterSpacing: 0.6,
      color: AppColors.mutedForeground,
    ),
  );

  Widget _cardHeader(String title, Widget chip) => Row(
    children: [
      Expanded(child: _sectionTitle(title)),
      const SizedBox(width: 8),
      chip,
    ],
  );

  Widget _chip(String text, {required Color color, required Color bg}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            color: color,
          ),
        ),
      );
}
