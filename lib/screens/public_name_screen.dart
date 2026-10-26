import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/nata_toast.dart';
import '../widgets/page_header.dart';

/// How people who find this member as a traveler see their name (designed
/// in Sleek, "Public name"): their first name and last initial, or a
/// pseudonym. It shows in search, on their profile and in route alerts;
/// once they accept a request, that sender and the recipient see the real
/// first name (20240183_traveler_pseudonym.sql). Pops with true once saved.
class PublicNameScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String? avatarPath;
  final bool verified;
  final double? rating;
  final bool usePseudonym;
  final String? pseudonym;
  final AuthService? authService;

  const PublicNameScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    this.avatarPath,
    this.verified = false,
    this.rating,
    this.usePseudonym = false,
    this.pseudonym,
    this.authService,
  });

  /// 2 to 20 letters or numbers; spaces and . _ - after the first one.
  static final _shape = RegExp(
    r'^[\p{L}\p{N}][\p{L}\p{N} ._-]*$',
    unicode: true,
  );
  static final _reserved = RegExp(
    'nata|admin|support|moderator',
    caseSensitive: false,
  );

  /// Null when [name] can be used, or why not.
  static PseudonymProblem? check(String name) {
    final n = name.trim();
    if (n.length < 2 || n.length > 20 || !_shape.hasMatch(n)) {
      return PseudonymProblem.invalid;
    }
    if (_reserved.hasMatch(n)) return PseudonymProblem.reserved;
    return null;
  }

  @override
  State<PublicNameScreen> createState() => _PublicNameScreenState();
}

enum PseudonymProblem { invalid, reserved }

class _PublicNameScreenState extends State<PublicNameScreen> {
  late bool _pseudo = widget.usePseudonym;
  late final _field = TextEditingController(text: widget.pseudonym ?? '');
  PseudonymProblem? _problem;
  bool _saving = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  String get _realName {
    final last = widget.lastName.trim();
    return last.isEmpty
        ? widget.firstName.trim()
        : '${widget.firstName.trim()} ${last[0].toUpperCase()}.';
  }

  String get _shown {
    final p = _field.text.trim();
    return _pseudo && p.isNotEmpty ? p : _realName;
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _field.text.trim();
    if (_pseudo) {
      final problem = PublicNameScreen.check(name);
      if (problem != null) {
        setState(() => _problem = problem);
        return;
      }
    }
    setState(() {
      _saving = true;
      _problem = null;
    });
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await (widget.authService ?? AuthService()).setPublicName(
        usePseudonym: _pseudo,
        pseudonym: name.isEmpty ? null : name,
      );
      messenger.showSnackBar(
        nataToast(l.publicNameSaved, tone: ToastTone.success),
      );
      navigator.pop(true);
    } on PseudonymException catch (e) {
      if (mounted) {
        setState(() {
          _problem = e.reserved
              ? PseudonymProblem.reserved
              : PseudonymProblem.invalid;
        });
      }
    } catch (e) {
      debugPrint('[PublicName] save: $e');
      messenger.showSnackBar(
        nataToast(l.errRequestFailed, tone: ToastTone.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            PageHeader(title: l.publicNameRow),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
                children: [
                  Text(
                    l.publicNameIntro,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _option(
                    key: 'public-name-real',
                    selected: !_pseudo,
                    title: l.publicNameReal,
                    preview: _realName,
                    subtitle: l.publicNameRealSub,
                    onTap: () => setState(() {
                      _pseudo = false;
                      _problem = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _option(
                    key: 'public-name-pseudonym',
                    selected: _pseudo,
                    title: l.publicNamePseudo,
                    subtitle: l.publicNamePseudoSub,
                    onTap: () => setState(() => _pseudo = true),
                    child: _pseudo ? _pseudonymField() : null,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.publicNameInfo,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              height: 1.45,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l.publicNamePreview.toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _preview(),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  key: const ValueKey('public-name-save'),
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    shape: const StadiumBorder(),
                    textStyle: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryForeground,
                          ),
                        )
                      : Text(l.publicNameSave),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option({
    required String key,
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? preview,
    Widget? child,
  }) {
    return GestureDetector(
      key: ValueKey(key),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                if (preview != null && preview.isNotEmpty)
                  Text(
                    preview,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            if (child != null)
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 12),
                child: child,
              ),
          ],
        ),
      ),
    );
  }

  Widget _pseudonymField() {
    final l = context.l10n;
    final error = switch (_problem) {
      PseudonymProblem.invalid => l.publicNameInvalid,
      PseudonymProblem.reserved => l.publicNameReserved,
      null => null,
    };
    return TextField(
      key: const ValueKey('public-name-field'),
      controller: _field,
      autofocus: (widget.pseudonym ?? '').isEmpty,
      maxLength: 20,
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => setState(() => _problem = null),
      style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.foreground),
      decoration: InputDecoration(
        labelText: l.publicNameField,
        hintText: l.publicNameHint,
        helperText: error == null ? l.publicNameHelper : null,
        errorText: error,
        counterText: '',
        filled: true,
        fillColor: AppColors.input,
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
  }

  /// The row people see in search, with the name chosen.
  Widget _preview() {
    return Container(
      key: const ValueKey('public-name-preview'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: AvatarImage(
                path: widget.avatarPath,
                fallback: Container(
                  color: AppColors.secondary,
                  alignment: Alignment.center,
                  child: Text(
                    _shown.isEmpty ? '?' : _shown.characters.first,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _shown,
                        key: const ValueKey('public-name-shown'),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    if (widget.verified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Color(0xFF168A68),
                      ),
                    ],
                  ],
                ),
                if (widget.rating != null)
                  Text(
                    '★ ${widget.rating!.toStringAsFixed(1)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
}
