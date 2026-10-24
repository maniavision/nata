import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/country_service.dart';
import '../services/payment_service.dart';
import '../services/preferences_service.dart';
import '../widgets/nata_toast.dart';
import '../services/phone_number.dart';
import 'stripe_bank_section.dart';

/// Adds where a traveler is paid: their mobile money, on a network pawaPay
/// pays out to in their country of residence (it can't be changed here;
/// add-payout-account checks it too), or their bank through Stripe where
/// Stripe can pay out (payout-options lists it as the STRIPE bank), given
/// in Nata's own form ([StripeBankSection]). Pops the saved account.
class AddPayoutAccountScreen extends StatefulWidget {
  /// Overrides for tests; default to the real service and the country of
  /// residence on the profile (the device's country when it has none).
  final PaymentService? service;
  final Country? initialCountry;
  final Future<String?> Function()? residenceCountry;

  /// Overrides for tests: opening Stripe's page (an in-app browser by
  /// default), and the traveler's name to start the bank form with (the
  /// profile's by default).
  final Future<bool> Function(Uri link)? openStripePage;
  final Future<({String first, String last})?> Function()? travelerName;

  const AddPayoutAccountScreen({
    super.key,
    this.service,
    this.initialCountry,
    this.residenceCountry,
    this.openStripePage,
    this.travelerName,
  });

  /// payout-options' code for a bank connected through Stripe.
  static const stripeBank = 'STRIPE';

  static Future<String?> _profileResidence() async {
    final profile = await AuthService().getProfile();
    final iso = (profile?['country_of_residence'] as String?)?.trim();
    return iso == null || iso.isEmpty ? null : iso.toUpperCase();
  }

  @override
  State<AddPayoutAccountScreen> createState() => _AddPayoutAccountScreenState();
}

class _AddPayoutAccountScreenState extends State<AddPayoutAccountScreen> {
  Country? _country;
  PayoutOptions? _options;
  bool _loading = true;
  bool _loadFailed = false;

  PayoutAccountKind _kind = PayoutAccountKind.bank;
  PayoutProvider? _provider;
  final _number = TextEditingController();
  final _holder = TextEditingController();
  bool _saving = false;
  String? _error;

  PaymentService get _service => widget.service ?? PaymentService();

