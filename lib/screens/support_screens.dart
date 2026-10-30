import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/request_service.dart' show PriceFormatter;
import '../services/message_service.dart' show ChatReportReason;
import '../services/support_service.dart';
import '../widgets/chat_report_sheet.dart';
import '../widgets/avatar_image.dart';
import '../widgets/page_header.dart';
import 'notifications_screen.dart' show notificationTimeLabel;
import '../widgets/nata_toast.dart';

// The Support section for Nata staff, as designed in Sleek (Support,
// Reported Problems, Problem Detail, Payments & Locks). Profile opens it
// only for staff; the server refuses everyone else anyway.

const _green = Color(0xFF168A68);
const _greenBg = Color(0xFFE4F4EE);
const _amber = Color(0xFFB7791F);
const _amberBg = Color(0x26E5A83B);

TextStyle _label() => GoogleFonts.dmSans(
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 1,
  color: AppColors.mutedForeground,
);

TextStyle _small({Color? color, FontWeight weight = FontWeight.w400}) =>
    GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: weight,
      color: color ?? AppColors.mutedForeground,
      height: 1.4,
    );

TextStyle _body({FontWeight weight = FontWeight.w700, Color? color}) =>
    GoogleFonts.dmSans(
      fontSize: 12,
      fontWeight: weight,
      color: color ?? AppColors.foreground,
    );

TextStyle _title({double size = 14}) => GoogleFonts.dmSans(
  fontSize: size,
  fontWeight: FontWeight.w800,
  color: AppColors.foreground,
);

/// A white rounded card, as every Sleek support card.
class _Card extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Key? cardKey;
  const _Card({required this.child, this.onTap, this.cardKey});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      key: cardKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
    return onTap == null
        ? card
        : GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: card,
          );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  const _Chip(this.text, {required this.color, required this.background});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: _label()),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool primary;
  final bool destructive;
  final bool busy;
  final IconData? icon;
  final Key? buttonKey;
  const _Pill(
    this.text, {
    this.onTap,
    this.primary = true,
    this.destructive = false,
    this.busy = false,
    this.icon,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary
        ? AppColors.primaryForeground
        : (destructive ? AppColors.destructive : AppColors.foreground);
    final bg = primary
        ? (destructive ? AppColors.destructive : AppColors.primary)
        : AppColors.card;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        key: buttonKey,
        onPressed: busy ? null : onTap,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledForegroundColor: fg.withValues(alpha: 0.6),
          shape: StadiumBorder(
            side: primary
                ? BorderSide.none
                : BorderSide(
                    color: destructive
                        ? AppColors.destructive.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 8),
                  ],
                  Text(text),
                ],
              ),
      ),
    );
  }
}

class _Person extends StatelessWidget {
  final String name;
  final String role;
  final String? phone;
  const _Person({required this.name, required this.role, this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.input.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Avatar(name: name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: _body()),
                Text(role, style: _small()),
              ],
            ),
          ),
          if (phone != null && phone!.isNotEmpty)
            GestureDetector(
              onTap: () => launchUrl(Uri(scheme: 'tel', path: '+$phone')),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _greenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_rounded, size: 18, color: _green),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? path;
  const _Avatar({required this.name, this.path});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final fallback = Container(
      color: AppColors.secondary,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child: AvatarImage(path: path, fallback: fallback),
      ),
    );
  }
}

