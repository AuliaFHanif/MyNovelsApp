class Series {
  final String id;
  final String title;
  final String? translatedTitle;
  final String author;
  final String sourceLanguage;
  final String? coverImage;
  final String? description;
  final String? translationContext;
  final Map<String, String>? glossary;
  final String status;
  final DateTime created;
  final DateTime updated;

  Series({
    required this.id,
    required this.title,
    this.translatedTitle,
    required this.author,
    required this.sourceLanguage,
    this.coverImage,
    this.description,
    this.translationContext,
    this.glossary,
    required this.status,
    required this.created,
    required this.updated,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    // Handle glossary field - could be Map, String, or null
    Map<String, String>? glossaryMap;
    if (json['glossary'] != null) {
      if (json['glossary'] is Map) {
        glossaryMap = Map<String, String>.from(json['glossary']);
      } else if (json['glossary'] is String) {
        // If it's stored as a string, try to parse it or leave it null
        glossaryMap = null;
      }
    }

    return Series(
      id: json['id'],
      title: json['title'],
      translatedTitle: json['translated_title'],
      author: json['author'],
      sourceLanguage: json['source_language'],
      coverImage: json['cover_image'],
      description: json['description'],
      translationContext: json['translation_context'],
      glossary: glossaryMap,
      status: json['status'] ?? 'ongoing',
      created: DateTime.parse(json['created']),
      updated: DateTime.parse(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'translated_title': translatedTitle,
      'author': author,
      'source_language': sourceLanguage,
      'description': description,
      'translation_context': translationContext,
      'glossary': glossary,
      'status': status,
    };
  }
}
