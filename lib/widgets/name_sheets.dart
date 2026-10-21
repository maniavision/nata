import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/auth_service.dart' show NameLockedException;

/// Where members write for what the app can't do, such as changing a
/// verified name.
const supportEmail = 'support@nata.com';

/// Saves a new name. Throws [NameLockedException] once the identity check
/// has started (the server refuses it, migration 20240160).
typedef SaveName = Future<void> Function(String first, String last);

/// The pencil next to the name on Profile: edits it while the member isn't
/// verified, otherwise explains why it is locked (designed in Sleek: "Edit
/// Name (Sheet)" and "Name Locked (Sheet)"). Returns true when the name was
/// changed.
Future<bool?> showNameSheet(
  BuildContext context, {
  required String verificationStatus,
  required String firstName,
  required String lastName,
  required SaveName save,
  Future<void> Function(Uri)? openEmail,
}) {
  final locked =
      verificationStatus == 'pending' || verificationStatus == 'verified';
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.foreground.withValues(alpha: 0.45),
    builder: (_) => locked
        ? NameLockedSheet(
            name: '$firstName $lastName'.trim(),
            openEmail: openEmail,
          )
        : EditNameSheet(firstName: firstName, lastName: lastName, save: save),
  );
}

Widget _sheet({required Key key, required List<Widget> children}) => Builder(
  builder: (context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        key: key,
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  },
);

ButtonStyle _primary() => FilledButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: AppColors.primaryForeground,
  shape: const StadiumBorder(),
  textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15),
);

Widget _textButton(BuildContext context, Key key, String label) => TextButton(
  key: key,
  onPressed: () => Navigator.of(context).pop(),
  style: TextButton.styleFrom(
    foregroundColor: AppColors.mutedForeground,
    textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14),
  ),
  child: Text(label),
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

InputDecoration _field({bool readOnly = false}) => InputDecoration(
  filled: true,
  fillColor: readOnly ? AppColors.secondary : AppColors.input,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
  ),
);

/// "Edit your name", for members who aren't verified yet.
class EditNameSheet extends StatefulWidget {
  final String firstName;
  final String lastName;
  final SaveName save;

  const EditNameSheet({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.save,
  });

  @override
  State<EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<EditNameSheet> {
  late final _first = TextEditingController(text: widget.firstName);
  late final _last = TextEditingController(text: widget.lastName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final first = _first.text.trim();
    final last = _last.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(() => _error = l.nameErrEmpty);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(first, last);
      if (mounted) Navigator.of(context).pop(true);
    } on NameLockedException {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l.nameErrLocked;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l.nameErrFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = GoogleFonts.dmSans(fontSize: 14, color: AppColors.foreground);
    return _sheet(
      key: const ValueKey('edit-name-sheet'),
      children: [
        Text(
          l.nameEditTitle,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l.nameEditHelper,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            height: 1.45,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 18),
        _label(l.firstName),
        TextField(
          key: const ValueKey('edit-first-name'),
          controller: _first,
          enabled: !_saving,
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
          style: style,
          decoration: _field().copyWith(counterText: ''),
        ),
        const SizedBox(height: 12),
        _label(l.lastName),
        TextField(
          key: const ValueKey('edit-last-name'),
          controller: _last,
          enabled: !_saving,
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
          style: style,
          decoration: _field().copyWith(counterText: ''),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            key: const ValueKey('edit-name-error'),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.destructive,
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const ValueKey('edit-name-save'),
            onPressed: _saving ? null : _save,
            style: _primary(),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryForeground,
                    ),
                  )
                : Text(l.nameSave),
          ),
        ),
        const SizedBox(height: 4),
        _textButton(context, const ValueKey('edit-name-cancel'), l.cancel),
      ],
    );
  }
}

/// "Your name matches your ID", for verified or under-review members.
class NameLockedSheet extends StatelessWidget {
  final String name;
  final Future<void> Function(Uri)? openEmail;

  const NameLockedSheet({super.key, required this.name, this.openEmail});

  static Uri supportUri(String subject) => Uri(
    scheme: 'mailto',
    path: supportEmail,
    query: 'subject=${Uri.encodeComponent(subject)}',
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _sheet(
      key: const ValueKey('name-locked-sheet'),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF168A68).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 30,
              color: Color(0xFF168A68),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.nameLockedTitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.nameLockedBody,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            height: 1.45,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          key: const ValueKey('locked-name'),
          controller: TextEditingController(text: name),
          readOnly: true,
          enableInteractiveSelection: false,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
          decoration: _field(readOnly: true).copyWith(
            suffixIcon: const Icon(
              Icons.lock_rounded,
              size: 18,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const ValueKey('name-contact-support'),
            onPressed: () async {
              final uri = supportUri(l.nameSupportSubject);
              Navigator.of(context).pop();
              try {
                await (openEmail ?? (u) => launchUrl(u))(uri);
              } catch (e) {
                debugPrint('[Name] could not open email: $e');
              }
            },
            icon: const Icon(Icons.mail_rounded, size: 20),
            label: Text(l.nameContactSupport),
            style: _primary(),
          ),
        ),
        const SizedBox(height: 4),
        _textButton(context, const ValueKey('name-locked-close'), l.close),
      ],
    );
  }
}
