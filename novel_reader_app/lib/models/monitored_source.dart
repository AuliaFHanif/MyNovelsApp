class MonitoredSource {
  final String id;
  final String seriesId;
  final String artistName;
  final String sourceUrl; // DeviantArt artist URL
  final String sourceType; // 'deviantart' for now
  final String? rssUrl; // Derived from sourceUrl
  final bool isActive;
  final DateTime? lastChecked;
  final String? lastFoundUrl; // URL of last found chapter
  final DateTime created;
  final DateTime updated;

  MonitoredSource({
    required this.id,
    required this.seriesId,
    required this.artistName,
    required this.sourceUrl,
    required this.sourceType,
    this.rssUrl,
    required this.isActive,
    this.lastChecked,
    this.lastFoundUrl,
    required this.created,
    required this.updated,
  });

  factory MonitoredSource.fromJson(Map<String, dynamic> json) {
    return MonitoredSource(
      id: json['id'],
      seriesId: json['series_id'],
      artistName: json['artist_name'],
      sourceUrl: json['source_url'],
      sourceType: json['source_type'] ?? 'deviantart',
      rssUrl: json['rss_url'],
      isActive: json['is_active'] ?? true,
      lastChecked: json['last_checked'] != null
          ? DateTime.parse(json['last_checked'])
          : null,
      lastFoundUrl: json['last_found_url'],
      created: DateTime.parse(json['created']),
      updated: DateTime.parse(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'series_id': seriesId,
      'artist_name': artistName,
      'source_url': sourceUrl,
      'source_type': sourceType,
      'rss_url': rssUrl,
      'is_active': isActive,
      'last_checked': lastChecked?.toIso8601String(),
      'last_found_url': lastFoundUrl,
    };
  }
}