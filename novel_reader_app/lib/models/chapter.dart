class Chapter {
  final String id;
  final String seriesId;
  final int chapterNumber;
  final String? chapterTitle;
  final String sourceText;
  final List<String>? images;
  final String translationStatus;
  final String status;
  final int? wordCount;
  final DateTime created;
  final DateTime updated;

  Chapter({
    required this.id,
    required this.seriesId,
    required this.chapterNumber,
    this.chapterTitle,
    required this.sourceText,
    this.images,
    required this.translationStatus,
    required this.status,
    this.wordCount,
    required this.created,
    required this.updated,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    // Debug: Print what we're getting
    print('Parsing chapter - images field: ${json['images']}');

    // Handle images field - could be List, String, or null
    List<String>? imagesList;
    if (json['images'] != null) {
      if (json['images'] is List) {
        imagesList = (json['images'] as List)
            .where((item) => item != null && item.toString().isNotEmpty)
            .map((item) => item.toString())
            .toList();
        print('Parsed ${imagesList.length} images');
      } else if (json['images'] is String) {
        final imgStr = json['images'] as String;
        imagesList = imgStr.isEmpty ? null : [imgStr];
      }
    }

    return Chapter(
      id: json['id'],
      seriesId: json['series_id'],
      chapterNumber: json['chapter_number'],
      chapterTitle: json['chapter_title'],
      sourceText: json['source_text'],
      images: imagesList,
      translationStatus: json['translation_status'] ?? 'pending',
      status: json['status'] ?? 'ongoing',
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
      'images': images,
      'translation_status': translationStatus,
      'status': status,
      'word_count': wordCount,
    };
  }
}
