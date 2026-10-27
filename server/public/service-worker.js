self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open('classmate-shell-v1');
    await cache.addAll(['/', '/style.css', '/app.js']);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames
      .filter(name => name.startsWith('flutter-') || (name.startsWith('classmate-shell-') && name !== 'classmate-shell-v1'))
      .map(name => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin || url.pathname.startsWith('/api/')) return;

  const shellFiles = ['/', '/style.css', '/app.js'];
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request)
      .then(async response => {
        if (response.ok) await (await caches.open('classmate-shell-v1')).put('/', response.clone());
        return response;
      })
      .catch(async () => (await caches.open('classmate-shell-v1')).match('/') || Response.error()));
    return;
  }

  if (!shellFiles.includes(url.pathname)) return;
  event.respondWith(fetch(request)
    .then(async response => {
      if (response.ok) await (await caches.open('classmate-shell-v1')).put(request, response.clone());
      return response;
    })
    .catch(async () => (await caches.open('classmate-shell-v1')).match(request) || Response.error()));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if ('focus' in client) {
        await client.focus();
        client.postMessage({
          type: 'classmate-open-view',
          view: event.notification.data?.view || 'works',
        });
        return;
      }
    }
    await self.clients.openWindow('/');
  })());
});
