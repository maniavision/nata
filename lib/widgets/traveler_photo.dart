import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../main.dart';
import 'avatar_image.dart';

/// A traveler's photo where people browse: blurred, with a small lock, until
/// the traveler accepts one of the viewer's requests (designed in Sleek;
/// 20240188_blur_traveler_photos.sql). The shape and colours still show, not
/// the face.
class TravelerPhoto extends StatelessWidget {
  final String? path;
  final bool revealed;
  final double size;

  /// The lock in the bottom-left corner (when a badge has the right one).
  final bool lockLeft;

  const TravelerPhoto({
    super.key,
    required this.path,
    required this.revealed,
    required this.size,
    this.lockLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.secondary,
      child: Icon(Icons.person, color: AppColors.primary, size: size * 0.5),
    );
    final photo = AvatarImage(path: path, fallback: fallback);
    final hidden = !revealed && (path ?? '').trim().isNotEmpty;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: hidden
                  ? ImageFiltered(
                      key: const ValueKey('traveler-photo-blurred'),
                      imageFilter: ImageFilter.blur(
                        sigmaX: size / 32,
                        sigmaY: size / 32,
                      ),
                      child: photo,
                    )
                  : photo,
            ),
          ),
          if (hidden)
            Positioned(
              right: lockLeft ? null : -1,
              left: lockLeft ? -1 : null,
              bottom: -1,
              child: Container(
                key: const ValueKey('traveler-photo-lock'),
                width: (size * 0.36).clamp(14, 26),
                height: (size * 0.36).clamp(14, 26),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.card, width: 1.5),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: (size * 0.2).clamp(8, 14),
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
