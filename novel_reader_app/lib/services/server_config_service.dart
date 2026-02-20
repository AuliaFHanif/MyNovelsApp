import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketbase/pocketbase.dart';

/// Manages the PocketBase server URL, persisted across sessions.
/// Call [init] once at startup before using [url] or [pb].
class ServerConfigService extends ChangeNotifier {
  static final ServerConfigService _instance = ServerConfigService._internal();
  factory ServerConfigService() => _instance;
  ServerConfigService._internal();

  static const _kUrlKey = 'reader_server_url';
  static const _kDefaultUrl = 'http://127.0.0.1:8090';

  String _url = _kDefaultUrl;
  late PocketBase _pb;
  bool _initialized = false;

  String get url => _url;
  PocketBase get pb => _pb;
  bool get isDefaultUrl => _url == _kDefaultUrl;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _url = prefs.getString(_kUrlKey) ?? _kDefaultUrl;
    _pb = PocketBase(_url);
    _initialized = true;
  }

  /// Update the URL, persist it, and rebuild the PocketBase client.
  /// Returns an error string if the URL is invalid or unreachable,
  /// or null on success.
  Future<String?> setUrl(String raw) async {
    final trimmed = raw.trim().replaceAll(
      RegExp(r'/$'),
      '',
    ); // strip trailing /

    // Basic validation
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Invalid URL. Use format: http://100.x.x.x:8090';
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }

    // Test the connection before saving
    try {
      final testPb = PocketBase(trimmed);
      await testPb.health.check().timeout(const Duration(seconds: 6));
    } catch (_) {
      return 'Could not reach server at $trimmed.\nMake sure PocketBase is running and the URL is correct.';
    }

    // Save
    _url = trimmed;
    _pb = PocketBase(_url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUrlKey, _url);
    notifyListeners();
    return null; // success
  }

  Future<void> resetToDefault() async {
    _url = _kDefaultUrl;
    _pb = PocketBase(_url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUrlKey);
    notifyListeners();
  }

  /// Quick connectivity check against the current URL.
  Future<bool> testConnection() async {
    try {
      await _pb.health.check().timeout(const Duration(seconds: 6));
      return true;
    } catch (_) {
      return false;
    }
  }
}
