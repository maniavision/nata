import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../services/signed_urls.dart';

/// A photo from a private bucket, by its signed link: kept in memory and on
/// disk under its storage path, so it shows at once on the next visit (and
/// after the app restarts) instead of downloading again.
///
/// Also for public images whose link never changes (the sign-in pictures).
///
/// Only for photos whose path is never reused for a different picture (item
/// photos, tickets, chat photos). Delivery photos are retaken at the same
/// path, so they load by their link.
class StoragePhoto {
  StoragePhoto._();

  /// Off in tests, which have no disk.
  static bool diskCache = true;

  static ImageProvider provider(String url) => diskCache
      ? CachedNetworkImageProvider(url, cacheKey: SignedUrls.imageKey(url))
      : NetworkImage(url);
}
