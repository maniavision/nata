import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/app_update_service.dart';

/// Opens [url] in the store; false when that did not work.
typedef StoreLauncher = Future<bool> Function(String url);

Future<bool> _openInStore(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Tells the user when a newer version of the app has been published.
///
/// It looks when the app opens and again when the app comes back from the
/// background (at most every [recheckEvery]). The notice is drawn on the
/// navigator's overlay rather than pushed as a page, so it never disturbs the
/// screens underneath (the splash screen replaces itself, for example).
///
/// Put it around the [MaterialApp] and give the app the same [navigatorKey].
class AppUpdateListener extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// Overrides for tests.
  final AppUpdateService? service;
  final StoreLauncher? launcher;
  final Duration recheckEvery;
  final DateTime Function()? now;

  const AppUpdateListener({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.service,
    this.launcher,
    this.recheckEvery = const Duration(hours: 6),
    this.now,
  });

  @override
  State<AppUpdateListener> createState() => _AppUpdateListenerState();
}

class _AppUpdateListenerState extends State<AppUpdateListener>
    with WidgetsBindingObserver {
  late final AppUpdateService _service = widget.service ?? AppUpdateService();
  OverlayEntry? _entry;
  bool _checking = false;
  DateTime? _lastCheck;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame, when the navigator exists.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    if (last == null || _now().difference(last) >= widget.recheckEvery) {
      _check();
    }
  }

  Future<void> _check() async {
    if (_checking || _entry != null) return;
    _checking = true;
    try {
      _lastCheck = _now();
      final update = await _service.check();
      if (update == null || !mounted) return;
      if (!await _service.shouldPrompt(update) || !mounted) return;
      final overlay = widget.navigatorKey.currentState?.overlay;
      if (overlay == null) return;
      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => UpdateNotice(
          update: update,
          launcher: widget.launcher ?? _openInStore,
          onLater: () {
            unawaited(_service.postpone(update));
            _close(entry);
          },
        ),
      );
      _entry = entry;
      overlay.insert(entry);
    } catch (e) {
      // Telling the user about an update must never break the app.
      debugPrint('[AppUpdateListener] $e');
    } finally {
      _checking = false;
    }
  }

  void _close(OverlayEntry entry) {
    entry.remove();
    if (_entry == entry) _entry = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The "update available" / "update required" card, over a dimmed screen.
class UpdateNotice extends StatefulWidget {
  final AppUpdate update;
  final StoreLauncher launcher;

  /// Called for "Later". Not offered when the update is compulsory.
  final VoidCallback onLater;

  const UpdateNotice({
    super.key,
    required this.update,
    required this.launcher,
    required this.onLater,
  });

  @override
  State<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<UpdateNotice> {
  bool _opening = false;
  bool _failed = false;

  Future<void> _update() async {
    final url = widget.update.storeUrl;
    if (url == null || _opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    bool ok;
    try {
      ok = await widget.launcher(url);
    } catch (_) {
      ok = false;
    }
    if (mounted) {
      setState(() {
        _opening = false;
        _failed = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final u = widget.update;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Blocks the screen underneath; a tap outside does nothing.
          const ModalBarrier(dismissible: false, color: Color(0x99102F35)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  key: const ValueKey('update-notice'),
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          color: AppColors.accent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        u.mandatory
                            ? l.updateRequiredTitle
                            : l.updateAvailableTitle,
                        key: const ValueKey('update-title'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        u.mandatory
                            ? l.updateRequiredBody
                            : l.updateAvailableBody(u.latest, u.current),
                        key: const ValueKey('update-body'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      if (u.notes.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.updateWhatsNew.toUpperCase(),
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  letterSpacing: 1.3,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                u.notes,
                                key: const ValueKey('update-notes'),
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: AppColors.foreground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_failed) ...[
                        const SizedBox(height: 12),
                        Text(
                          l.updateOpenFailed,
                          key: const ValueKey('update-open-failed'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.destructive,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (u.storeUrl != null)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            key: const ValueKey('update-now'),
                            onPressed: _opening ? null : _update,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              disabledBackgroundColor: AppColors.accent
                                  .withValues(alpha: 0.6),
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              l.updateNow,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (!u.mandatory)
                        TextButton(
                          key: const ValueKey('update-later'),
                          onPressed: widget.onLater,
                          child: Text(
                            l.updateLater,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
