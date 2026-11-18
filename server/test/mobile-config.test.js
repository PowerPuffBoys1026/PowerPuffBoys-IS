const test = require('node:test');
const assert = require('node:assert/strict');

const { lanAddresses, render } = require('../scripts/mobile-config');

test('lanAddresses returns only non-internal IPv4 interfaces', () => {
  for (const address of lanAddresses()) {
    assert.match(address.address, /^\d+\.\d+\.\d+\.\d+$/);
    assert.ok(!address.address.startsWith('127.'));
    assert.ok(!address.address.startsWith('169.254.'));
    assert.equal(typeof address.name, 'string');
  }
});

test('lanAddresses prefers physical adapters over virtual ones', () => {
  const addresses = lanAddresses({
    'vEthernet (Default Switch)': [{ family: 'IPv4', address: '172.30.192.1', internal: false }],
    'Wi-Fi 6': [{ family: 'IPv4', address: '192.168.254.137', internal: false }],
    'Ethernet': [{ family: 'IPv4', address: '192.168.1.20', internal: false }],
    'Loopback Pseudo-Interface': [{ family: 'IPv4', address: '127.0.0.1', internal: true }],
    'VMware Network Adapter': [{ family: 'IPv4', address: '192.168.17.1', internal: false }],
    'Local Area Connection': [{ family: 'IPv4', address: '169.254.5.4', internal: false }],
  });

  assert.deepEqual(
    addresses.map((item) => item.address),
    ['192.168.254.137', '192.168.1.20', '172.30.192.1', '192.168.17.1'],
  );
});

test('render shows the API URL and CORS origin for the first LAN address', () => {
  const output = render({
    port: 3001,
    addresses: [{ name: 'Wi-Fi', address: '192.168.1.25' }],
    host: '',
  });

  assert.match(output, /API port: 3001/);
  assert.match(output, /192\.168\.1\.25/);
  assert.match(output, /API_BASE_URL=http:\/\/192\.168\.1\.25:3001\/api/);
  assert.match(output, /http:\/\/192\.168\.1\.25:8080/);
  assert.match(output, /api\/health/);
});

test('render explains what to do when there is no LAN address', () => {
  const output = render({ port: 3000, addresses: [], host: '' });
  assert.match(output, /No LAN IPv4 address was found/);
  assert.match(output, /10\.0\.2\.2/);
});

test('render shows an explicit host override when provided', () => {
  const output = render({ port: 3000, addresses: [], host: 'http://tunnel.example.com' });
  assert.match(output, /API host override: http:\/\/tunnel\.example\.com/);
});
