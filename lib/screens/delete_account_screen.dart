import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../widgets/page_header.dart';
import 'login_screen.dart';

const _green = Color(0xFF168A68);
const _greenBg = Color(0xFFE4F4EE);
const _amber = Color(0xFFA86B12);
const _amberBg = Color(0xFFFBF0DC);
const _redBg = Color(0xFFFEE2E2);

/// Profile > Delete account. Says what is deleted and what is kept, and asks
/// to confirm; while money or a delivery is in flight it says what to finish
/// first instead. Once deleted, the user is signed out to the welcome screen.
class DeleteAccountScreen extends StatefulWidget {
  /// Overrides for tests; they default to the real services.
  final Future<AccountDeletionBlockers> Function()? loadBlockers;
  final Future<void> Function()? deleteAccount;
  final AuthService? authService;

  /// Where the user lands once the account is gone; the welcome screen.
  final WidgetBuilder? afterDeleted;

  const DeleteAccountScreen({
    super.key,
    this.loadBlockers,
    this.deleteAccount,
    this.authService,
    this.afterDeleted,
  });

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  AccountDeletionBlockers? _blockers;
  bool _loadFailed = false;
  bool _understood = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final load = widget.loadBlockers ?? AccountService().deletionBlockers;
      final blockers = await load();
      if (mounted) setState(() => _blockers = blockers);
    } catch (e) {
      debugPrint('[DeleteAccount] load error: $e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await (widget.deleteAccount ?? AccountService().deleteAccount)();
    } on AccountDeletionBlockedException catch (e) {
      // Something started since the page opened: show what it is.
      debugPrint('[DeleteAccount] blocked: ${e.code}');
      if (!mounted) return;
      setState(() => _deleting = false);
      await _load();
      return;
    } catch (e) {
      debugPrint('[DeleteAccount] delete error: $e');
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.daFailed)));
      return;
    }

    try {
      await (widget.authService ?? AuthService()).signOut();
    } catch (e) {
      // The sign-in is already gone on the server.
      debugPrint('[DeleteAccount] sign out: $e');
    }
    PreferencesService().reset();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: widget.afterDeleted ?? (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final blockers = _blockers;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(title: l.deleteAccountRow),
            Expanded(
              child: _loadFailed
                  ? _buildLoadFailed()
                  : blockers == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : blockers.any
                  ? _buildBlocked(blockers)
                  : _buildConfirm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadFailed() {
    final l = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.daLoadFailed,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
          TextButton(onPressed: _load, child: Text(l.retry)),
        ],
      ),
    );
  }

  // ── Confirm ────────────────────────────────────────────────────────────────
  Widget _buildConfirm() {
    final l = context.l10n;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            children: [
              _Badge(
                icon: Icons.warning_amber_rounded,
                color: AppColors.destructive,
                background: _redBg,
              ),
              const SizedBox(height: 16),
              _Title(l.daTitle, key: const ValueKey('delete-account-title')),
              const SizedBox(height: 6),
              _Body(l.daBody),
              const SizedBox(height: 24),
              _Card(
                heading: l.daWhatWeDelete,
                children: [
                  for (final text in [
                    l.daDeleteProfile,
                    l.daDeleteId,
                    l.daDeletePayment,
                    l.daDeleteMessages,
                    l.daDeleteNotifications,
                  ])
                    _Line(
                      leading: Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColors.destructive,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: text,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _Card(
                heading: l.daWhatWeKeep,
                children: [
                  _Line(
                    leading: const _Check(),
                    title: l.daKeepPayments,
                    subtitle: l.daKeepPaymentsSub,
                  ),
                  _Line(
                    leading: const _Check(),
                    title: l.daKeepDeliveries,
                    subtitle: l.daKeepDeliveriesSub,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                key: const ValueKey('delete-account-understand'),
                onTap: _deleting
                    ? null
                    : () => setState(() => _understood = !_understood),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _understood
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 22,
                        color: _understood
                            ? AppColors.destructive
                            : AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.daUnderstand,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 8 + bottom),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('delete-account-confirm'),
                  onPressed: _understood && !_deleting ? _delete : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.destructive,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.destructive.withValues(
                      alpha: 0.35,
                    ),
                    disabledForegroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  child: _deleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l.daConfirmButton),
                ),
              ),
              TextButton(
                key: const ValueKey('delete-account-cancel'),
                onPressed: _deleting ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  textStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                child: Text(l.cancel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Blocked ────────────────────────────────────────────────────────────────
  Widget _buildBlocked(AccountDeletionBlockers b) {
    final l = context.l10n;
    final bottom = MediaQuery.of(context).padding.bottom;
    final rows = [
      if (b.escrow > 0)
        (Icons.lock_outline_rounded, l.daBlockedEscrow, b.escrow),
      if (b.payments > 0)
        (Icons.payments_outlined, l.daBlockedPayments, b.payments),
      if (b.deliveries > 0)
        (Icons.local_shipping_outlined, l.daBlockedDeliveries, b.deliveries),
      if (b.disputes > 0)
        (Icons.flag_outlined, l.daBlockedDisputes, b.disputes),
      if (b.staff) (Icons.shield_outlined, l.daBlockedStaff, null),
    ];
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            children: [
              const _Badge(
                icon: Icons.hourglass_bottom_rounded,
                color: _amber,
                background: _amberBg,
              ),
              const SizedBox(height: 16),
              _Title(
                l.daBlockedTitle,
                key: const ValueKey('delete-account-blocked'),
              ),
              const SizedBox(height: 6),
              _Body(l.daBlockedBody),
              const SizedBox(height: 24),
              if (rows.isNotEmpty)
                _Card(
                  children: [
                    for (final (icon, label, count) in rows)
                      _Line(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 16, color: AppColors.primary),
                        ),
                        title: label,
                        trailing: count == null
                            ? null
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _amberBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$count',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: _amber,
                                  ),
                                ),
                              ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                l.daNeedHelp,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              key: const ValueKey('delete-account-back'),
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryForeground,
                shape: const StadiumBorder(),
                textStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              child: Text(l.backToProfile),
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;

  const _Badge({
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 34, color: color),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;

  const _Title(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        fontSize: 22,
        letterSpacing: -0.4,
        color: AppColors.foreground,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String text;

  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        height: 1.5,
        color: AppColors.mutedForeground,
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(color: _greenBg, shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, size: 12, color: _green),
    );
  }
}

/// A white card, with an optional small caps heading.
class _Card extends StatelessWidget {
  final String? heading;
  final List<Widget> children;

  const _Card({this.heading, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                heading!.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.6,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppColors.border, indent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _Line({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.foreground,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