  bool get _viaStripe =>
      _kind == PayoutAccountKind.bank &&
      (_options?.banks.any(
            (b) => b.code == AddPayoutAccountScreen.stripeBank,
          ) ??
          false);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    var country = widget.initialCountry;
    if (country == null) {
      try {
        // The country of residence; the device's for a profile without one.
        final iso =
            await (widget.residenceCountry ??
                AddPayoutAccountScreen._profileResidence)() ??
            PreferencesService().countryIsoCode;
        country = await CountryService().byIsoCode(iso);
      } catch (e) {
        debugPrint('[AddPayoutAccount] country: $e');
      }
    }
    country ??= const Country(
      isoCode: 'NG',
      name: 'Nigeria',
      phoneCode: '+234',
    );
    if (!mounted) return;
    setState(() => _country = country);
    await _loadOptions();
  }

  Future<void> _loadOptions() async {
    final country = _country;
    if (country == null) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
      _options = null;
      _provider = null;
      _error = null;
    });
    try {
      final options = await _service.payoutOptions(country.isoCode);
      if (!mounted) return;
      setState(() {
        _options = options;
        // Banks first when there are any.
        _kind = options.banks.isNotEmpty
            ? PayoutAccountKind.bank
            : PayoutAccountKind.mobileMoney;
      });
    } catch (e) {
      debugPrint('[AddPayoutAccount] options: $e');
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PayoutProvider> get _providers => _kind == PayoutAccountKind.bank
      ? (_options?.banks ?? const [])
      : (_options?.mobileMoney ?? const []);

  /// The number as the server wants it: a mobile number with its country
  /// code and without the leading 0; an account number as typed.
  String get _accountNumber {
    final raw = _number.text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (_kind == PayoutAccountKind.bank) return raw;
    final code = (_country?.phoneCode ?? '').replaceAll(RegExp(r'\D'), '');
    var local = raw.replaceAll(RegExp(r'\D'), '');
    if (local.startsWith(code) && local.length > code.length + 6) {
      return local;
    }
    // Keeps the 0 where it belongs to the number (see phone_number.dart).
    final e164 = internationalPhoneNumber(
      dialCode: code,
      input: local,
      isoCode: _country?.isoCode,
    );
    return e164 == null ? '$code$local' : e164.substring(1);
  }

  Future<void> _save() async {
    final l = context.l10n;
    final provider = _provider;
    final country = _country;
    if (provider == null || country == null) return;
    if (_number.text.trim().length < 6 || _holder.text.trim().length < 2) {
      setState(() => _error = l.errPayoutAccountInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final account = await _service.addPayoutAccount(
        kind: _kind,
        country: country.isoCode,
        provider: provider,
        accountNumber: _accountNumber,
        holderName: _holder.text.trim(),
      );
      // Payouts that were waiting for an account go out now.
      unawaited(
        _service.sendPayouts().catchError((Object e) {
          debugPrint('[AddPayoutAccount] send payouts: $e');
          return 0;
        }),
      );
      messenger.showSnackBar(
        nataToast(l.payoutAccountSaved, tone: ToastTone.success),
      );
      navigator.pop(account);
    } on PayoutAccountException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = switch (e.reason) {
          PayoutAccountFailure.invalid => l.errPayoutAccountInvalid,
          PayoutAccountFailure.notSupported => l.errPayoutNotSupported,
          PayoutAccountFailure.countryMismatch => l.errPayoutCountryMismatch,
          PayoutAccountFailure.unavailable => l.errPaymentsUnavailable,
          PayoutAccountFailure.emailRequired ||
          PayoutAccountFailure.other => l.errSavePayoutAccount,
        },
      );
    } catch (e) {
      debugPrint('[AddPayoutAccount] save: $e');
      if (mounted) setState(() => _error = l.errSavePayoutAccount);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final options = _options;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
                children: [
                  _label(l.payoutCountry),
                  _countryField(),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                    )
                  else if (_loadFailed)
                    _message(
                      l.errLoadPayoutOptions,
                      key: 'payout-options-error',
                      retry: _loadOptions,
                    )
                  else if (options == null || options.isEmpty)
                    _message(
                      l.noPayoutOptions(_country?.name ?? ''),
                      key: 'payout-options-none',
                    )
                  else ...[
                    if (options.banks.isNotEmpty &&
                        options.mobileMoney.isNotEmpty) ...[
                      _kindToggle(),
                      const SizedBox(height: 16),
                    ],
                    if (_viaStripe)
                      StripeBankSection(
                        service: _service,
                        country: _country!,
                        travelerName: widget.travelerName,
                        openStripePage: widget.openStripePage,
                        onSaved: (account) =>
                            Navigator.of(context).pop(account),
                      )
                    else ...[
                      _label(
                        _kind == PayoutAccountKind.bank
                            ? l.bankLabel
                            : l.providerLabel,
                      ),
                      _providerField(),
                      const SizedBox(height: 16),
                      _label(
                        _kind == PayoutAccountKind.bank
                            ? l.accountNumber
                            : l.mobileMoneyNumber,
                      ),
                      _textField(
                        _number,
                        key: 'payout-number',
                        keyboard: _kind == PayoutAccountKind.bank
                            ? TextInputType.text
                            : TextInputType.phone,
                        prefix: _kind == PayoutAccountKind.mobileMoney
                            ? _country?.phoneCode
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _label(l.accountHolderName),
                      _textField(
                        _holder,
                        key: 'payout-holder',
                        keyboard: TextInputType.name,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.payoutAccountNoteSecure,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          height: 1.4,
                          color: AppColors.mutedForeground,
                        ),
                      ),
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
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          key: const ValueKey('payout-save'),
                          onPressed: _saving || _provider == null
                              ? null
                              : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.primaryForeground,
                            disabledBackgroundColor: AppColors.muted,
                            shape: const StadiumBorder(),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryForeground,
                                  ),
                                )
                              : Text(
                                  l.savePayoutAccount,
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
    child: Row(
      children: [
        GestureDetector(
          key: const ValueKey('payout-back'),
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.l10n.addPayoutAccount,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 1.2,
        color: AppColors.mutedForeground,
      ),
    ),
  );

  BoxDecoration get _box => BoxDecoration(
    color: AppColors.input,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
  );

  /// The country of residence: shown, not changed.
  Widget _countryField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        key: const ValueKey('payout-country'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: _box.copyWith(
          color: AppColors.muted.withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            if (_country != null) ...[
              Text(
                _flag(_country!.isoCode),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                _country?.name ?? '…',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              context.l10n.payoutCountryNote,
              key: const ValueKey('payout-country-note'),
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

  /// The flag emoji of a two-letter country code.
  static String _flag(String isoCode) {
    final code = isoCode.trim().toUpperCase();
    if (code.length != 2) return '';
    const base = 0x1F1E6;
    return String.fromCharCodes([
      base + code.codeUnitAt(0) - 0x41,
      base + code.codeUnitAt(1) - 0x41,
    ]);
  }

  Widget _kindToggle() {
    Widget option(PayoutAccountKind kind, String label, IconData icon) {
      final selected = _kind == kind;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('payout-kind-${kind.name}'),
          onTap: () => setState(() {
            _kind = kind;
            _provider = null;
            _error = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? AppColors.primaryForeground
                      : AppColors.mutedForeground,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: selected
                          ? AppColors.primaryForeground
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          option(
            PayoutAccountKind.bank,
            context.l10n.bankAccount,
            Icons.account_balance_rounded,
          ),
          option(
            PayoutAccountKind.mobileMoney,
            context.l10n.mobileMoney,
            Icons.phone_iphone_rounded,
          ),
        ],
      ),
    );
  }

  Widget _providerField() {
    final providers = _providers;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _box,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          key: const ValueKey('payout-provider'),
          isExpanded: true,
          menuMaxHeight: 420,
          value: _provider == null ? null : providers.indexOf(_provider!),
          hint: Text(
            _kind == PayoutAccountKind.bank
                ? context.l10n.chooseBank
                : context.l10n.chooseProvider,
          ),
          items: [
            for (var i = 0; i < providers.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(providers[i].name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (i) => setState(() {
            _provider = i == null ? null : providers[i];
            _error = null;
          }),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller, {
    required String key,
    required TextInputType keyboard,
    String? prefix,
  }) => TextField(
    key: ValueKey(key),
    controller: controller,
    keyboardType: keyboard,
    onChanged: (_) {
      if (_error != null) setState(() => _error = null);
    },
    style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.foreground),
    decoration: InputDecoration(
      prefixText: prefix == null ? null : '$prefix ',
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

  Widget _message(String text, {required String key, VoidCallback? retry}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            key: ValueKey(key),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
          if (retry != null)
            TextButton(onPressed: retry, child: Text(context.l10n.retry)),
        ],
      );
}
