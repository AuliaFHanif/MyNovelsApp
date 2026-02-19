import 'package:flutter/foundation.dart';
import '../models/monitored_source.dart';
import '../models/feed_notification.dart';
import '../services/pocketbase_service.dart';

class FeedViewModel extends ChangeNotifier {
  final PocketBaseService _pb = PocketBaseService();

  List<FeedNotification> _notifications = [];
  List<MonitoredSource> _monitoredSources = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<FeedNotification> get notifications => _notifications;
  List<MonitoredSource> get monitoredSources => _monitoredSources;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get unread notification count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Fetch all notifications for the user
  Future<void> fetchNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final records = await _pb.pb
          .collection('feed_notifications')
          .getFullList(sort: '-created');

      _notifications = records
          .map((record) => FeedNotification.fromJson(record.toJson()))
          .toList();
    } catch (e) {
      _errorMessage = 'Failed to load notifications: $e';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch all monitored sources
  Future<void> fetchMonitoredSources() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final records = await _pb.pb
          .collection('monitored_sources')
          .getFullList(sort: '-created');

      _monitoredSources = records
          .map((record) => MonitoredSource.fromJson(record.toJson()))
          .toList();
    } catch (e) {
      _errorMessage = 'Failed to load monitored sources: $e';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to an artist for a series
  /// [seriesId]: The series to monitor
  /// [artistName]: Name of the artist (for display)
  /// [sourceUrl]: DeviantArt artist URL (e.g., https://www.deviantart.com/artistname)
  Future<bool> subscribeToArtist(
    String seriesId,
    String artistName,
    String sourceUrl,
  ) async {
    try {
      // Validate URL format
      if (!_isValidDeviantArtUrl(sourceUrl)) {
        _errorMessage =
            'Invalid DeviantArt URL. Expected format: https://www.deviantart.com/[username]';
        notifyListeners();
        return false;
      }

      // Derive RSS URL from source URL
      final rssUrl = _deriveRssUrl(sourceUrl);

      await _pb.pb.collection('monitored_sources').create(body: {
        'series_id': seriesId,
        'artist_name': artistName,
        'source_url': sourceUrl,
        'source_type': 'deviantart',
        'rss_url': rssUrl,
        'is_active': true,
      });

      await fetchMonitoredSources(); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = 'Failed to subscribe to artist: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// Unsubscribe from an artist
  Future<bool> unsubscribeFromArtist(String monitoredSourceId) async {
    try {
      await _pb.pb.collection('monitored_sources').delete(monitoredSourceId);

      // Also delete associated notifications
      try {
        final notificationsToDelete = await _pb.pb
            .collection('feed_notifications')
            .getFullList(
              filter: 'monitored_source_id = "$monitoredSourceId"',
            );

        for (final notification in notificationsToDelete) {
          await _pb.pb
              .collection('feed_notifications')
              .delete(notification.id);
        }
      } catch (e) {
        print('Error deleting notifications: $e');
        // Continue even if notification deletion fails
      }

      await fetchMonitoredSources(); // Refresh the list
      await fetchNotifications(); // Refresh notifications
      return true;
    } catch (e) {
      _errorMessage = 'Failed to unsubscribe from artist: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _pb.pb.collection('feed_notifications').update(
            notificationId,
            body: {'is_read': true},
          );

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = FeedNotification(
          id: _notifications[index].id,
          monitoredSourceId: _notifications[index].monitoredSourceId,
          seriesId: _notifications[index].seriesId,
          artistName: _notifications[index].artistName,
          seriesTitle: _notifications[index].seriesTitle,
          chapterTitle: _notifications[index].chapterTitle,
          chapterNumber: _notifications[index].chapterNumber,
          postUrl: _notifications[index].postUrl,
          thumbnailUrl: _notifications[index].thumbnailUrl,
          isRead: true,
          created: _notifications[index].created,
          updated: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to mark notification as read: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _pb.pb.collection('feed_notifications').delete(notificationId);

      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete notification: $e';
      print(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Helper functions
  bool _isValidDeviantArtUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.contains('deviantart.com') &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  String _deriveRssUrl(String sourceUrl) {
    try {
      final uri = Uri.parse(sourceUrl);
      final username = uri.pathSegments.first;
      return 'https://www.deviantart.com/$username/rss';
    } catch (e) {
      return sourceUrl; // Fallback
    }
  }

  /// Set up real-time subscription to feed notifications
  void subscribeToFeedUpdates(Function(FeedNotification) onNewNotification) {
    _pb.pb
        .collection('feed_notifications')
        .subscribe('*', (e) {
      if (e.action == 'create') {
        final notification =
            FeedNotification.fromJson(e.record.toJson());
        _notifications.insert(0, notification);
        notifyListeners();
        onNewNotification(notification);
      }
    });
  }
}