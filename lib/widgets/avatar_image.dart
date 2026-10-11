import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Profile picture that is downloaded once and then served from the
/// in-memory image cache (instant, within a session) and the on-disk cache
/// (instant, across app launches).
///
/// The cache key is the storage path, which stays the same between builds, so
/// rebuilding screens never triggers a new download. After uploading a new
/// picture call [AvatarImage.replace] so every [AvatarImage] swaps to it
/// immediately.
class AvatarImage extends StatelessWidget {
  /// Storage path (e.g. `avatars/<uid>/avatar_<uid>.jpg`) or full URL.
  final String? path;
  final Widget fallback;
  final BoxFit fit;

  const AvatarImage({
    super.key,
    required this.path,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  /// Bumped whenever the avatar is replaced, so mounted widgets reload.
  static final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  /// Notifies listeners whenever the avatar is replaced or evicted.
  static ValueListenable<int> get revision => _revision;

  static String _cacheKey(String path) => 'avatar:$path';

  /// The URL to load for [path]: a full http(s) URL is used as it is (minus any
  /// cache-busting `?t=`), a storage path is turned into its public URL.
  @visibleForTesting
  static String resolveUrl(String path) {
    final p = path.trim();
    if (p.startsWith('http')) {
      final q = p.indexOf('?t=');
      final cut = q >= 0 ? q : p.indexOf('&t=');
      return cut >= 0 ? p.substring(0, cut) : p;
    }
    return AuthService().getAvatarUrl(p);
  }

  /// Removes [path] from both caches.
  ///
  /// `CachedNetworkImage.evictFromCache` clears Flutter's in-memory image cache
  /// with the plain URL, which does not match images stored under a custom
  /// `cacheKey` (the old decoded picture would stay on screen). So the disk
  /// entry and the in-memory entry are removed here with the right key.
  static Future<void> _evictEntry(String path) async {
    final url = resolveUrl(path);
    final key = _cacheKey(path);
    await CachedNetworkImageProvider.defaultCacheManager.removeFile(key);
    await CachedNetworkImageProvider(url, cacheKey: key).evict();
  }

  /// Call after a new picture has been uploaded and saved. Seeds the cache with
  /// [bytes] so the new picture shows instantly (no download), drops the
  /// previous picture [oldPath] from the caches, and tells every mounted
  /// [AvatarImage] to refresh.
  static Future<void> replace(
    String path,
    Uint8List bytes, {
    String extension = 'jpg',
    String? oldPath,
  }) async {
    try {
      if (oldPath != null && oldPath.isNotEmpty && oldPath != path) {
        await _evictEntry(oldPath);
      }
      await _evictEntry(path);
      await CachedNetworkImageProvider.defaultCacheManager.putFile(
        resolveUrl(path),
        bytes,
        key: _cacheKey(path),
        fileExtension: extension.toLowerCase(),
      );
    } catch (e) {
      debugPrint('[AvatarImage] cache replace failed: $e');
    }
    _revision.value++;
  }

  /// Drops the cached picture (e.g. on sign-out).
  static Future<void> evict(String path) async {
    await _evictEntry(path);
    _revision.value++;
  }

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null || p.trim().isEmpty) return fallback;

    final url = resolveUrl(p);
    if (url.isEmpty) return fallback;

    return ValueListenableBuilder<int>(
      valueListenable: _revision,
      builder: (context, rev, _) => CachedNetworkImage(
        key: ValueKey('$p#$rev'),
        imageUrl: url,
        cacheKey: _cacheKey(p),
        fit: fit,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => fallback,
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }
}
