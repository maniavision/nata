import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/country_service.dart';
import '../services/payment_service.dart';
import '../widgets/nata_toast.dart';

/// How a country's bank accounts are given to Stripe.
enum _BankFormat {
  /// US: routing number and account number.
  us,

  /// Canada: transit and institution numbers, and account number.
  ca,

  /// UK: sort code and account number.
  gb,

  /// The EEA and Switzerland: an IBAN.
  iban,
}

/// The bank through Stripe on Add payout account (designed in Sleek, "Add
/// Payout Account - Bank Details"): the traveler gives their details and
/// bank account in Nata's form, and stripe-connect creates their Stripe
/// account with them. Then it shows where it stands: Stripe checking it, or
/// Stripe needing more than the form gives (finished on Stripe's page).
/// Calls [onSaved] once Stripe pays out to the bank.
class StripeBankSection extends StatefulWidget {
  final PaymentService service;

  /// The traveler's country of residence.
  final Country country;

  /// Overrides for tests: the name to start with (the profile's by
  /// default), and opening Stripe's page (an in-app browser by default).
  final Future<({String first, String last})?> Function()? travelerName;
  final Future<bool> Function(Uri link)? openStripePage;

  final void Function(PayoutAccount account) onSaved;

  const StripeBankSection({
    super.key,
    required this.service,
    required this.country,
    required this.onSaved,
    this.travelerName,
    this.openStripePage,
  });

  /// Stripe's Connected Account Agreement, accepted in the form.
  static final agreement = Uri.parse(
    'https://stripe.com/connect-account/legal/full',
  );

  static Future<({String first, String last})?> _profileName() async {
    final profile = await AuthService().getProfile();
    if (profile == null) return null;
    return (
      first: (profile['first_name'] as String? ?? '').trim(),
      last: (profile['last_name'] as String? ?? '').trim(),
    );
  }

  @override
  State<StripeBankSection> createState() => _StripeBankSectionState();
}

