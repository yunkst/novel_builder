class Novel {
  final String title;
  final String author;
  final String url;
  final bool isInBookshelf;
  final String? coverUrl;
  final String? description;
  final String? backgroundSetting;
  final int? lastReadChapterIndex;
  final double? readingProgress;

  Novel({
    required this.title,
    required this.author,
    required this.url,
    this.isInBookshelf = false,
    this.coverUrl,
    this.description,
    this.backgroundSetting,
    this.lastReadChapterIndex,
    this.readingProgress,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      'url': url,
      'isInBookshelf': isInBookshelf ? 1 : 0,
      'coverUrl': coverUrl,
      'description': description,
      'backgroundSetting': backgroundSetting,
    };
  }

  factory Novel.fromMap(Map<String, dynamic> map) {
    return Novel(
      title: map['title'] as String,
      author: map['author'] as String,
      url: map['url'] as String,
      isInBookshelf: (map['isInBookshelf'] as int) == 1,
      coverUrl: map['coverUrl'] as String?,
      description: map['description'] as String?,
      backgroundSetting: map['backgroundSetting'] as String?,
    );
  }

  Novel copyWith({
    String? title,
    String? author,
    String? url,
    bool? isInBookshelf,
    String? coverUrl,
    String? description,
    String? backgroundSetting,
  }) {
    return Novel(
      title: title ?? this.title,
      author: author ?? this.author,
      url: url ?? this.url,
      isInBookshelf: isInBookshelf ?? this.isInBookshelf,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      backgroundSetting: backgroundSetting ?? this.backgroundSetting,
    );
  }
}
