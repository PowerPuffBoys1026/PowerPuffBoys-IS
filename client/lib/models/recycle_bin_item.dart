import 'json.dart';

/// An item sitting in the recycle bin (`GET /recycle_bin`).
class RecycleBinItem {
  const RecycleBinItem({
    required this.id,
    required this.type,
    required this.label,
    this.deletedAt,
    this.expiresAt,
  });

  final int id;
  final String type;
  final String label;
  final DateTime? deletedAt;
  final DateTime? expiresAt;

  factory RecycleBinItem.fromJson(Map<String, dynamic> json) => RecycleBinItem(
    id: asInt(json['id']) ?? 0,
    type: json['type'] as String? ?? 'item',
    label: json['label'] as String? ?? 'Untitled',
    deletedAt: asLocalDate(json['deletedAt']),
    expiresAt: asLocalDate(json['expiresAt']),
  );
}

/// Result of `POST /recycle_bin/:id/restore`.
class RestoreResult {
  const RestoreResult({
    required this.id,
    required this.type,
    required this.label,
  });

  final int id;
  final String type;
  final String label;

  factory RestoreResult.fromJson(Map<String, dynamic> json) => RestoreResult(
    id: asInt(json['id']) ?? 0,
    type: json['type'] as String? ?? 'item',
    label: json['label'] as String? ?? 'Untitled',
  );
}
