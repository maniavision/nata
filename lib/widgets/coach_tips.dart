import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/screen_cache.dart';

/// One tip: a bubble pointing at [target] (designed in Sleek, "First Visit
/// Tips").
class CoachTip {
  final GlobalKey target;
  final String title;
  final String body;
  final IconData icon;

  const CoachTip({
    required this.target,
    required this.title,
    required this.body,
    required this.icon,
  });
}

/// First-visit tips: the screen dims except for one spot at a time, with a
/// bubble saying what it is for. "Next" moves on, "Skip" ends them. Shown
/// once per member on this device ([seenKey] is remembered when they end).
class CoachTips {
  /// Off in tests, so tips don't cover the screens under test.
  static bool enabled = true;

  static String seenKey(String name, String userId) =>
      'coach_tips_seen_${name}_$userId';

  /// One set of tips at a time.
  static bool _showing = false;

  /// A page's tips for the signed-in member, once the page has settled and
  /// only while it is the screen on top. [tips] is called then, so the
  /// targets are built.
  static void showWhenSettled(
    BuildContext context, {
    required String name,
    required List<CoachTip> Function() tips,
  }) {
    if (!enabled) return;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!context.mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      final userId = ScreenCache.userId();
      if (userId == null) return;
      showOnce(context, name: name, userId: userId, tips: tips());
    });
  }

  /// Shows [tips] unless they were seen. Tips whose target isn't on screen
  /// are left out.
  static Future<void> showOnce(
    BuildContext context, {
    required String name,
    required String userId,
    required List<CoachTip> tips,
  }) async {
    if (!enabled || _showing) return;
    final key = seenKey(name, userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(key) ?? false) return;
    } catch (_) {
      return;
    }
    if (!context.mounted || _showing) return;
    final shown = tips.where((t) => t.target.currentContext != null).toList();
    if (shown.isEmpty) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    _showing = true;
    entry = OverlayEntry(
      builder: (_) => CoachTipsOverlay(
        tips: shown,
        onDone: () async {
          entry.remove();
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(key, true);
          } catch (_) {}
        },
      ),
    );
    overlay.insert(entry);
  }
}

/// The dimmed screen, the highlighted spot and the bubble.
class CoachTipsOverlay extends StatefulWidget {
  final List<CoachTip> tips;
  final VoidCallback onDone;

  const CoachTipsOverlay({super.key, required this.tips, required this.onDone});

  @override
  State<CoachTipsOverlay> createState() => _CoachTipsOverlayState();
}

class _CoachTipsOverlayState extends State<CoachTipsOverlay> {
  int _index = 0;
  Rect? _spot;

  @override
  void initState() {
    super.initState();
    _focus();
  }

  @override
  void dispose() {
    // However the tips end (or the app tears them down), others may show.
    CoachTips._showing = false;
    super.dispose();
  }

  CoachTip get _tip => widget.tips[_index];

  /// Scrolls the target into view, then measures it.
  Future<void> _focus() async {
    final target = _tip.target.currentContext;
    if (target == null) return _next();
    if (Scrollable.maybeOf(target) != null) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: const Duration(milliseconds: 250),
      );
      if (!mounted || !target.mounted) return;
      await Scrollable.ensureVisible(
        target,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        duration: const Duration(milliseconds: 250),
      );
    }
    if (!mounted || !target.mounted) return;
    final box = target.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return _next();
    final origin = box.localToGlobal(Offset.zero);
    setState(() => _spot = (origin & box.size).inflate(6));
  }

  void _next() {
    if (_index + 1 >= widget.tips.length) {
      widget.onDone();
      return;
    }
    setState(() {
      _index++;
      _spot = null;
    });
    _focus();
  }

  @override
  Widget build(BuildContext context) {
    final spot = _spot;
    final size = MediaQuery.sizeOf(context);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Taps outside the bubble do nothing: the tips end with Skip or
          // the last "Got it".
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(painter: _ScrimPainter(spot)),
            ),
          ),
          if (spot != null) _bubble(spot, size),
        ],
      ),
    );
  }

  Widget _bubble(Rect spot, Size size) {
    final width = (size.width - 32).clamp(0.0, 320.0);
    const arrow = 10.0;
    final left = (spot.center.dx - width / 2).clamp(
      16.0,
      size.width - width - 16,
    );
    // Below the spot when it is in the top half, above it otherwise.
    final below = spot.center.dy < size.height / 2;
    final card = _card();
    final arrowX = (spot.center.dx - left - arrow).clamp(16.0, width - 36);
    final pointer = Padding(
      padding: EdgeInsets.only(left: arrowX),
      child: CustomPaint(
        size: const Size(arrow * 2, arrow),
        painter: _ArrowPainter(up: below),
      ),
    );
    return Positioned(
      key: ValueKey('coach-tip-$_index'),
      left: left,
      width: width,
      top: below ? spot.bottom + 4 : null,
      bottom: below ? null : size.height - spot.top + 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: below ? [pointer, card] : [card, pointer],
      ),
    );
  }

  Widget _card() {
    final l = context.l10n;
    final last = _index == widget.tips.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_tip.icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tip.title,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.primaryForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tip.body,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.primaryForeground.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Where the member is: one dot per tip.
              for (var i = 0; i < widget.tips.length; i++)
                Container(
                  width: i == _index ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.accent
                        : AppColors.primaryForeground.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 8),
              // Long labels (French, Spanish) wrap instead of overflowing.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (!last)
                      TextButton(
                        key: const ValueKey('coach-tip-skip'),
                        onPressed: widget.onDone,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryForeground
                              .withValues(alpha: 0.7),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(
                          l.tipSkip,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ElevatedButton(
                      key: const ValueKey('coach-tip-next'),
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        last ? l.tipGotIt : l.tipNext,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dims everything but [spot].
class _ScrimPainter extends CustomPainter {
  final Rect? spot;

  _ScrimPainter(this.spot);

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final path = spot == null
        ? screen
        : Path.combine(
            PathOperation.difference,
            screen,
            Path()..addRRect(
              RRect.fromRectAndRadius(spot!, const Radius.circular(16)),
            ),
          );
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.spot != spot;
}

/// The bubble's pointer, toward the highlighted spot.
class _ArrowPainter extends CustomPainter {
  final bool up;

  _ArrowPainter({required this.up});

  @override
  void paint(Canvas canvas, Size size) {
    final path = up
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0));
    canvas.drawPath(path..close(), Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.up != up;
}
