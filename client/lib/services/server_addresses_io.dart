import 'dart:io';

/// Returns private IPv4 addresses of the device's real network adapters.
/// Wi-Fi/Ethernet adapters come first; virtual VPN/container adapters are
/// ignored so discovery stays on the local network.
Future<List<String>> deviceLanIpv4s() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );

  final preferred = <String>[];
  final other = <String>[];

  for (final interface in interfaces) {
    if (_isVirtual(interface.name)) continue;
    final target = _isPreferred(interface.name) ? preferred : other;
    for (final address in interface.addresses) {
      if (address.isLoopback || !_isPrivate(address.address)) continue;
      if (!target.contains(address.address)) target.add(address.address);
    }
  }

  return [...preferred, ...other];
}

bool _isPreferred(String name) =>
    RegExp(r'wlan|wi-?fi|ethernet|^eth', caseSensitive: false).hasMatch(name);

bool _isVirtual(String name) => RegExp(
      r'virtual|vethernet|hyper-v|docker|wsl|vmware|virtualbox|tun|vpn|rmnet|ccmni|ppp',
      caseSensitive: false,
    ).hasMatch(name);

bool _isPrivate(String address) {
  final parts = address.split('.').map(int.parse).toList();
  if (parts.length != 4 || parts.any((part) => part < 0 || part > 255)) return false;
  final first = parts[0];
  final second = parts[1];
  if (first == 169 && second == 254) return false;
  return first == 10 ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}
