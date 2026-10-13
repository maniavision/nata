import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A version number such as "1.2.3" (a "+build" or "-beta" suffix is ignored).
/// Missing parts count as 0, so "1.2" equals "1.2.0".
class AppVersion implements Comparable<AppVersion> {
  final List<int> parts;
  const AppVersion._(this.parts);

  /// Null when [text] is not a version number.
  static AppVersion? tryParse(String? text) {
    if (text == null) return null;
    final core = text.trim().split(RegExp(r'[+\-]')).first;
    if (!RegExp(r'^\d+(\.\d+){0,2}$').hasMatch(core)) return null;
    final parts = core.split('.').map(int.parse).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return AppVersion._(parts);
  }

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < 3; i++) {
      final c = parts[i].compareTo(other.parts[i]);
      if (c != 0) return c;
    }
    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hashAll(parts);

  @override
  String toString() => parts.join('.');
}

/// A newer version of the app than the one running.
class AppUpdate {
  /// The newest version, as published (e.g. "1.1.0").
  final String latest;

  /// The version running now.
  final String current;

  /// True when the running version is older than the oldest one still allowed:
  /// the update cannot be postponed.
  final bool mandatory;

  /// Where to get it; null when nothing is known (then there is no button).
  final String? storeUrl;

  /// What is new (may be empty).
  final String notes;

  const AppUpdate({
    required this.latest,
    required this.current,
    required this.mandatory,
    required this.storeUrl,
    this.notes = '',
  });
}

/// Which version is running, and its package name.
typedef AppInfo = ({String version, String packageName});

Future<AppInfo> _readPackageInfo() async {
  final info = await PackageInfo.fromPlatform();
  return (version: info.version, packageName: info.packageName);
}

/// Finds out whether a newer version of the app has been published.
///
/// Needs `supabase/migrations/20240120_app_versions.sql`.
class AppUpdateService {
  final SupabaseClient? _clientOverride;
  final Future<AppInfo> Function() _appInfo;
  final TargetPlatform _platform;
  final DateTime Function() _now;

  AppUpdateService({
    SupabaseClient? client,
    Future<AppInfo> Function()? appInfo,
    TargetPlatform? platform,
    DateTime Function()? now,
  }) : _clientOverride = client,
       _appInfo = appInfo ?? _readPackageInfo,
       _platform = platform ?? defaultTargetPlatform,
       _now = now ?? DateTime.now;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  static const _dismissedKey = 'update_dismissed';

  /// After "Later", the same version is not offered again for this long.
  static const remindAfter = Duration(hours: 24);

  /// 'ios' or 'android'; null elsewhere (nothing to update from a store).
  String? get platformName {
    switch (_platform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return null;
    }
  }

  /// The update to offer, or null when the app is up to date, the platform has
  /// no store, or it could not be found out (offline, no row...). A failed
  /// check never gets in the user's way.
  Future<AppUpdate?> check() async {
    final platform = platformName;
    if (platform == null) return null;
    try {
      final info = await _appInfo();
      final current = AppVersion.tryParse(info.version);
      if (current == null) return null;

      final raw = await _client.rpc(
        'get_app_version',
        params: {'p_platform': platform},
      );
      final row = _firstRow(raw);
      if (row == null) return null;

      final latest = AppVersion.tryParse(row['latest_version'] as String?);
      if (latest == null) return null;
      final minSupported = AppVersion.tryParse(
        row['min_supported_version'] as String?,
      );

      final mandatory = minSupported != null && current < minSupported;
      // Anything older than the minimum is also older than "latest" in
      // practice; if the data says otherwise, the minimum still wins.
      if (!mandatory && !(current < latest)) return null;

      final shown = (mandatory && minSupported > latest)
          ? minSupported
          : latest;
      return AppUpdate(
        latest: shown.toString(),
        current: current.toString(),
        mandatory: mandatory,
        storeUrl: _storeUrl(row['store_url'] as String?, platform, info),
        notes: ((row['release_notes'] as String?) ?? '').trim(),
      );
    } catch (e) {
      debugPrint('[AppUpdateService] check failed: $e');
      return null;
    }
  }

  static Map<String, dynamic>? _firstRow(dynamic raw) {
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static String? _storeUrl(String? fromDb, String platform, AppInfo info) {
    final url = fromDb?.trim() ?? '';
    if (url.startsWith('https://')) return url;
    if (platform == 'android' && info.packageName.isNotEmpty) {
      return 'https://play.google.com/store/apps/details?id=${info.packageName}';
    }
    return null;
  }

  // ── "Later" ────────────────────────────────────────────────────────────────

  /// Whether to show [update] now. A compulsory update is always shown; an
  /// optional one is not shown again for [remindAfter] once the user chose
  /// "Later" for that version (a newer version is shown right away).
  Future<bool> shouldPrompt(AppUpdate update) async {
    if (update.mandatory) return true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_dismissedKey);
    if (saved == null) return true;
    final bar = saved.indexOf('|');
    if (bar < 0) return true;
    if (saved.substring(0, bar) != update.latest) return true;
    final at = int.tryParse(saved.substring(bar + 1));
    if (at == null) return true;
    final since = _now().difference(DateTime.fromMillisecondsSinceEpoch(at));
    return since >= remindAfter;
  }

  /// The user chose "Later" for [update].
  Future<void> postpone(AppUpdate update) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _dismissedKey,
      '${update.latest}|${_now().millisecondsSinceEpoch}',
    );
  }
}
