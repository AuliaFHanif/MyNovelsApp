class Chapter {
  final String id;
  final String seriesId;
  final int chapterNumber;
  final String? chapterTitle;
  final String sourceText;
  final String translationStatus;
  final int? wordCount;
  final DateTime created;
  final DateTime updated;

  Chapter({
    required this.id,
    required this.seriesId,
    required this.chapterNumber,
    this.chapterTitle,
    required this.sourceText,
    required this.translationStatus,
    this.wordCount,
    required this.created,
    required this.updated,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'],
      seriesId: json['series_id'],
      chapterNumber: json['chapter_number'],
      chapterTitle: json['chapter_title'],
      sourceText: json['source_text'],
      translationStatus: json['translation_status'] ?? 'pending',
      wordCount: json['word_count'],
      created: DateTime.parse(json['created']),
      updated: DateTime.parse(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'series_id': seriesId,
      'chapter_number': chapterNumber,
      'chapter_title': chapterTitle,
      'source_text': sourceText,
      'translation_status': translationStatus,
      'word_count': wordCount,
    };
  }
}
