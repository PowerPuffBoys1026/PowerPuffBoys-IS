/// Lenient JSON coercion helpers shared by the v2 models.
///
/// The API returns numbers as JSON numbers, but PostgreSQL `NUMERIC` columns
/// have historically been serialised as strings; these helpers accept both.
double? asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? asInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// Parses an ISO-8601 timestamp and converts it to local time.
DateTime? asLocalDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}
