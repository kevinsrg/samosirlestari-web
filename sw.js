const CACHE_NAME = 'samosirlestari-v1';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './supabase-config.js',
  './assets/pwa-icon-192.png',
  './assets/pwa-icon-512.png',
  './assets/danau-toba-landscape.jpg',
  './assets/danau-toba-portrait.jpg',
  './assets/danau-toba-samosir.png'
];
const ASSET_PATH = new URL('./assets/', self.registration.scope).pathname;

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys
          .filter(key => key.startsWith('samosirlestari-') && key !== CACHE_NAME)
          .map(key => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        try {
          const response = await fetch(request);
          if (response.ok) {
            await (await caches.open(CACHE_NAME)).put(request, response.clone());
          }
          return response;
        } catch {
          return await caches.match(request) ||
            await caches.match('./index.html') ||
            Response.error();
        }
      })()
    );
    return;
  }

  const isAppAsset = url.pathname.endsWith('/manifest.json') ||
    url.pathname.endsWith('.js') ||
    url.pathname.startsWith(ASSET_PATH);
  if (!isAppAsset) return;

  event.respondWith(
    (async () => {
      const cached = await caches.match(request);
      if (cached) return cached;
      const response = await fetch(request);
      if (response.ok) {
        await (await caches.open(CACHE_NAME)).put(request, response.clone());
      }
      return response;
    })()
  );
});
