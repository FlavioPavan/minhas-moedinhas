/* Service worker do Minhas Moedinhas: abre offline e carrega rápido.
   - Página e arquivos do app: rede primeiro, cache como reserva.
   - Bibliotecas de CDN e fontes: cache primeiro (versões fixas).
   - APIs (Supabase, Banco Central): nunca passam pelo cache. */
const VERSAO = 'mm-v2';
const SHELL = ['./', './index.html', './manifest.webmanifest', './icon.svg'];
const CDN = ['unpkg.com', 'cdn.jsdelivr.net', 'cdn.tailwindcss.com', 'fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSAO).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== VERSAO).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin === self.location.origin) {
    e.respondWith(
      fetch(req).then((res) => { const copia = res.clone(); caches.open(VERSAO).then((c) => c.put(req, copia)); return res; })
        .catch(() => caches.match(req).then((r) => r || caches.match('./index.html')))
    );
  } else if (CDN.includes(url.hostname)) {
    e.respondWith(caches.match(req).then((r) => r || fetch(req).then((res) => { const copia = res.clone(); caches.open(VERSAO).then((c) => c.put(req, copia)); return res; })));
  }
});
