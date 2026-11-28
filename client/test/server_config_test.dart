import 'dart:io';

import 'package:classmate/services/server_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerConfig.normalizeBaseUrl', () {
    test('adds scheme and /api for a bare host', () {
      expect(
        ServerConfig.normalizeBaseUrl('192.168.5.234:3000'),
        'http://192.168.5.234:3000/api',
      );
    });

    test('keeps an explicit /api and removes trailing slashes', () {
      expect(
        ServerConfig.normalizeBaseUrl('http://192.168.5.234:3000/api///'),
        'http://192.168.5.234:3000/api',
      );
    });

    test('rejects invalid addresses', () {
      expect(
        () => ServerConfig.normalizeBaseUrl('not a server'),
        throwsFormatException,
      );
    });
  });

  group('ServerConfig.hostsInSubnet', () {
    test('lists the /24 neighbours except the device itself', () {
      final hosts = ServerConfig.hostsInSubnet('192.168.5.234', skip: '192.168.5.234');
      expect(hosts.length, 253);
      expect(hosts.first, '192.168.5.1');
      expect(hosts.last, '192.168.5.254');
      expect(hosts, isNot(contains('192.168.5.234')));
    });
  });

  group('ServerConfig.isReachable', () {
    test('manual probe waits longer than a discovery probe', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"service":"classmate-api"}');
        await request.response.close();
      });

      final url = 'http://127.0.0.1:${server.port}/api';
      expect(await ServerConfig.isReachable(url), isTrue);
      expect(
        await ServerConfig.isReachable(url, timeout: const Duration(milliseconds: 100)),
        isFalse,
      );
    });
  });
}
