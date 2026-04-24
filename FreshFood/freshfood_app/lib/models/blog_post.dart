class BlogPostListItem {
  final int id;
  final String title;
  final String slug;
  final String? excerpt;
  final String? coverImageUrl;
  final DateTime? publishedAt;
  final int viewCount;

  const BlogPostListItem({
    required this.id,
    required this.title,
    required this.slug,
    required this.excerpt,
    required this.coverImageUrl,
    required this.publishedAt,
    required this.viewCount,
  });

  factory BlogPostListItem.fromJson(Map<String, dynamic> json) {
    final idRaw = json['blogPostID'] ?? json['BlogPostID'] ?? 0;
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    final title = (json['title'] ?? json['Title'] ?? '').toString();
    final slug = (json['slug'] ?? json['Slug'] ?? '').toString();
    final excerpt = json['excerpt'] ?? json['Excerpt'];
    final cover = json['coverImageUrl'] ?? json['CoverImageUrl'];
    final publishedRaw = json['publishedAt'] ?? json['PublishedAt'];
    DateTime? publishedAt;
    if (publishedRaw is String && publishedRaw.trim().isNotEmpty) publishedAt = DateTime.tryParse(publishedRaw);
    final viewsRaw = json['viewCount'] ?? json['ViewCount'] ?? 0;
    final viewCount = viewsRaw is num ? viewsRaw.toInt() : int.tryParse('$viewsRaw') ?? 0;
    return BlogPostListItem(
      id: id,
      title: title,
      slug: slug,
      excerpt: excerpt?.toString(),
      coverImageUrl: cover?.toString(),
      publishedAt: publishedAt,
      viewCount: viewCount,
    );
  }
}

class BlogPostDetail {
  final int id;
  final String title;
  final String slug;
  final String? excerpt;
  final String content;
  final String? coverImageUrl;
  final DateTime? publishedAt;
  final int viewCount;

  const BlogPostDetail({
    required this.id,
    required this.title,
    required this.slug,
    required this.excerpt,
    required this.content,
    required this.coverImageUrl,
    required this.publishedAt,
    required this.viewCount,
  });

  factory BlogPostDetail.fromJson(Map<String, dynamic> json) {
    final idRaw = json['blogPostID'] ?? json['BlogPostID'] ?? 0;
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    final title = (json['title'] ?? json['Title'] ?? '').toString();
    final slug = (json['slug'] ?? json['Slug'] ?? '').toString();
    final excerpt = json['excerpt'] ?? json['Excerpt'];
    final content = (json['content'] ?? json['Content'] ?? '').toString();
    final cover = json['coverImageUrl'] ?? json['CoverImageUrl'];
    final publishedRaw = json['publishedAt'] ?? json['PublishedAt'];
    DateTime? publishedAt;
    if (publishedRaw is String && publishedRaw.trim().isNotEmpty) publishedAt = DateTime.tryParse(publishedRaw);
    final viewsRaw = json['viewCount'] ?? json['ViewCount'] ?? 0;
    final viewCount = viewsRaw is num ? viewsRaw.toInt() : int.tryParse('$viewsRaw') ?? 0;
    return BlogPostDetail(
      id: id,
      title: title,
      slug: slug,
      excerpt: excerpt?.toString(),
      content: content,
      coverImageUrl: cover?.toString(),
      publishedAt: publishedAt,
      viewCount: viewCount,
    );
  }
}

