import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';

/// True when [error] means the user turned camera access off for Nata.
/// iOS asks only once; after "Don't Allow" the camera stays off until it is
/// switched on again in Settings.
bool isCameraDenied(Object error) {
  if (error is PlatformException) {
    return error.code == 'camera_access_denied' ||
        error.code == 'camera_access_restricted';
  }
  if (error is CameraException) {
    return error.code.contains('AccessDenied') ||
        error.code.contains('Restricted');
  }
  return false;
}

/// Opens Nata's page in the phone's Settings.
Future<void> openAppSettings() async {
  try {
    await launchUrl(Uri.parse('app-settings:'));
  } catch (e) {
    debugPrint('[Camera] could not open Settings: $e');
  }
}

/// "Camera access is off" (designed in Sleek, "Camera Access Off (Sheet)"):
/// says how to switch the camera back on and opens Settings.
Future<void> showCameraDeniedSheet(
  BuildContext context, {
  Future<void> Function()? openSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.foreground.withValues(alpha: 0.45),
    builder: (_) =>
        CameraDeniedSheet(openSettings: openSettings ?? openAppSettings),
  );
}

class CameraDeniedSheet extends StatelessWidget {
  final Future<void> Function() openSettings;

  const CameraDeniedSheet({super.key, required this.openSettings});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      key: const ValueKey('camera-denied'),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                color: AppColors.accent,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.cameraOffTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.cameraOffBody,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.45,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l.cameraOffPath,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('camera-denied-settings'),
                onPressed: () {
                  Navigator.of(context).pop();
                  openSettings();
                },
                icon: const Icon(Icons.settings_rounded, size: 20),
                label: Text(l.openSettings),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentForeground,
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const ValueKey('camera-denied-close'),
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mutedForeground,
                textStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: Text(l.notNow),
            ),
          ],
        ),
      ),
    );
  }
}
