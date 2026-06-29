const CACHE_NAME = 'sovereign-v3';
const STATIC_ASSETS = ['/', '/index.html', '/styles.css', '/app.js', '/manifest.json'];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(STATIC_ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  const url = event.request.url;
  // Never cache API calls or external RPCs — always go to network
  if (url.includes('/api/') || url.includes('rpc.ritualfoundation') || 
      url.includes('explorer.ritualfoundation') || url.includes('registry.ritualfoundation') ||
      url.includes('openrouter.ai') || url.includes('api.openai.com') ||
      url.includes('api.anthropic.com') || url.includes('generativelanguage.googleapis') ||
      url.includes('huggingface.co')) {
    event.respondWith(fetch(event.request));
  } else {
    // Network-first for static assets (JS/CSS/HTML) — updates propagate
    event.respondWith(
      fetch(event.request).then(response => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(c => c.put(event.request, clone));
        }
        return response;
      }).catch(() => caches.match(event.request))
    );
  }
});
