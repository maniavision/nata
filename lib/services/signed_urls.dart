/// Short-lived links to photos in private buckets (item photos, tickets,
/// chat and delivery photos), kept until shortly before they expire.
///
/// Every screen used to ask the server for a new link on each visit, and
/// each new link (a different token) made the photo download again. Reusing
/// the link saves that round trip; [imageKey] lets the photo itself be kept
/// on disk under its storage path, whatever the token.
///
/// Links belong to the session: signing out clears them.
class SignedUrls {
  SignedUrls._();

  static final Map<String, ({String url, DateTime expires})> _links = {};
  static final Map<String, Future<String>> _pending = {};

  /// A link is replaced this long before it expires, so a photo never
  /// starts loading from a link that dies on the way.
  static const margin = Duration(minutes: 2);

  /// Replaced in tests.
  static DateTime Function() now = DateTime.now;

  static String _key(String bucket, String path) => '$bucket/$path';

  /// The link to [path] in [bucket]: the one kept, or a new one from
  /// [create] (valid for [lifetime]). Asking again while it is being made
  /// waits for the same one.
  static Future<String> get(
    String bucket,
    String path, {
    required Duration lifetime,
    required Future<String> Function() create,
  }) {
    final key = _key(bucket, path);
    final kept = _links[key];
    if (kept != null && kept.expires.isAfter(now().add(margin))) {
      return Future.value(kept.url);
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    final made = now();
    final future = create()
        .then((url) {
          _links[key] = (url: url, expires: made.add(lifetime));
          return url;
        })
        // A block, not `=>`: returning the removed future would make this
        // wait for itself.
        .whenComplete(() {
          _pending.remove(key);
        });
    _pending[key] = future;
    return future;
  }

  /// Forgets the link to [path] (its photo was just replaced).
  static void forget(String bucket, String path) =>
      _links.remove(_key(bucket, path));

  /// Forgets every link (signing out).
  static void clear() {
    _links.clear();
    _pending.clear();
  }

  /// What a photo at a signed [url] is kept under: the link without its
  /// token, which stays the same from one link to the next.
  static String imageKey(String url) {
    final q = url.indexOf('?');
    return 'storage:${q < 0 ? url : url.substring(0, q)}';
  }
}
