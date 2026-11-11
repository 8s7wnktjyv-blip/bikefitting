// FYF Offline-Speicher. Immer zuerst das Netz (damit Updates sofort ankommen), ohne Netz die letzte gespeicherte Version.
// Nur Dateien dieser Seite – Anfragen an Supabase und andere Server werden nie zwischengespeichert.
const CACHE = 'fyf-app-v1-p15';
const CORE = ['./', './index.html', './manifest.webmanifest', './rad.html', './pass.webmanifest', './finder.html', './icon-192.png', './icon-512.png', './apple-touch-icon.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const r = e.request; const u = new URL(r.url);
  if (r.method !== 'GET' || u.origin !== location.origin) return;
  e.respondWith(fetch(r).then(res => { if (res.ok && res.type === 'basic') { const cp = res.clone(); caches.open(CACHE).then(c => c.put(r, cp)); } return res; })
    .catch(() => caches.match(r, { ignoreSearch: true }).then(m => m || (r.mode === 'navigate' ? caches.match(/rad\.html|finder\.html/.test(u.pathname) ? './rad.html' : './index.html') : undefined)).then(m => m || new Response('Offline', { status: 503 }))));
});
