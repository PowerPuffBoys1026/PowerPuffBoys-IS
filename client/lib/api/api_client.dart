import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Error thrown for any non-2xx API response.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, [this.details = const []]);

  final int statusCode;
  final String message;
  final List<dynamic> details;

  @override
  String toString() => message;
}

/// Thin JSON wrapper around `package:http` that injects the bearer token and
/// normalises the API's `{ error: { message, details } }` shape.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = _clean(baseUrl);

  final http.Client _client;
  String? _baseUrl;

  /// Effective base URL (runtime override when set, build-time default otherwise).
  String get baseUrl => _baseUrl ?? AppConfig.apiBaseUrl;

  set baseUrl(String? value) => _baseUrl = _clean(value);

  String? token;

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }

  Map<String, String> get _authHeaders => {
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        ..._authHeaders,
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value != null && '$value'.isNotEmpty) params[key] = '$value';
    });
    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: params.isEmpty ? null : params);
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      return null;
    }
  }

  Never _throwFor(http.Response response) {
    final decoded = _decode(response);
    final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
    if (error is Map<String, dynamic>) {
      throw ApiException(
        response.statusCode,
        error['message']?.toString() ?? 'Request failed',
        (error['details'] as List?) ?? const [],
      );
    }
    throw ApiException(response.statusCode, 'Request failed (${response.statusCode})');
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);

    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: _headers);
        break;
      case 'POST':
        response = await _client.post(uri, headers: _headers, body: encoded);
        break;
      case 'PUT':
        response = await _client.put(uri, headers: _headers, body: encoded);
        break;
      case 'PATCH':
        response = await _client.patch(uri, headers: _headers, body: encoded);
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: _headers, body: encoded);
        break;
      default:
        throw ArgumentError('Unsupported method $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decode(response);
    }
    _throwFor(response);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body}) => _send('POST', path, body: body);
  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Downloads a binary payload (attachment contents).
  Future<List<int>> getBytes(String path) async {
    final response = await _client.get(_uri(path), headers: _authHeaders);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    _throwFor(response);
  }

  /// Uploads one file as `multipart/form-data` using [field] (default `file`).
  Future<dynamic> postMultipart(
    String path, {
    required String filePath,
    required String fileName,
    String field = 'file',
  }) async {
    return _sendMultipart(
      path,
      await http.MultipartFile.fromPath(field, filePath, filename: fileName),
    );
  }

  /// Uploads in-memory bytes (used for Android `content://` picks).
  Future<dynamic> postMultipartBytes(
    String path, {
    required List<int> bytes,
    required String fileName,
    String field = 'file',
  }) async {
    return _sendMultipart(
      path,
      http.MultipartFile.fromBytes(field, bytes, filename: fileName),
    );
  }

  Future<dynamic> _sendMultipart(String path, http.MultipartFile file) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_authHeaders)
      ..files.add(file);

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decode(response);
    }
    _throwFor(response);
  }
}
