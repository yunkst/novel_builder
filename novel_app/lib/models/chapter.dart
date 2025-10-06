class Chapter {
  final String title;
  final String url;
  final String? content;
  final bool isCached;
  final int? chapterIndex;

  Chapter({
    required this.title,
    required this.url,
    this.content,
    this.isCached = false,
    this.chapterIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'content': content,
      'isCached': isCached ? 1 : 0,
      'chapterIndex': chapterIndex,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      title: map['title'] as String,
      url: map['url'] as String,
      content: map['content'] as String?,
      isCached: (map['isCached'] as int) == 1,
      chapterIndex: map['chapterIndex'] as int?,
    );
  }

  Chapter copyWith({
    String? title,
    String? url,
    String? content,
    bool? isCached,
    int? chapterIndex,
  }) {
    return Chapter(
      title: title ?? this.title,
      url: url ?? this.url,
      content: content ?? this.content,
      isCached: isCached ?? this.isCached,
      chapterIndex: chapterIndex ?? this.chapterIndex,
    );
  }
}
