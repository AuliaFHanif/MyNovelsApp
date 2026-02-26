import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pocketbase_service.dart';

class ReaderAuthService extends ChangeNotifier {
  static final ReaderAuthService _instance = ReaderAuthService._internal();
  factory ReaderAuthService() => _instance;
  ReaderAuthService._internal();

  bool _isLoggedIn = false;
  String? _userId;
  String? _username;
  String? _email;

  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get username => _username;
  String? get email => _email;

  final _pb = PocketBaseService();

  // ─── Liked series (stored locally for guests, remotely for users) ───
  Set<String> _likedSeriesIds = {};
  Set<String> get likedSeriesIds => _likedSeriesIds;

  // ─── Continue reading (stored locally) ───
  // Map of seriesId -> {chapterId, chapterNumber, progress}
  final Map<String, Map<String, dynamic>> _readingProgress = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Restore guest liked series
    final liked = prefs.getStringList('liked_series') ?? [];
    _likedSeriesIds = liked.toSet();

    // Restore reading progress
    final progressKeys = prefs.getKeys()
        .where((k) => k.startsWith('progress_'))
        .toList();
    for (final key in progressKeys) {
      final seriesId = key.replaceFirst('progress_', '');
      final data = prefs.getString(key);
      if (data != null) {
        try {
          // Format: chapterId|chapterNumber|chapterTitle
          final parts = data.split('|');
          if (parts.length >= 2) {
            _readingProgress[seriesId] = {
              'chapterId': parts[0],
              'chapterNumber': int.tryParse(parts[1]) ?? 1,
              'chapterTitle': parts.length > 2 ? parts[2] : '',
            };
          }
        } catch (_) {}
      }
    }

    // Try to restore PocketBase session
    if (_pb.pb.authStore.isValid) {
      _isLoggedIn = true;
      _userId = _pb.pb.authStore.model?.id;
      _username = _pb.pb.authStore.model?.data['username'];
      _email = _pb.pb.authStore.model?.data['email'];

      // Load liked series from server
      await _loadLikedSeriesFromServer();
    }

    notifyListeners();
  }

  // ─── Auth ───

  Future<String?> login(String email, String password) async {
    try {
      final auth = await _pb.pb
          .collection('users')
          .authWithPassword(email, password);

      _isLoggedIn = true;
      _userId = auth.record?.id;
      _username = auth.record?.data['username'];
      _email = auth.record?.data['email'];

      await _loadLikedSeriesFromServer();
      notifyListeners();
      return null; // success
    } catch (e) {
      return _parseError(e);
    }
  }

  Future<String?> register(String email, String password, String username) async {
    try {
      await _pb.pb.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'username': username,
      });

      return await login(email, password);
    } catch (e) {
      return _parseError(e);
    }
  }

  Future<void> logout() async {
    // Save liked series locally before logout
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('liked_series', _likedSeriesIds.toList());

    _pb.pb.authStore.clear();
    _isLoggedIn = false;
    _userId = null;
    _username = null;
    _email = null;
    notifyListeners();
  }

  // ─── Liked series ───

  Future<void> _loadLikedSeriesFromServer() async {
    if (!_isLoggedIn || _userId == null) return;
    try {
      final records = await _pb.pb
          .collection('user_liked_series')
          .getFullList(filter: 'user_id = "$_userId"');
      _likedSeriesIds = records.map((r) => r.data['series_id'] as String).toSet();
    } catch (_) {
      // Table might not exist yet — fall back to local
    }
  }

  bool isLiked(String seriesId) => _likedSeriesIds.contains(seriesId);

  Future<void> toggleLike(String seriesId) async {
    final liked = _likedSeriesIds.contains(seriesId);

    if (liked) {
      _likedSeriesIds.remove(seriesId);
    } else {
      _likedSeriesIds.add(seriesId);
    }

    notifyListeners();

    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('liked_series', _likedSeriesIds.toList());

    if (_isLoggedIn && _userId != null) {
      try {
        if (liked) {
          // Remove from server
          final records = await _pb.pb
              .collection('user_liked_series')
              .getFullList(
                filter: 'user_id = "$_userId" && series_id = "$seriesId"',
              );
          for (final r in records) {
            await _pb.pb.collection('user_liked_series').delete(r.id);
          }
        } else {
          // Add to server
          await _pb.pb.collection('user_liked_series').create(body: {
            'user_id': _userId,
            'series_id': seriesId,
          });
        }
      } catch (_) {
        // Silently fail — local state already updated
      }
    }
  }

  // ─── Reading progress ───

  Future<void> saveProgress(
    String seriesId,
    String chapterId,
    int chapterNumber,
    String chapterTitle,
  ) async {
    _readingProgress[seriesId] = {
      'chapterId': chapterId,
      'chapterNumber': chapterNumber,
      'chapterTitle': chapterTitle,
    };
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'progress_$seriesId',
      '$chapterId|$chapterNumber|$chapterTitle',
    );
  }

  Map<String, dynamic>? getProgress(String seriesId) =>
      _readingProgress[seriesId];

  // ─── Helpers ───

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('400')) return 'Invalid email or password.';
    if (msg.contains('email')) return 'Invalid email address.';
    if (msg.contains('network') || msg.contains('SocketException')) {
      return 'Cannot reach server. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}