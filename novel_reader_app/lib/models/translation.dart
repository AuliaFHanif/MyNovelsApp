class Translation {
  final String id;
  final String chapterId;
  final String translatedText;
  final String? modelUsed;
  final int? translationTime;
  final int? qualityRating;
  final int? chunkCount;
  final DateTime created;
  final DateTime updated;

  Translation({
    required this.id,
    required this.chapterId,
    required this.translatedText,
    this.modelUsed,
    this.translationTime,
    this.qualityRating,
    this.chunkCount,
    required this.created,
    required this.updated,
  });

  factory Translation.fromJson(Map<String, dynamic> json) {
    return Translation(
      id: json['id'],
      chapterId: json['chapter_id'],
      translatedText: json['translated_text'],
      modelUsed: json['model_used'],
      translationTime: json['translation_time'],
      qualityRating: json['quality_rating'],
      chunkCount: json['chunk_count'],
      created: DateTime.parse(json['created']),
      updated: DateTime.parse(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chapter_id': chapterId,
      'translated_text': translatedText,
      'model_used': modelUsed,
      'translation_time': translationTime,
      'quality_rating': qualityRating,
      'chunk_count': chunkCount,
    };
  }
}
