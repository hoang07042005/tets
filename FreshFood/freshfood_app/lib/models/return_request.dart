class ReturnRequest {
  final int returnRequestId;
  final int orderId;
  final int userId;
  final String status; // Pending | Approved | Rejected
  final String requestType; // Return | CancelRefund
  final String reason;
  final String? adminNote;
  final String? videoUrl;
  final String? refundProofUrl;
  final String? refundNote;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final List<ReturnRequestImage> images;

  const ReturnRequest({
    required this.returnRequestId,
    required this.orderId,
    required this.userId,
    required this.status,
    required this.requestType,
    required this.reason,
    required this.adminNote,
    required this.videoUrl,
    required this.refundProofUrl,
    required this.refundNote,
    required this.createdAt,
    required this.reviewedAt,
    required this.images,
  });

  factory ReturnRequest.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    DateTime? _dt(dynamic v) => (v is String && v.trim().isNotEmpty) ? DateTime.tryParse(v) : null;

    final imgsRaw = json['images'] ?? json['Images'];
    final imgs = <ReturnRequestImage>[];
    if (imgsRaw is List) {
      for (final e in imgsRaw) {
        if (e is Map) imgs.add(ReturnRequestImage.fromJson(Map<String, dynamic>.from(e)));
      }
    }

    return ReturnRequest(
      returnRequestId: _i(json['returnRequestID'] ?? json['ReturnRequestID'] ?? json['id']),
      orderId: _i(json['orderID'] ?? json['OrderID'] ?? json['orderId']),
      userId: _i(json['userID'] ?? json['UserID'] ?? json['userId']),
      status: (json['status'] ?? json['Status'] ?? 'Pending').toString(),
      requestType: (json['requestType'] ?? json['RequestType'] ?? 'Return').toString(),
      reason: (json['reason'] ?? json['Reason'] ?? '').toString(),
      adminNote: (json['adminNote'] ?? json['AdminNote'])?.toString(),
      videoUrl: (json['videoUrl'] ?? json['VideoUrl'])?.toString(),
      refundProofUrl: (json['refundProofUrl'] ?? json['RefundProofUrl'])?.toString(),
      refundNote: (json['refundNote'] ?? json['RefundNote'])?.toString(),
      createdAt: _dt(json['createdAt'] ?? json['CreatedAt']),
      reviewedAt: _dt(json['reviewedAt'] ?? json['ReviewedAt']),
      images: imgs,
    );
  }
}

class ReturnRequestImage {
  final int id;
  final String imageUrl;
  const ReturnRequestImage({required this.id, required this.imageUrl});

  factory ReturnRequestImage.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return ReturnRequestImage(
      id: _i(json['returnRequestImageID'] ?? json['ReturnRequestImageID'] ?? json['id']),
      imageUrl: (json['imageUrl'] ?? json['ImageUrl'] ?? json['imageURL'] ?? json['ImageURL'] ?? '').toString(),
    );
  }
}

