class Series {
  final String id;
  final String title;
  final String author;
  final String sourceLanguage;
  final String? coverImage;
  final String? description;
  final DateTime created;
  final DateTime updated;

  Series({
    required this.id,
    required this.title,
    required this.author,
    required this.sourceLanguage,
    this.coverImage,
    this.description,
    required this.created,
    required this.updated,
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      sourceLanguage: json['source_language'],
      coverImage: json['cover_image'],
      description: json['description'],
      created: DateTime.parse(json['created']),
      updated: DateTime.parse(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'author': author,
      'source_language': sourceLanguage,
      'description': description,
    };
  }
}
