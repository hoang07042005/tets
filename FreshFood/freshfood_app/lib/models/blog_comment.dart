class BlogComment {
  final int id;
  final int blogPostId;
  final int userId;
  final int? parentCommentId;
  final String userName;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;

  const BlogComment({
    required this.id,
    required this.blogPostId,
    required this.userId,
    required this.parentCommentId,
    required this.userName,
    required this.avatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory BlogComment.fromJson(Map<String, dynamic> json) {
    final idRaw = json['blogCommentID'] ?? json['BlogCommentID'] ?? 0;
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;
    final postRaw = json['blogPostID'] ?? json['BlogPostID'] ?? 0;
    final blogPostId = postRaw is num ? postRaw.toInt() : int.tryParse('$postRaw') ?? 0;
    final userRaw = json['userID'] ?? json['UserID'] ?? 0;
    final userId = userRaw is num ? userRaw.toInt() : int.tryParse('$userRaw') ?? 0;
    final parentRaw = json['parentCommentID'] ?? json['ParentCommentID'];
    final parentCommentId = parentRaw == null ? null : (parentRaw is num ? parentRaw.toInt() : int.tryParse('$parentRaw'));
    final userName = (json['userName'] ?? json['UserName'] ?? '').toString();
    final avatarUrl = json['avatarUrl'] ?? json['AvatarUrl'];
    final content = (json['content'] ?? json['Content'] ?? '').toString();
    final createdRaw = (json['createdAt'] ?? json['CreatedAt'] ?? '').toString();
    DateTime createdAt;
    final s = createdRaw.trim();
    if (s.isEmpty) {
      createdAt = DateTime.now().toUtc();
    } else {
      // Backend often returns UTC timestamps without timezone suffix.
      // Treat timezone-less ISO strings as UTC to avoid "time ago" drift.
      final hasTz = RegExp(r'([zZ]|[+-]\d{2}:?\d{2})$').hasMatch(s);
      createdAt = DateTime.tryParse(hasTz ? s : '${s}Z') ?? DateTime.now().toUtc();
      if (!createdAt.isUtc) createdAt = createdAt.toUtc();
    }
    return BlogComment(
      id: id,
      blogPostId: blogPostId,
      userId: userId,
      parentCommentId: parentCommentId,
      userName: userName,
      avatarUrl: avatarUrl?.toString(),
      content: content,
      createdAt: createdAt,
    );
  }
}

