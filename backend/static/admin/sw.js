/* Service worker mínimo do painel: permite "instalar app" sem cachear dados.
   Painel administrativo sempre busca da rede (nada de conteúdo sensível em cache). */
self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (evento) => {
  evento.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", (evento) => {
  evento.respondWith(fetch(evento.request));
});
