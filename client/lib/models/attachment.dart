import 'json.dart';

/// A file attached to a school work or note.
class Attachment {
  const Attachment({
    required this.id,
    required this.resourceType,
    required this.resourceId,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    this.createdAt,
  });

  final int id;
  final String resourceType;
  final int resourceId;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final DateTime? createdAt;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  String get extension {
    final dot = originalName.lastIndexOf('.');
    if (dot < 0 || dot == originalName.length - 1) return '';
    return originalName.substring(dot + 1).toLowerCase();
  }

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: asInt(json['id']) ?? 0,
        resourceType: json['resourceType'] as String? ?? '',
        resourceId: asInt(json['resourceId']) ?? 0,
        originalName: json['originalName'] as String? ?? 'attachment',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        sizeBytes: asInt(json['sizeBytes']) ?? 0,
        createdAt: asLocalDate(json['createdAt']),
      );
}
