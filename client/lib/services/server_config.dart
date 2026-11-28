import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'server_addresses_fallback.dart'
    if (dart.library.io) 'server_addresses_io.dart';

/// Resolves the API address at startup so the Android app follows the device's
/// current network instead of a hard-coded PC IP.
class ServerConfig {
  static const _overrideKey = 'classmate_api_base_url';
  static const _probeTimeout = Duration(milliseconds: 400);
  static const _batchSize = 48;

  /// Stored manual override → LAN discovery → build-time fallback.
  static Future<String> resolve() async {
    final override = await loadOverride();
    if (override != null) return override;
    final discovered = await discover();
    return discovered ?? AppConfig.apiBaseUrl;
  }

  static Future<String?> loadOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_overrideKey);
    if (value == null || value.trim().isEmpty) return null;
    return normalizeBaseUrl(value);
  }

  static Future<void> saveOverride(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_overrideKey, normalizeBaseUrl(baseUrl));
  }

  static Future<void> clearOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_overrideKey);
  }

  /// Accepts `192.168.5.234:3000`, `http://192.168.5.234:3000` and URLs that
  /// already include `/api`, always returning a clean `<scheme>://host/api`.
  static String normalizeBaseUrl(String input) {
    var value = input.trim();
    if (value.isEmpty || value.contains(RegExp(r'\s'))) {
      throw const FormatException('Enter the server address.');
    }
    if (!value.contains('://')) value = 'http://$value';

    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('Use an address like http://192.168.5.234:3000/api');
    }

    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.isEmpty) path = '/api';

    return uri.replace(path: path, query: null, fragment: null).toString();
  }

  /// Probes `/api/health` on every host of the device's LAN subnet in parallel
  /// batches. Returns `null` when the API is offline or not on this network.
  static Future<String?> discover() async {
    final configured = Uri.parse(AppConfig.apiBaseUrl);
    final port = configured.port == 0
        ? (configured.scheme == 'https' ? 443 : 80)
        : configured.port;
    final scheme = configured.scheme == 'https' ? 'https' : 'http';

    final candidates = <String>{};
    for (final address in (await deviceLanIpv4s()).take(2)) {
      for (final host in hostsInSubnet(address, skip: address)) {
        candidates.add('$scheme://$host:$port/api');
      }
    }
    if (candidates.isEmpty) return null;

    final urls = candidates.toList();
    for (var offset = 0; offset < urls.length; offset += _batchSize) {
      final batch = urls.skip(offset).take(_batchSize).toList();
      final results = await Future.wait(batch.map(isReachable));
      for (var index = 0; index < results.length; index++) {
        if (results[index]) return batch[index];
      }
    }
    return null;
  }

  static Future<bool> isReachable(String baseUrl) async {
    try {
      final uri = Uri.parse('${normalizeBaseUrl(baseUrl)}/health');
      final response = await http.get(uri).timeout(_probeTimeout);
      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> &&
          decoded['service'] == 'classmate-api';
    } catch (_) {
      return false;
    }
  }

  static List<String> hostsInSubnet(String address, {String? skip}) {
    final parts = address.split('.').map(int.parse).toList();
    if (parts.length != 4) return const <String>[];

    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    final hosts = <String>[];
    for (var host = 1; host <= 254; host++) {
      final candidate = '$prefix.$host';
      if (candidate != skip) hosts.add(candidate);
    }
    return hosts;
  }
}
