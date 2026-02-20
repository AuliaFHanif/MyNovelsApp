class FeedNotification {
  final String id;
  final String monitoredSourceId;
  final String seriesId;
  final String artistName;
  final String seriesTitle;
  final String? chapterTitle;
  final String? chapterNumber;
  final String postUrl; // Direct link to the DeviantArt post
  final String? thumbnailUrl;
  final bool isRead;
  final DateTime created;
  final DateTime updated;

  FeedNotification({
    required this.id,
    required this.monitoredSourceId,
    required this.seriesId,
    required this.artistName,
    required this.seriesTitle,
    this.chapterTitle,
    this.chapterNumber,
    required this.postUrl,
    this.thumbnailUrl,
    required this.isRead,
    required this.created,
    required this.updated,
  });

  factory FeedNotification.fromJson(Map<String, dynamic> json) {
    return FeedNotification(
      id: json['id'],
      monitoredSourceId: json['monitored_source_id'],
      seriesId: json['series_id'],
      artistName: json['artist_name'],
      seriesTitle: json['series_title'],
      chapterTitle: json['chapter_title'],
      chapterNumber: json['chapter_number'],
      postUrl: json['post_url'],
      thumbnailUrl: json['thumbnail_url'],
      isRead: json['is_read'] ?? false,
      created: DateTime.parse(json['created']),
      updated: DateTime.parse(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monitored_source_id': monitoredSourceId,
      'series_id': seriesId,
      'artist_name': artistName,
      'series_title': seriesTitle,
      'chapter_title': chapterTitle,
      'chapter_number': chapterNumber,
      'post_url': postUrl,
      'thumbnail_url': thumbnailUrl,
      'is_read': isRead,
    };
  }
}