/// A page from Profile: the header, then a pull-to-refresh list.
class _Page extends StatelessWidget {
  final String title;
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  const _Page({
    required this.title,
    required this.onRefresh,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(title: title),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accent,
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 40 + bottom),
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _loading() => const Padding(
  padding: EdgeInsets.only(top: 60),
  child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
);

Widget _message(String text, {Key? key}) => Padding(
  key: key,
  padding: const EdgeInsets.only(top: 60),
  child: Text(
    text,
    textAlign: TextAlign.center,
    style: _body(weight: FontWeight.w500, color: AppColors.mutedForeground),
  ),
);

String _money(double amount, String currency) =>
    currency.isEmpty ? '' : PriceFormatter.write(amount, currency);

String _reasonLabel(AppLocalizations l, String reason) => switch (reason) {
  'not_received' => l.rpNotReceived,
  'damaged' => l.rpDamaged,
  'wrong_item' => l.rpWrongItem,
  'opened' => l.rpOpened,
  _ => l.rpOther,
};

_Chip _reasonChip(AppLocalizations l, String reason) => switch (reason) {
  'damaged' => _Chip(
    _reasonLabel(l, reason),
    color: _amber,
    background: _amberBg,
  ),
  'wrong_item' => _Chip(
    _reasonLabel(l, reason),
    color: AppColors.accent,
    background: AppColors.accent.withValues(alpha: 0.15),
  ),
  _ => _Chip(
    _reasonLabel(l, reason),
    color: AppColors.destructive,
    background: AppColors.destructive.withValues(alpha: 0.1),
  ),
};

String _ago(BuildContext context, DateTime then) =>
    notificationTimeLabel(context.l10n, DateTime.now(), then);

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(nataToast(text));

// ── Support (dashboard) ─────────────────────────────────────────────────────

class SupportScreen extends StatefulWidget {
  final SupportService? service;
  const SupportScreen({super.key, this.service});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final SupportService _service = widget.service ?? SupportService();
  SupportSummary? _summary;
  List<SupportActivity> _activity = const [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await _service.summary();
      final activity = await _service.recentActivity();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _activity = activity;
        _failed = false;
      });
    } catch (e) {
      debugPrint('[Support] load: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = _summary;
    return _Page(
      title: l.supportTitle,
      onRefresh: _load,
      children: [
        Text(
          l.supportSubtitle,
          style: _body(
            weight: FontWeight.w400,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        if (s == null && _failed)
          _message(l.supportLoadFailed, key: const ValueKey('support-error'))
        else if (s == null)
          _loading()
        else ...[
          _SummaryCard(
            key: const ValueKey('support-problems'),
            icon: Icons.report_gmailerrorred_rounded,
            color: AppColors.accent,
            background: AppColors.accent.withValues(alpha: 0.15),
            label: l.supportProblemsCard,
            count: s.openProblems,
            suffix: l.supportOpenSuffix,
            line: l.supportProblemsLine,
            onTap: () => _open(SupportProblemsScreen(service: _service)),
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            key: const ValueKey('support-locked'),
            icon: Icons.lock_rounded,
            color: _amber,
            background: _amberBg,
            label: l.supportLockedCard,
            count: s.lockedDeliveries,
            suffix: l.supportLockedSuffix,
            line: l.supportLockedLine,
            onTap: () => _open(
              SupportPaymentsScreen(service: _service, startOnLocks: true),
            ),
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            key: const ValueKey('support-failed'),
            icon: Icons.sync_problem_rounded,
            color: AppColors.destructive,
            background: AppColors.destructive.withValues(alpha: 0.1),
            label: l.supportFailedCard,
            count: s.failedPayments,
            suffix: l.supportFailedSuffix,
            line: l.supportFailedLine,
            onTap: () => _open(SupportPaymentsScreen(service: _service)),
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            key: const ValueKey('support-reports'),
            icon: Icons.flag_rounded,
            color: AppColors.primary,
            background: AppColors.secondary,
            label: l.supportReportsCard,
            count: s.openReports,
            suffix: l.supportReportsSuffix,
            line: l.supportReportsLine,
            onTap: () => _open(SupportReportsScreen(service: _service)),
          ),
          const SizedBox(height: 20),
          _Section(
            title: l.supportRecentActivity,
            children: [
              if (_activity.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l.supportNoActivity, style: _small()),
                ),
              for (final (i, a) in _activity.indexed) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                _ActivityRow(activity: a),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String label;
  final int count;
  final String suffix;
  final String line;
  final VoidCallback onTap;
  const _SummaryCard({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.label,
    required this.count,
    required this.suffix,
    required this.line,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _Card(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: _label()),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$count ',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    TextSpan(
                      text: suffix,
                      style: _body(color: color),
                    ),
                  ],
                ),
              ),
              Text(line, style: _small()),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.mutedForeground,
        ),
      ],
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  final SupportActivity activity;
  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (IconData icon, String title) = switch (activity.action) {
      'resolved' => (Icons.check_circle_rounded, l.supportActResolved),
      'refunded' => (Icons.undo_rounded, l.supportActRefunded),
      'payout_retried' => (Icons.refresh_rounded, l.supportActPayoutRetried),
      'refund_retried' => (Icons.refresh_rounded, l.supportActRefundRetried),
      'report_reviewed' => (Icons.flag_rounded, l.supportActReportReviewed),
      _ => (Icons.lock_open_rounded, l.supportActUnlocked),
    };
    final resolved = activity.action == 'resolved';
    // The subject is "Payout retried · Daniel O."; show the part after the
    // action, which is already the title.
    final parts = activity.subject.split(' · ');
    final subject = parts.length > 1 ? parts.sublist(1).join(' · ') : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: resolved ? _greenBg : AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: resolved ? _green : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _body()),
                Text(
                  [
                    subject,
                    activity.adminName,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: _small(),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _ago(context, activity.createdAt),
            style: _small(weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Reported Problems ───────────────────────────────────────────────────────

class SupportProblemsScreen extends StatefulWidget {
  final SupportService? service;
  const SupportProblemsScreen({super.key, this.service});

  @override
  State<SupportProblemsScreen> createState() => _SupportProblemsScreenState();
}

class _SupportProblemsScreenState extends State<SupportProblemsScreen> {
  late final SupportService _service = widget.service ?? SupportService();
  bool _open = true;
  List<SupportProblem>? _problems;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final open = _open;
    try {
      final problems = await _service.problems(open: open);
      if (!mounted || open != _open) return;
      setState(() {
        _problems = problems;
        _failed = false;
      });
    } catch (e) {
      debugPrint('[Support] problems: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _switch(bool open) {
    if (open == _open) return;
    setState(() {
      _open = open;
      _problems = null;
    });
    _load();
  }

  Widget _tab(
    String text,
    bool selected,
    VoidCallback onTap, {
    int? count,
    Key? key,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: _body(
                color: selected
                    ? AppColors.primaryForeground
                    : AppColors.mutedForeground,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: _small(color: AppColors.primaryForeground),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final problems = _problems;
    return _Page(
      title: l.supportProblemsTitle,
      onRefresh: _load,
      children: [
        Row(
          children: [
            _tab(
              l.supportOpen,
              _open,
              () => _switch(true),
              count: _open ? problems?.length : null,
              key: const ValueKey('problems-open'),
            ),
            const SizedBox(width: 8),
            _tab(
              l.supportResolved,
              !_open,
              () => _switch(false),
              key: const ValueKey('problems-resolved'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (problems == null && _failed)
          _message(l.supportLoadFailed)
        else if (problems == null)
          _loading()
        else if (problems.isEmpty)
          _message(l.supportNoProblems, key: const ValueKey('problems-empty'))
        else
          for (final p in problems) ...[
            _ProblemCard(
              problem: p,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SupportProblemDetailScreen(
                      problem: p,
                      service: _service,
                    ),
                  ),
                );
                if (mounted) _load();
              },
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _ProblemCard extends StatelessWidget {
  final SupportProblem problem;
  final VoidCallback onTap;
  const _ProblemCard({required this.problem, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = problem;
    return _Card(
      cardKey: ValueKey('problem-${p.disputeId}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _reasonChip(l, p.reason),
              Text(_ago(context, p.createdAt), style: _small()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Avatar(name: p.reporterName, path: p.reporterAvatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p.reportedBySender
                              ? l.supportReportedBySender
                              : l.supportReportedByTraveler)
                          .toUpperCase(),
                      style: _label(),
                    ),
                    Text(p.reporterName, style: _body()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(p.itemName, style: _title()),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(
                Icons.flight_takeoff_rounded,
                size: 12,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: 4),
              Text(p.route, style: _small()),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.supportInEscrow.toUpperCase(), style: _label()),
                  Text(_money(p.amount, p.currency), style: _title()),
                ],
              ),
              Row(
                children: [
                  Text(
                    l.supportViewDetails,
                    style: _body(color: AppColors.accent),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Problem Detail ──────────────────────────────────────────────────────────

class SupportProblemDetailScreen extends StatefulWidget {
  final SupportProblem problem;
  final SupportService? service;
  const SupportProblemDetailScreen({
    super.key,
    required this.problem,
    this.service,
  });

  @override
  State<SupportProblemDetailScreen> createState() =>
      _SupportProblemDetailScreenState();
}

class _SupportProblemDetailScreenState
    extends State<SupportProblemDetailScreen> {
  late final SupportService _service = widget.service ?? SupportService();
  final _note = TextEditingController();
  ({String? pickup, String? handover}) _photos = (pickup: null, handover: null);
  bool _confirmRefund = false;
  bool _confirmDeposit = false;
  bool _busy = false;

  SupportProblem get _p => widget.problem;

  @override
  void initState() {
    super.initState();
    _note.text = _p.resolution;
    _service
        .photos(_p.requestId)
        .then((p) {
          if (mounted) setState(() => _photos = p);
        })
        .catchError((Object e) {
          debugPrint('[Support] photos: $e');
        });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() action, String done) async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _snack(context, done);
      navigator.pop(true);
    } catch (e) {
      debugPrint('[Support] action: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(context, l.supportActionFailed);
    }
  }

  String _day(DateTime? d) => d == null ? '' : DateFormat('MMM d').format(d);

  Widget _step(
    String title,
    String sub, {
    String? photo,
    bool last = false,
    bool reported = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: reported ? AppColors.accent : _green,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.card, width: 3),
                  ),
                ),
                if (!last)
                  Expanded(child: Container(width: 1, color: AppColors.border)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _body(
                      color: reported ? AppColors.accent : AppColors.foreground,
                    ),
                  ),
                  Text(sub, style: _small()),
                  if (photo != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photo,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = _p;
    final amount = _money(p.amount, p.currency);
    final (
      String payLine,
      String paySub,
      _Chip payChip,
    ) = switch (p.paymentStatus) {
      'released' => (
        l.supportReleasedLine(amount),
        '',
        const _Chip('✓', color: _green, background: _greenBg),
      ),
      'refunded' => (
        l.supportRefundedLine(amount),
        '',
        _Chip(
          l.supportRefunded,
          color: AppColors.destructive,
          background: AppColors.destructive.withValues(alpha: 0.1),
        ),
      ),
      _ => (
        l.supportHeldLine(amount),
        l.supportHeldSub,
        _Chip(
          l.supportHeld,
          color: AppColors.accent,
          background: AppColors.accent.withValues(alpha: 0.15),
        ),
      ),
    };
    final steps = <Widget>[
      if (p.paidAt != null)
        _step(
          l.supportPaid,
          '${_day(p.paidAt)} · ${l.supportHeldLine(amount)}',
        ),
      if (p.pickedUpAt != null)
        _step(l.supportPickedUp, _day(p.pickedUpAt), photo: _photos.pickup),
      if (p.deliveredAt != null)
        _step(l.supportDelivered, _day(p.deliveredAt), photo: _photos.handover),
      _step(
        l.supportReported,
        _ago(context, p.createdAt),
        last: true,
        reported: true,
      ),
    ];

    return _Page(
      title: l.supportProblemDetail,
      onRefresh: () async {},
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _reasonChip(l, p.reason),
                  Text(_ago(context, p.createdAt), style: _small()),
                ],
              ),
              const SizedBox(height: 12),
              Text(p.itemName, style: _title()),
              Text('${p.route} · $amount', style: _small()),
              const SizedBox(height: 12),
              Text(l.supportReporterDetails.toUpperCase(), style: _label()),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.input,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  p.details.isEmpty ? l.supportNoDetails : p.details,
                  style: _body(weight: FontWeight.w400),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: l.supportPeople,
          children: [
            _Person(
              name: p.senderName,
              role: l.supportSender,
              phone: p.senderPhone,
            ),
            const SizedBox(height: 8),
            _Person(
              name: p.travelerName,
              role: l.supportTraveler,
              phone: p.travelerPhone,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(title: l.supportTimeline, children: steps),
        const SizedBox(height: 16),
        _Section(
          title: l.supportPaymentStatus,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(payLine, style: _body()),
                        if (paySub.isNotEmpty) Text(paySub, style: _small()),
                      ],
                    ),
                  ),
                  payChip,
                ],
              ),
            ),
            if (p.depositStatus.isNotEmpty && p.depositAmount != null) ...[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('support-deposit'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.input,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  l.supportDepositRow(
                    PriceFormatter.write(p.depositAmount!, p.depositCurrency),
                    switch (p.depositStatus) {
                      'held' => l.depositStatusHeld,
                      'refunding' => l.depositStatusRefunding,
                      'refunded' => l.depositStatusRefunded,
                      _ => l.depositStatusPaidToSender,
                    },
                  ),
                  style: _body(),
                ),
              ),
            ],
          ],
        ),
        if (p.isOpen) ...[
          const SizedBox(height: 16),
          _Section(
            title: l.supportResolutionNote,
            children: [
              TextField(
                key: const ValueKey('support-note'),
                controller: _note,
                minLines: 3,
                maxLines: 5,
                style: _body(weight: FontWeight.w400),
                decoration: InputDecoration(
                  hintText: l.supportResolutionHint,
                  hintStyle: _body(
                    weight: FontWeight.w400,
                    color: AppColors.mutedForeground,
                  ),
                  filled: true,
                  fillColor: AppColors.input,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Pill(
            l.supportMarkResolved,
            buttonKey: const ValueKey('support-resolve'),
            busy: _busy && !_confirmRefund && !_confirmDeposit,
            onTap: () => _act(
              () => _service.resolve(p.disputeId, _note.text),
              l.supportResolvedSnack,
            ),
          ),
          if (p.refundable) ...[
            const SizedBox(height: 10),
            _Pill(
              l.supportRefundSender,
              buttonKey: const ValueKey('support-refund'),
              primary: false,
              destructive: true,
              onTap: _busy
                  ? null
                  : () => setState(() => _confirmRefund = !_confirmRefund),
            ),
            if (_confirmRefund) ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('support-refund-confirm'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.destructive.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.destructive,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.supportRefundConfirmTitle(
                                  amount,
                                  p.senderName,
                                ),
                                style: _title(),
                              ),
                              Text(l.supportRefundConfirmBody, style: _small()),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Pill(
                            l.cancel,
                            primary: false,
                            onTap: () => setState(() => _confirmRefund = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Pill(
                            l.supportConfirmRefund,
                            buttonKey: const ValueKey(
                              'support-refund-confirm-button',
                            ),
                            destructive: true,
                            busy: _busy,
                            onTap: () => _act(
                              () => _service.refundSender(
                                p.disputeId,
                                _note.text,
                              ),
                              l.supportRefundSnack,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (p.depositPayable) ...[
            const SizedBox(height: 10),
            _Pill(
              l.supportPayDeposit,
              buttonKey: const ValueKey('support-pay-deposit'),
              primary: false,
              destructive: true,
              onTap: _busy
                  ? null
                  : () => setState(() => _confirmDeposit = !_confirmDeposit),
            ),
            if (_confirmDeposit) ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('support-pay-deposit-confirm'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.destructive.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.supportPayDepositConfirm(
                        PriceFormatter.write(
                          p.depositAmount ?? 0,
                          p.depositCurrency,
                        ),
                      ),
                      style: _small(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Pill(
                            l.cancel,
                            primary: false,
                            onTap: () =>
                                setState(() => _confirmDeposit = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Pill(
                            l.supportPayDeposit,
                            buttonKey: const ValueKey(
                              'support-pay-deposit-confirm-button',
                            ),
                            destructive: true,
                            busy: _busy,
                            onTap: () => _act(
                              () => _service.payDepositToSender(
                                p.disputeId,
                                _note.text,
                              ),
                              l.supportDepositPaid,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ] else if (p.resolution.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: l.supportResolutionNote,
            children: [
              Text(p.resolution, style: _body(weight: FontWeight.w400)),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Payments & Locks ────────────────────────────────────────────────────────

class SupportPaymentsScreen extends StatefulWidget {
  final SupportService? service;
  final bool startOnLocks;
  const SupportPaymentsScreen({
    super.key,
    this.service,
    this.startOnLocks = false,
  });

  @override
  State<SupportPaymentsScreen> createState() => _SupportPaymentsScreenState();
}

class _SupportPaymentsScreenState extends State<SupportPaymentsScreen> {
  late final SupportService _service = widget.service ?? SupportService();
  late bool _locks = widget.startOnLocks;
  List<FailedPayment>? _failedPayments;
  List<LockedDelivery>? _locked;
  bool _loadFailed = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final failed = await _service.failedPayments();
      final locked = await _service.lockedDeliveries();
      if (!mounted) return;
      setState(() {
        _failedPayments = failed;
        _locked = locked;
        _loadFailed = false;
      });
    } catch (e) {
      debugPrint('[Support] payments: $e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _retry(FailedPayment p) async {
    final l = context.l10n;
    setState(() => _busy.add(p.id));
    try {
      final status = await _service.retry(p);
      if (!mounted) return;
      // Both go out with the next payment job.
      _snack(
        context,
        p.kind == FailedPaymentKind.payout
            ? l.supportPayoutRequeued
            : l.supportRefundRequeued,
      );
    } catch (e) {
      debugPrint('[Support] retry: $e');
      if (mounted) _snack(context, l.supportActionFailed);
    }
    if (!mounted) return;
    setState(() => _busy.remove(p.id));
    _load();
  }

  Future<void> _unlock(LockedDelivery d) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _UnlockDialog(name: d.travelerName),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy.add(d.requestId));
    try {
      await _service.unlock(d.requestId);
      if (mounted) _snack(context, l.supportUnlockedSnack);
    } catch (e) {
      debugPrint('[Support] unlock: $e');
      if (mounted) _snack(context, l.supportActionFailed);
    }
    if (!mounted) return;
    setState(() => _busy.remove(d.requestId));
    _load();
  }

  Widget _tab(
    String text,
    int? count,
    bool selected,
    VoidCallback onTap,
    Color badge,
    Key key,
  ) {
    return Expanded(
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: _body(
                    color: selected
                        ? AppColors.primaryForeground
                        : AppColors.mutedForeground,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.15)
                        : badge.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: _small(
                      color: selected ? AppColors.primaryForeground : badge,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final failed = _failedPayments;
    final locked = _locked;
    final loading = failed == null || locked == null;
    return _Page(
      title: l.supportPaymentsTitle,
      onRefresh: _load,
      children: [
        Row(
          children: [
            _tab(
              l.supportFailedTab,
              failed?.length,
              !_locks,
              () => setState(() => _locks = false),
              AppColors.accent,
              const ValueKey('payments-failed-tab'),
            ),
            const SizedBox(width: 8),
            _tab(
              l.supportLockedTab,
              locked?.length,
              _locks,
              () => setState(() => _locks = true),
              _amber,
              const ValueKey('payments-locked-tab'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (loading && _loadFailed)
          _message(l.supportLoadFailed)
        else if (loading)
          _loading()
        else if (!_locks) ...[
          if (failed.isEmpty)
            _message(
              l.supportNothingFailed,
              key: const ValueKey('failed-empty'),
            ),
          for (final p in failed) ...[
            _FailedCard(
              payment: p,
              busy: _busy.contains(p.id),
              onRetry: () => _retry(p),
            ),
            const SizedBox(height: 12),
          ],
        ] else ...[
          if (locked.isEmpty)
            _message(
              l.supportNothingLocked,
              key: const ValueKey('locked-empty'),
            ),
          for (final d in locked) ...[
            _LockedCard(
              delivery: d,
              busy: _busy.contains(d.requestId),
              onUnlock: () => _unlock(d),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _FailedCard extends StatelessWidget {
  final FailedPayment payment;
  final bool busy;
  final VoidCallback onRetry;
  const _FailedCard({
    required this.payment,
    required this.busy,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = payment;
    final payout = p.kind == FailedPaymentKind.payout;
    return _Card(
      cardKey: ValueKey('failed-${p.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              payout
                  ? _Chip(
                      l.supportPayout,
                      color: AppColors.primary,
                      background: AppColors.secondary,
                    )
                  : _Chip(
                      l.supportRefund,
                      color: AppColors.destructive,
                      background: AppColors.destructive.withValues(alpha: 0.1),
                    ),
              Text(_ago(context, p.updatedAt), style: _small()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Avatar(name: p.personName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.personName, style: _body()),
                    Text(
                      payout ? l.supportTraveler : l.supportSender,
                      style: _small(),
                    ),
                  ],
                ),
              ),
              Text(_money(p.amount, p.currency), style: _title()),
            ],
          ),
          if (p.reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l.supportReasonSaid(p.reason), style: _small()),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Pill(
            l.retry,
            buttonKey: ValueKey('retry-${p.id}'),
            icon: Icons.refresh_rounded,
            busy: busy,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  final LockedDelivery delivery;
  final bool busy;
  final VoidCallback onUnlock;
  const _LockedCard({
    required this.delivery,
    required this.busy,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = delivery;
    return _Card(
      cardKey: ValueKey('locked-${d.requestId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Chip(l.supportLocked, color: _amber, background: _amberBg),
              if (d.pickedUpAt != null)
                Text(_ago(context, d.pickedUpAt!), style: _small()),
            ],
          ),
          const SizedBox(height: 12),
          Text(d.itemName, style: _title()),
          Text(d.route, style: _small()),
          const SizedBox(height: 12),
          _Person(name: d.travelerName, role: l.supportTraveler),
          const SizedBox(height: 8),
          _Person(name: d.senderName, role: l.supportSender),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Text(l.supportWrongAttempts.toUpperCase(), style: _label()),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < d.attempts
                        ? AppColors.destructive
                        : AppColors.border,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                '${d.attempts.clamp(0, 5)}/5',
                style: _small(weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Pill(
            l.supportUnlock,
            buttonKey: ValueKey('unlock-${d.requestId}'),
            icon: Icons.lock_open_rounded,
            busy: busy,
            onTap: onUnlock,
          ),
        ],
      ),
    );
  }
}

class _UnlockDialog extends StatelessWidget {
  final String name;
  const _UnlockDialog({required this.name});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: _amberBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_open_rounded, color: _amber),
            ),
            const SizedBox(height: 16),
            Text(l.supportUnlockTitle, style: _title(size: 16)),
            const SizedBox(height: 4),
            Text(l.supportUnlockBody(name), style: _small()),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Pill(
                    l.cancel,
                    primary: false,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Pill(
                    l.supportConfirmUnlock,
                    buttonKey: const ValueKey('unlock-confirm'),
                    onTap: () => Navigator.of(context).pop(true),
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

// ── Chat Reports ────────────────────────────────────────────────────────────

String _chatReason(AppLocalizations l, String code) {
  for (final r in ChatReportReason.values) {
    if (r.code == code) return ChatReportSheet.reasonLabel(l, r);
  }
  return code;
}

/// Members reported in chat (20240190): open ones, or reviewed ones.
class SupportReportsScreen extends StatefulWidget {
  final SupportService? service;
  const SupportReportsScreen({super.key, this.service});

  @override
  State<SupportReportsScreen> createState() => _SupportReportsScreenState();
}

class _SupportReportsScreenState extends State<SupportReportsScreen> {
  late final SupportService _service = widget.service ?? SupportService();
  bool _open = true;
  List<SupportChatReport>? _reports;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final open = _open;
    try {
      final reports = await _service.chatReports(open: open);
      if (!mounted || open != _open) return;
      setState(() {
        _reports = reports;
        _failed = false;
      });
    } catch (e) {
      debugPrint('[Support] reports: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _switch(bool open) {
    if (open == _open) return;
    setState(() {
      _open = open;
      _reports = null;
    });
    _load();
  }

  Widget _tab(String text, bool selected, VoidCallback onTap, {Key? key}) =>
      GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            text,
            style: _body(
              color: selected
                  ? AppColors.primaryForeground
                  : AppColors.mutedForeground,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reports = _reports;
    return _Page(
      title: l.supportReportsTitle,
      onRefresh: _load,
      children: [
        Row(
          children: [
            _tab(
              l.supportOpen,
              _open,
              () => _switch(true),
              key: const ValueKey('reports-open'),
            ),
            const SizedBox(width: 8),
            _tab(
              l.supportReviewed,
              !_open,
              () => _switch(false),
              key: const ValueKey('reports-reviewed'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (reports == null && _failed)
          _message(l.supportLoadFailed)
        else if (reports == null)
          _loading()
        else if (reports.isEmpty)
          _message(l.supportNoReports, key: const ValueKey('reports-empty'))
        else
          for (final r in reports) ...[
            _ReportCard(
              report: r,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SupportReportDetailScreen(report: r, service: _service),
                  ),
                );
                if (mounted) _load();
              },
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final SupportChatReport report;
  final VoidCallback onTap;
  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = report;
    return _Card(
      cardKey: ValueKey('report-${r.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Chip(
                _chatReason(l, r.reason),
                color: AppColors.destructive,
                background: AppColors.destructive.withValues(alpha: 0.1),
              ),
              Text(_ago(context, r.createdAt), style: _small()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Avatar(name: r.reportedName, path: r.reportedAvatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.supportReportedMember.toUpperCase(),
                      style: _label(),
                    ),
                    Text(r.reportedName, style: _body()),
                    if (r.reportedCount > 1)
                      Text(
                        l.supportTimesReported(r.reportedCount),
                        style: _small(color: AppColors.destructive),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
          if (r.messageBody.isNotEmpty || r.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              r.messageBody.isNotEmpty ? '“${r.messageBody}”' : r.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _small(color: AppColors.foreground),
            ),
          ],
          const SizedBox(height: 8),
          Text('${l.supportReportedBy} ${r.reporterName}', style: _small()),
        ],
      ),
    );
  }
}

/// One chat report: who, why, the conversation, and closing it with a note.
class SupportReportDetailScreen extends StatefulWidget {
  final SupportChatReport report;
  final SupportService? service;
  const SupportReportDetailScreen({
    super.key,
    required this.report,
    this.service,
  });

  @override
  State<SupportReportDetailScreen> createState() =>
      _SupportReportDetailScreenState();
}

class _SupportReportDetailScreenState extends State<SupportReportDetailScreen> {
  late final SupportService _service = widget.service ?? SupportService();
  final _note = TextEditingController();
  List<SupportReportMessage>? _messages;
  bool _busy = false;

  SupportChatReport get _r => widget.report;

  @override
  void initState() {
    super.initState();
    _service
        .reportMessages(_r.id)
        .then((m) {
          if (mounted) setState(() => _messages = m);
        })
        .catchError((Object e) {
          debugPrint('[Support] report messages: $e');
          if (mounted) setState(() => _messages = const []);
        });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _review() async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await _service.reviewReport(_r.id, _note.text);
      if (!mounted) return;
      _snack(context, l.supportReviewedSnack);
      navigator.pop(true);
    } catch (e) {
      debugPrint('[Support] review report: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(context, l.supportActionFailed);
    }
  }

  Widget _bubble(SupportReportMessage m) {
    final reported = m.authorId == _r.reportedId;
    final text = m.hasPhoto && m.body.isEmpty
        ? context.l10n.supportPhotoMessage
        : m.body;
    return Align(
      alignment: reported ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: reported
              ? AppColors.destructive.withValues(alpha: 0.06)
              : AppColors.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: reported
                ? AppColors.destructive.withValues(alpha: 0.25)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reported ? _r.reportedName : _r.reporterName,
              style: _small(weight: FontWeight.w700),
            ),
            Text(text, style: _body(weight: FontWeight.w400)),
            Text(
              DateFormat('MMM d, h:mm a').format(m.createdAt),
              style: _small(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = _r;
    final messages = _messages;
    return _Page(
      title: l.supportReportsTitle,
      onRefresh: () async {},
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Chip(
                    _chatReason(l, r.reason),
                    color: AppColors.destructive,
                    background: AppColors.destructive.withValues(alpha: 0.1),
                  ),
                  Text(_ago(context, r.createdAt), style: _small()),
                ],
              ),
              const SizedBox(height: 12),
              _Person(name: r.reportedName, role: l.supportReportedMember),
              const SizedBox(height: 8),
              _Person(name: r.reporterName, role: l.supportReportedBy),
              const SizedBox(height: 8),
              if (r.reportedCount > 1)
                Text(
                  l.supportTimesReported(r.reportedCount),
                  style: _small(color: AppColors.destructive),
                ),
              if (r.blocked) Text(l.supportBlockedByReporter, style: _small()),
            ],
          ),
        ),
        if (r.messageBody.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: l.supportReportedMessage,
            children: [
              Text(
                r.messageBody,
                key: const ValueKey('report-message-body'),
                style: _body(weight: FontWeight.w400),
              ),
            ],
          ),
        ],
        if (r.note.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: l.supportReportNote,
            children: [Text(r.note, style: _body(weight: FontWeight.w400))],
          ),
        ],
        const SizedBox(height: 16),
        _Section(
          title: l.supportConversation,
          children: [
            if (messages == null)
              const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            else
              for (final m in messages) _bubble(m),
          ],
        ),
        const SizedBox(height: 16),
        if (r.isOpen) ...[
          _Section(
            title: l.supportResolutionNote,
            children: [
              TextField(
                key: const ValueKey('report-review-note'),
                controller: _note,
                minLines: 3,
                maxLines: 5,
                style: _body(weight: FontWeight.w400),
                decoration: InputDecoration(
                  hintText: l.supportReviewNoteHint,
                  hintStyle: _body(
                    weight: FontWeight.w400,
                    color: AppColors.mutedForeground,
                  ),
                  filled: true,
                  fillColor: AppColors.input,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Pill(
            l.supportMarkReviewed,
            buttonKey: const ValueKey('report-mark-reviewed'),
            busy: _busy,
            onTap: _review,
          ),
        ] else if (r.reviewNote.isNotEmpty)
          _Section(
            title: l.supportResolutionNote,
            children: [
              Text(r.reviewNote, style: _body(weight: FontWeight.w400)),
            ],
          ),
      ],
    );
  }
}
