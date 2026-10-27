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
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value != null && '$value'.isNotEmpty) params[key] = '$value';
    });
    return Uri.parse('$_baseUrl$path')
        .replace(queryParameters: params.isEmpty ? null : params);
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

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

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

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body}) => _send('POST', path, body: body);
  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);
}
