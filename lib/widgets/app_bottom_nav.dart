import 'dart:ui';

import '../services/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../screens/home_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/requests_screen.dart';
import '../screens/trips_screen.dart';

/// The app-wide bottom navigation bar:
/// Home · Requests · Trips · Messages · Profile.
///
/// One implementation shared by every screen so the bar always looks and
/// behaves the same.
class AppBottomNav extends StatelessWidget {
  /// Index of the highlighted tab (0 Home, 1 Requests, 2 Trips, 3 Messages,
  /// 4 Profile).
  final int current;

  /// Whether this screen *is* the tab's root screen. When true, tapping the
  /// highlighted tab does nothing. Sub-pages (e.g. search results) pass false
  /// so tapping their highlighted tab still navigates there.
  final bool isTabRoot;

  /// Called after returning to the host screen from a pushed tab screen
  /// (used by Home to refresh its data).
  final VoidCallback? onReturn;

  const AppBottomNav({
    super.key,
    required this.current,
    this.isTabRoot = true,
    this.onReturn,
  });

  static const _icons = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.list_alt_outlined, Icons.list_alt_rounded),
    (Icons.luggage_outlined, Icons.luggage_rounded),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
    (Icons.account_circle_outlined, Icons.account_circle_rounded),
  ];

  Widget _destination(int index) {
    switch (index) {
      case 1:
        return const RequestsScreen();
      case 2:
        return const TripsScreen();
      case 3:
        return const MessagesScreen();
      default:
        return const ProfileScreen();
    }
  }

  /// Switching tabs shows the new tab straight away, without the sliding
  /// animation of opening a page (and without its swipe-back gesture).
  static Route<T> tabRoute<T>(Widget screen) => PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );

  Future<void> _onTap(BuildContext context, int index) async {
    if (index == current && isTabRoot) return;
    // Only Home is open to visitors who aren't signed in.
    if (index != 0 && !AuthGate.check(context)) return;

    final navigator = Navigator.of(context);

    if (index == 0) {
      // Home is the root of the app: go back to it and drop everything above.
      navigator.pushAndRemoveUntil(
        tabRoute<void>(const HomeScreen()),
        (route) => false,
      );
      return;
    }

    final route = tabRoute<void>(_destination(index));

    if (current == 0 && isTabRoot) {
      // From Home: stack the tab screen on top, refresh Home on return.
      await navigator.push(route);
      onReturn?.call();
    } else {
      // From another tab: swap screens so the back stack doesn't pile up.
      navigator.pushReplacement(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Visitors who aren't signed in only browse Home: no tab bar.
    if (!AuthGate.isSignedIn()) return const SizedBox.shrink();
    final l = context.l10n;
    final labels = [l.home, l.requests, l.trips, l.messages, l.profile];
    final bottom = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 64 + bottom,
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: EdgeInsets.only(bottom: bottom),
          child: Row(
            children: List.generate(labels.length, (i) {
              final active = current == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTap(context, i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? _icons[i].$2 : _icons[i].$1,
                        size: 22,
                        color: active
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[i],
                        style: GoogleFonts.dmSans(
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 10,
                          color: active
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
