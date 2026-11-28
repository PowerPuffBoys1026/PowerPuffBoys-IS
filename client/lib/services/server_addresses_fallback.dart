/// Web fallback: the browser cannot enumerate LAN interfaces, so discovery is
/// skipped there and the configured (or manually entered) URL is used.
Future<List<String>> deviceLanIpv4s() async => const <String>[];
