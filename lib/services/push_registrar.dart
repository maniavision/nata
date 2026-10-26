/// Makes sure this phone is registered for the signed-in member's pushes.
///
/// A phone that isn't registered gets nothing while the app is closed, and
/// registering used to happen only on sign-in and could fail quietly (on
/// iOS the APNs token often arrives a few seconds after permission). So
/// [ensure] is called whenever it might be needed (launch, sign-in, a
/// refreshed session, coming back to the app), waits for the APNs token,
/// and does nothing when this member and token are already registered.
/// What failed is tried again next time.
class PushRegistrar {
  /// Asks for permission (the first time); false when refused.
  final Future<bool> Function() requestPermission;

  /// The APNs token on iOS (null until Apple sends it); null on Android.
  final Future<String?> Function()? apnsToken;

  /// The Firebase token pushes are sent to.
  final Future<String?> Function() fcmToken;

  /// Saves the token for the signed-in member.
  final Future<void> Function(String token) save;

  /// Who is signed in (null: nobody).
  final String? Function() userId;

  /// How long to wait for the APNs token, and how often to look.
  final Duration apnsWait;
  final Duration apnsPoll;

  PushRegistrar({
    required this.requestPermission,
    required this.fcmToken,
    required this.save,
    required this.userId,
    this.apnsToken,
    this.apnsWait = const Duration(seconds: 20),
    this.apnsPoll = const Duration(milliseconds: 500),
  });

  /// The member and token last saved.
  ({String user, String token})? _saved;
  Future<bool>? _running;

  /// Registers this phone unless it already is; true when registered.
  Future<bool> ensure() => _running ??= _ensure().whenComplete(() {
    _running = null;
  });

  Future<bool> _ensure() async {
    final user = userId();
    if (user == null) return false;
    try {
      if (!await requestPermission()) return false;
      final apns = apnsToken;
      if (apns != null && !await _waitFor(apns)) return false;
      final token = await fcmToken();
      if (token == null || token.isEmpty) return false;
      // Signed out (or someone else signed in) while this was waiting.
      if (userId() != user) return false;
      final saved = _saved;
      if (saved != null && saved.user == user && saved.token == token) {
        return true;
      }
      await save(token);
      _saved = (user: user, token: token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _waitFor(Future<String?> Function() apns) async {
    final until = DateTime.now().add(apnsWait);
    while (true) {
      if (await apns() != null) return true;
      if (!DateTime.now().isBefore(until)) return false;
      await Future<void>.delayed(apnsPoll);
    }
  }

  /// A new token from Firebase: save it for whoever is signed in.
  Future<void> tokenChanged(String token) async {
    final user = userId();
    if (user == null) return;
    try {
      await save(token);
      _saved = (user: user, token: token);
    } catch (_) {}
  }

  /// Signing out: the next member registers afresh.
  void forget() => _saved = null;
}