class _StripeBankSectionState extends State<StripeBankSection>
    with WidgetsBindingObserver {
  /// Where it stands with Stripe; null until known.
  StripeBankStatus? _status;
  bool _busy = false;
  bool _stripeOpened = false;

  /// Once Stripe pays out to it: the bank connected, whether it is already
  /// one of the traveler's payout accounts, and whether they chose to give
  /// another bank in the form instead.
  StripeConnectedBank? _connected;
  bool _connectedAdded = false;
  bool _changing = false;
  String? _error;

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postal = TextEditingController();
  final _idNumber = TextEditingController();
  final _routing = TextEditingController();
  final _institution = TextEditingController();
  final _account = TextEditingController();
  final _email = TextEditingController();
  DateTime? _dob;
  bool _agreed = false;

  /// Stripe needs an email, and Nata has none: asked for in the form.
  bool _needsEmail = false;

  String get _iso => widget.country.isoCode.toUpperCase();

  _BankFormat get _format => switch (_iso) {
    'US' => _BankFormat.us,
    'CA' => _BankFormat.ca,
    'GB' => _BankFormat.gb,
    _ => _BankFormat.iban,
  };

  /// Only the US needs an ID number in the form: the SSN's last 4 digits.
  bool get _asksSsn => _iso == 'US';

  /// A state or province where the address has one.
  bool get _asksState => _iso == 'US' || _iso == 'CA';

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Where it stands, once the section is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check(quiet: true);
    });
    _prefillName();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Stripe's page in another app: see where it stands.
    if (state == AppLifecycleState.resumed && _stripeOpened) {
      _check(quiet: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in [
      _first,
      _last,
      _phone,
      _line1,
      _city,
      _state,
      _postal,
      _idNumber,
      _routing,
      _institution,
      _account,
      _email,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _prefillName() async {
    try {
      final name =
          await (widget.travelerName ?? StripeBankSection._profileName)();
      if (!mounted || name == null) return;
      setState(() {
        if (_first.text.isEmpty) _first.text = name.first;
        if (_last.text.isEmpty) _last.text = name.last;
      });
    } catch (e) {
      debugPrint('[StripeBank] name: $e');
    }
  }

  /// Saved once Stripe pays out to the bank: payouts waiting go out.
  void _done(PayoutAccount account) {
    final l = context.l10n;
    unawaited(
      widget.service.sendPayouts().catchError((Object e) {
        debugPrint('[StripeBank] send payouts: $e');
        return 0;
      }),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(nataToast(l.payoutAccountSaved, tone: ToastTone.success));
    widget.onSaved(account);
  }

  /// Shows where it stands. A bank Stripe pays out to is saved (and the
  /// screen closes) when [save]: the form was just sent, the traveler tapped
  /// "Use this bank", or came back from Stripe's page. On opening it is only
  /// shown, so one removed from Payment settings doesn't come back by itself.
  void _show(StripeBank bank, {bool save = false}) {
    if (bank.status == StripeBankStatus.enabled &&
        bank.account != null &&
        save) {
      _done(bank.account!);
      return;
    }
    setState(() {
      _status = bank.status;
      _connected = bank.bank;
      _connectedAdded = bank.account != null;
      _changing = false;
    });
  }

  /// Asks where it stands. [quiet]: on opening or coming back; [save]:
  /// "Use this bank".
  Future<void> _check({bool quiet = false, bool save = false}) async {
    if (_busy) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      if (!quiet) _error = null;
    });
    try {
      final saveNow = save || _stripeOpened;
      final bank = await widget.service.stripeBankStatus(save: saveNow);
      if (mounted) _show(bank, save: saveNow);
    } catch (e) {
      debugPrint('[StripeBank] status: $e');
      if (mounted) {
        setState(() {
          _status ??= StripeBankStatus.none;
          if (!quiet) _error = l.errRequestFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _digits(TextEditingController c) =>
      c.text.replaceAll(RegExp(r'\D'), '');

  /// The form's answers, or null (and why) when something is missing.
  StripeBankDetails? _details() {
    final l = context.l10n;
    final routing = switch (_format) {
      // Canada: transit-institution, as Stripe takes it.
      _BankFormat.ca => '${_digits(_routing)}-${_digits(_institution)}',
      _BankFormat.iban => '',
      _ => _digits(_routing),
    };
    final account = _format == _BankFormat.iban
        ? _account.text.replaceAll(RegExp(r'\s'), '').toUpperCase()
        : _digits(_account);
    final ok =
        _first.text.trim().isNotEmpty &&
        _last.text.trim().isNotEmpty &&
        _dob != null &&
        _phone.text.trim().length >= 7 &&
        _line1.text.trim().isNotEmpty &&
        _city.text.trim().isNotEmpty &&
        (!_asksState || _state.text.trim().isNotEmpty) &&
        _postal.text.trim().isNotEmpty &&
        (!_asksSsn || _digits(_idNumber).length == 4) &&
        switch (_format) {
          _BankFormat.us => routing.length == 9,
          _BankFormat.ca =>
            _digits(_routing).length == 5 && _digits(_institution).length == 3,
          _BankFormat.gb => routing.length == 6,
          _BankFormat.iban => true,
        } &&
        account.length >= 4 &&
        (!_needsEmail || _emailPattern.hasMatch(_email.text.trim())) &&
        _agreed;
    if (!ok) {
      setState(() => _error = l.stripeFormIncomplete);
      return null;
    }
    return StripeBankDetails(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      dateOfBirth: _dob!,
      phone: _phone.text.trim(),
      line1: _line1.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim().toUpperCase(),
      postalCode: _postal.text.trim().toUpperCase(),
      idNumber: _asksSsn ? _digits(_idNumber) : null,
      routingNumber: routing,
      accountNumber: account,
      email: _needsEmail ? _email.text.trim() : null,
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = context.l10n;
    final details = _details();
    if (details == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bank = await widget.service.submitStripeBank(details);
      if (mounted) _show(bank, save: true);
    } on PayoutAccountException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.reason == PayoutAccountFailure.emailRequired) _needsEmail = true;
        _error = switch (e.reason) {
          PayoutAccountFailure.emailRequired => l.stripeEmailNeeded,
          PayoutAccountFailure.notSupported => l.errPayoutNotSupported,
          PayoutAccountFailure.unavailable => l.errPaymentsUnavailable,
          // Stripe's own words (an invalid routing number...).
          PayoutAccountFailure.invalid =>
            e.message ?? l.errPayoutAccountInvalid,
          _ => l.errSavePayoutAccount,
        };
      });
    } catch (e) {
      debugPrint('[StripeBank] submit: $e');
      if (mounted) setState(() => _error = l.errSavePayoutAccount);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Stripe's page, for what the form doesn't cover.
  Future<void> _finishWithStripe() async {
    if (_busy) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await widget.service.stripeBankLink();
      final opened = await (widget.openStripePage ?? _openInApp)(link);
      if (!mounted) return;
      setState(() {
        _stripeOpened = _stripeOpened || opened;
        if (!opened) _error = l.errStripeOpen;
      });
    } catch (e) {
      debugPrint('[StripeBank] link: $e');
      if (mounted) setState(() => _error = l.errStripeOpen);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static Future<bool> _openInApp(Uri link) =>
      launchUrl(link, mode: LaunchMode.inAppBrowserView);

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 13, now.month, now.day),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_status == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
          )
        else if (_status == StripeBankStatus.pending ||
            _status == StripeBankStatus.actionNeeded)
          _statusCard()
        else if (_status == StripeBankStatus.enabled && !_changing)
          _connectedCard()
        else
          _form(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            key: const ValueKey('payout-error'),
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.destructive,
            ),
          ),
        ],
      ],
    );
  }

  // ── The form ──────────────────────────────────────────────────────────────
  Widget _form() {
    final l = context.l10n;
    final dob = _dob;
    return Column(
      key: const ValueKey('stripe-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(l.stripeYourDetails, [
          Row(
            children: [
              Expanded(
                child: _field(
                  _first,
                  key: 'stripe-first',
                  label: l.firstName,
                  keyboard: TextInputType.name,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  _last,
                  key: 'stripe-last',
                  label: l.lastName,
                  keyboard: TextInputType.name,
                ),
              ),
            ],
          ),
          _caption(l.stripeDateOfBirth),
          GestureDetector(
            key: const ValueKey('stripe-dob'),
            onTap: _pickDob,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: _box,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dob == null
                          ? 'MM / DD / YYYY'
                          : '${dob.month.toString().padLeft(2, '0')} / '
                                '${dob.day.toString().padLeft(2, '0')} / '
                                '${dob.year}',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: dob == null
                            ? AppColors.mutedForeground
                            : AppColors.foreground,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
          _field(
            _phone,
            key: 'stripe-phone',
            label: l.phoneNumber,
            keyboard: TextInputType.phone,
          ),
          if (_needsEmail) ...[
            _field(
              _email,
              key: 'stripe-email',
              label: l.stripeEmailLabel,
              keyboard: TextInputType.emailAddress,
            ),
            _helper(l.stripeEmailNote),
          ],
        ]),
        _section(l.stripeHomeAddress, [
          _field(
            _line1,
            key: 'stripe-line1',
            label: l.stripeStreet,
            keyboard: TextInputType.streetAddress,
          ),
          _field(
            _city,
            key: 'stripe-city',
            label: l.stripeCity,
            keyboard: TextInputType.text,
          ),
          Row(
            children: [
              if (_asksState) ...[
                Expanded(
                  child: _field(
                    _state,
                    key: 'stripe-state',
                    label: _iso == 'US' ? l.stripeState : l.stripeProvince,
                    keyboard: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _field(
                  _postal,
                  key: 'stripe-postal',
                  label: _iso == 'US' ? l.stripeZip : l.stripePostcode,
                  keyboard: _iso == 'US'
                      ? TextInputType.number
                      : TextInputType.text,
                ),
              ),
            ],
          ),
        ]),
        if (_asksSsn)
          _section(l.stripeIdentity, [
            _field(
              _idNumber,
              key: 'stripe-ssn',
              label: l.stripeSsnLast4,
              keyboard: TextInputType.number,
              obscure: true,
              maxLength: 4,
            ),
            _helper(l.stripeSsnHelp),
          ]),
        _section(l.stripeBankAccount, [
          ...switch (_format) {
            _BankFormat.us => [
              _field(
                _routing,
                key: 'stripe-routing',
                label: l.stripeRoutingNumber,
                keyboard: TextInputType.number,
                maxLength: 9,
              ),
            ],
            _BankFormat.ca => [
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _routing,
                      key: 'stripe-routing',
                      label: l.stripeTransitNumber,
                      keyboard: TextInputType.number,
                      maxLength: 5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _institution,
                      key: 'stripe-institution',
                      label: l.stripeInstitutionNumber,
                      keyboard: TextInputType.number,
                      maxLength: 3,
                    ),
                  ),
                ],
              ),
            ],
            _BankFormat.gb => [
              _field(
                _routing,
                key: 'stripe-routing',
                label: l.stripeSortCode,
                keyboard: TextInputType.number,
                maxLength: 8,
              ),
            ],
            _BankFormat.iban => const <Widget>[],
          },
          _field(
            _account,
            key: 'stripe-account',
            label: _format == _BankFormat.iban ? l.stripeIban : l.accountNumber,
            keyboard: _format == _BankFormat.iban
                ? TextInputType.text
                : TextInputType.number,
          ),
          _helper(l.stripeHolderNote),
        ]),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                key: const ValueKey('stripe-agree'),
                value: _agreed,
                activeColor: AppColors.accent,
                onChanged: (v) => setState(() {
                  _agreed = v ?? false;
                  _error = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.foreground,
                  ),
                  children: [
                    TextSpan(text: l.stripeAgreePrefix),
                    TextSpan(
                      text: l.stripeAgreementName,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrl(
                          StripeBankSection.agreement,
                          mode: LaunchMode.inAppBrowserView,
                        ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _button(
          key: 'stripe-save',
          label: l.stripeSaveBank,
          onPressed: _submit,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 13,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                l.stripeFormNote,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── The bank already connected ─────────────────────────────────────────────
  static const _green = Color(0xFF168A68);
  static const _greenBg = Color(0xFFE4F4EE);

  Widget _connectedCard() {
    final l = context.l10n;
    final bank = _connected;
    final body = [
      if (bank != null) l.stripeConnectedBody(bank.institution, bank.last4),
      if (_connectedAdded) l.stripeConnectedAdded,
    ].join(' ');
    return Container(
      key: const ValueKey('stripe-connected'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _greenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: _green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.stripeConnectedTitle,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.foreground,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _connectedAdded
              ? _button(
                  key: 'stripe-done',
                  label: l.stripeDone,
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : _button(
                  key: 'stripe-use',
                  label: l.stripeUseBank,
                  onPressed: () => _check(save: true),
                ),
          TextButton(
            key: const ValueKey('stripe-change'),
            onPressed: _busy ? null : () => setState(() => _changing = true),
            child: Text(
              l.stripeChangeBank,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stripe checking it, or needing more ───────────────────────────────────
  Widget _statusCard() {
    final l = context.l10n;
    final more = _status == StripeBankStatus.actionNeeded;
    return Container(
      key: const ValueKey('payout-stripe'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  more
                      ? Icons.assignment_late_outlined
                      : Icons.hourglass_top_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      more ? l.stripeMoreTitle : l.stripePendingTitle,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      more ? l.stripeMoreBody : l.stripePendingBody,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (more) ...[
            _button(
              key: 'stripe-finish',
              label: l.stripeFinish,
              onPressed: _finishWithStripe,
              icon: Icons.open_in_new_rounded,
            ),
            const SizedBox(height: 8),
          ],
          _button(
            key: 'stripe-check',
            label: l.stripeCheckAgain,
            onPressed: _check,
            outlined: true,
          ),
        ],
      ),
    );
  }

  // ── Pieces ────────────────────────────────────────────────────────────────
  BoxDecoration get _box => BoxDecoration(
    color: AppColors.input,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
  );

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1.2,
            color: AppColors.mutedForeground,
          ),
        ),
        for (final c in children) ...[const SizedBox(height: 8), c],
      ],
    ),
  );

  Widget _caption(String text) => Text(
    text,
    style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.mutedForeground),
  );

  Widget _helper(String text) => Text(
    text,
    style: GoogleFonts.dmSans(
      fontSize: 11,
      height: 1.4,
      color: AppColors.mutedForeground,
    ),
  );

  Widget _field(
    TextEditingController controller, {
    required String key,
    required String label,
    required TextInputType keyboard,
    bool obscure = false,
    int? maxLength,
  }) => TextField(
    key: ValueKey(key),
    controller: controller,
    keyboardType: keyboard,
    obscureText: obscure,
    autocorrect: false,
    inputFormatters: maxLength == null
        ? null
        : [LengthLimitingTextInputFormatter(maxLength)],
    onChanged: (_) {
      if (_error != null) setState(() => _error = null);
    },
    style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.foreground),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.dmSans(
        fontSize: 13,
        color: AppColors.mutedForeground,
      ),
      filled: true,
      fillColor: AppColors.input,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
  );

  Widget _button({
    required String key,
    required String label,
    required VoidCallback onPressed,
    bool outlined = false,
    IconData? icon,
  }) {
    final child = _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 16),
              ],
            ],
          );
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              key: ValueKey(key),
              onPressed: _busy ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: const StadiumBorder(),
              ),
              child: child,
            )
          : ElevatedButton(
              key: ValueKey(key),
              onPressed: _busy ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.muted,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: child,
            ),
    );
  }
}
