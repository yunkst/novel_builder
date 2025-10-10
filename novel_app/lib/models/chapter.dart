class Chapter {
  final String title;
  final String url;
  final String? content;
  final bool isCached;
  final int? chapterIndex;
  final bool isUserInserted;

  Chapter({
    required this.title,
    required this.url,
    this.content,
    this.isCached = false,
    this.chapterIndex,
    this.isUserInserted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'content': content,
      'isCached': isCached ? 1 : 0,
      'chapterIndex': chapterIndex,
      'isUserInserted': isUserInserted ? 1 : 0,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      title: map['title'] as String,
      url: map['url'] as String,
      content: map['content'] as String?,
      isCached: (map['isCached'] as int) == 1,
      chapterIndex: map['chapterIndex'] as int?,
      isUserInserted: (map['isUserInserted'] as int?) == 1,
    );
  }

  Chapter copyWith({
    String? title,
    String? url,
    String? content,
    bool? isCached,
    int? chapterIndex,
    bool? isUserInserted,
  }) {
    return Chapter(
      title: title ?? this.title,
      url: url ?? this.url,
      content: content ?? this.content,
      isCached: isCached ?? this.isCached,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      isUserInserted: isUserInserted ?? this.isUserInserted,
    );
  }
}
