const CACHE = 'patrimonio-v4-supabase';

// App shell — arquivos estáticos que não mudam (o conteúdo financeiro
// vem do Supabase em tempo real e NÃO é armazenado no cache).
const CORE = [
  './',
  './index.html',
  './config.js',
  './manifest.json',
  './icon.svg',
  './icon-192.png',
  './icon-512.png',
];

const CDN = [
  'https://unpkg.com/react@18/umd/react.production.min.js',
  'https://unpkg.com/react-dom@18/umd/react-dom.production.min.js',
  'https://unpkg.com/@babel/standalone@7.24.0/babel.min.js',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js',
  'https://fonts.googleapis.com/css2?family=Cinzel:wght@400;600;700&family=Crimson+Text:ital,wght@0,400;0,600;1,400&display=swap',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll([...CORE, ...CDN]))
      .catch(() => caches.open(CACHE).then(c => c.addAll(CORE)))
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;

  const url = e.request.url;

  // NUNCA cachear chamadas à API do Supabase — sempre buscar dados frescos.
  if (url.includes('supabase.co/rest') || url.includes('supabase.co/auth') ||
      url.includes('supabase.co/realtime')) {
    return; // deixa passar direto para a rede
  }

  // App shell e CDNs: cache-first com atualização em segundo plano.
  e.respondWith(
    caches.match(e.request).then(cached => {
      const fetchPromise = fetch(e.request).then(res => {
        if (res && res.status === 200) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
        }
        return res;
      }).catch(() => cached);
      return cached || fetchPromise;
    })
  );
});
