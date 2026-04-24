class RecentReview {
  final int reviewId;
  final String? userName;
  final String? avatarUrl;
  final int rating;
  final String? comment;
  final DateTime? reviewDate;

  const RecentReview({
    required this.reviewId,
    required this.rating,
    this.userName,
    this.avatarUrl,
    this.comment,
    this.reviewDate,
  });

  factory RecentReview.fromJson(Map<String, dynamic> json) {
    final idRaw = json['reviewID'] ?? json['ReviewID'] ?? 0;
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? 0;

    final ratingRaw = json['rating'] ?? json['Rating'] ?? 0;
    final rating = ratingRaw is num ? ratingRaw.toInt() : int.tryParse('$ratingRaw') ?? 0;

    final userRaw = json['userName'] ?? json['UserName'];
    final userName = userRaw == null ? null : (userRaw is String ? userRaw : '$userRaw');

    final avatarRaw = json['avatarUrl'] ?? json['AvatarUrl'] ?? json['avatarURL'] ?? json['AvatarURL'];
    final avatarUrl = avatarRaw == null ? null : (avatarRaw is String ? avatarRaw : '$avatarRaw');

    final commentRaw = json['comment'] ?? json['Comment'];
    final comment = commentRaw == null ? null : (commentRaw is String ? commentRaw : '$commentRaw');

    final dateRaw = json['reviewDate'] ?? json['ReviewDate'];
    DateTime? reviewDate;
    if (dateRaw is String && dateRaw.trim().isNotEmpty) {
      reviewDate = DateTime.tryParse(dateRaw);
    }

    return RecentReview(
      reviewId: id,
      rating: rating,
      userName: userName,
      avatarUrl: avatarUrl,
      comment: comment,
      reviewDate: reviewDate,
    );
  }
}

class ReviewSummary {
  final double averageRating;
  final int totalReviews;

  const ReviewSummary({required this.averageRating, required this.totalReviews});

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final avgRaw = json['averageRating'] ?? json['AverageRating'] ?? 0;
    final averageRating = avgRaw is num ? avgRaw.toDouble() : double.tryParse('$avgRaw') ?? 0.0;

    final totalRaw = json['totalReviews'] ?? json['TotalReviews'] ?? 0;
    final totalReviews = totalRaw is num ? totalRaw.toInt() : int.tryParse('$totalRaw') ?? 0;

    return ReviewSummary(averageRating: averageRating, totalReviews: totalReviews);
  }
}

