/**
 * Prints the values needed to run the Flutter client on a phone over Wi-Fi.
 *
 * No secrets are read or printed: this only inspects local network interfaces
 * and the optional PORT environment variable.
 */
const os = require('node:os');

const DEFAULT_PORT = 3000;

function isPrivateIpv4(address) {
  const [first, second] = address.split('.').map(Number);
  return (
    first === 10 ||
    (first === 172 && second >= 16 && second <= 31) ||
    (first === 192 && second === 168)
  );
}

function isVirtualInterface(name) {
  return /virtual|vethernet|vmware|virtualbox|hyper-v|docker|wsl/i.test(name);
}

function interfaceRank(name) {
  if (isVirtualInterface(name)) return 3;
  if (/wi-?fi|wireless/i.test(name)) return 0;
  if (/ethernet/i.test(name)) return 1;
  return 2;
}

function lanAddresses(networkInterfaces = os.networkInterfaces()) {
  const found = [];
  for (const [name, interfaces] of Object.entries(networkInterfaces)) {
    for (const iface of interfaces || []) {
      // Skip loopback (127.x), link-local (169.254.x) and public addresses.
      if (iface.family !== 'IPv4' || iface.internal) continue;
      if (!isPrivateIpv4(iface.address)) continue;
      found.push({ name, address: iface.address });
    }
  }
  // Prefer a physical Wi-Fi/Ethernet adapter over Docker/Hyper-V virtual ones.
  return found.sort(
    (a, b) => interfaceRank(a.name) - interfaceRank(b.name) || a.name.localeCompare(b.name),
  );
}

function render({ port, addresses, host }) {
  const lines = [
    'ClassMate — mobile connection helper',
    `API port: ${port} (set PORT in server/.env to change it)`,
    '',
  ];

  if (host) {
    lines.push(`API host override: ${host}`);
  }

  if (!addresses.length) {
    lines.push(
      'No LAN IPv4 address was found. Connect to Wi-Fi, then run this script again.',
      'For an Android emulator you can use 10.0.2.2 instead of a LAN address.',
    );
    return lines.join('\n');
  }

  lines.push('LAN IPv4 addresses detected (phone and PC must be on the same Wi-Fi):');
  for (const { name, address } of addresses) {
    lines.push(`  ${name.padEnd(16)} ${address}`);
  }

  const preferred = addresses[0].address;
  lines.push(
    '',
    'Run the Flutter client on a phone with:',
    `  flutter run -d <device-id> --dart-define=API_BASE_URL=http://${preferred}:${port}/api`,
    '',
    'Checking the API from the phone browser:',
    `  http://${preferred}:${port}/api/health`,
    '',
    'If you use the Web client on the phone, add its origin to CORS_ORIGIN in server/.env:',
    `  CORS_ORIGIN=http://localhost:8080,http://127.0.0.1:8080,http://${preferred}:8080`,
    '',
    'Windows Firewall (run once, in an elevated PowerShell):',
    `  New-NetFirewallRule -DisplayName "ClassMate API TCP ${port}" \``,
    `    -Direction Inbound -Protocol TCP -LocalPort ${port} \``,
    '    -RemoteAddress LocalSubnet -Action Allow',
  );

  return lines.join('\n');
}

function mobileConfig() {
  return render({
    port: Number(process.env.PORT) || DEFAULT_PORT,
    addresses: lanAddresses(),
    host: process.env.API_HOST || '',
  });
}

module.exports = { lanAddresses, render, mobileConfig };

if (require.main === module) {
  console.log(mobileConfig());
}
