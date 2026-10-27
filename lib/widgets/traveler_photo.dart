import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../main.dart';
import 'avatar_image.dart';

/// A traveler's photo where people browse: blurred until the traveler
/// accepts one of the viewer's requests (20240188_blur_traveler_photos.sql).
/// The shape and colours still show, not the face.
class TravelerPhoto extends StatelessWidget {
  final String? path;
  final bool revealed;
  final double size;

  const TravelerPhoto({
    super.key,
    required this.path,
    required this.revealed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.secondary,
      child: Icon(Icons.person, color: AppColors.primary, size: size * 0.5),
    );
    final photo = AvatarImage(path: path, fallback: fallback);
    final hidden = !revealed && (path ?? '').trim().isNotEmpty;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hidden
            ? ImageFiltered(
                key: const ValueKey('traveler-photo-blurred'),
                imageFilter: ImageFilter.blur(
                  sigmaX: size / 24,
                  sigmaY: size / 24,
                ),
                child: photo,
              )
            : photo,
      ),
    );
  }
}
