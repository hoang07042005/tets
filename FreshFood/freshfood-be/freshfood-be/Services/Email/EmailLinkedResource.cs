namespace freshfood_be.Services.Email;

/// <summary>Ảnh nhúng (multipart/related) cho HTML email — dùng src="cid:ContentId".</summary>
public sealed record EmailLinkedResource(byte[] Content, string FileName, string ContentId, string ContentType);
