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

/* Notificações push do painel (avisos de novo e-mail). */
self.addEventListener("push", (evento) => {
  let dados = {};
  try {
    dados = evento.data ? evento.data.json() : {};
  } catch (erro) {
    dados = { title: "MentAll PRO", body: evento.data ? evento.data.text() : "" };
  }
  const titulo = dados.title || "MentAll PRO";
  const opcoes = {
    body: dados.body || "",
    icon: "/admin/icon-192.png",
    badge: "/admin/icon-192.png",
    data: { url: dados.url || "/admin/email" },
  };
  evento.waitUntil(self.registration.showNotification(titulo, opcoes));
});

self.addEventListener("notificationclick", (evento) => {
  evento.notification.close();
  const url = (evento.notification.data && evento.notification.data.url) || "/admin/email";
  evento.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((lista) => {
      for (const cliente of lista) {
        if (cliente.url.indexOf("/admin") !== -1 && "focus" in cliente) {
          cliente.navigate(url);
          return cliente.focus();
        }
      }
      return clients.openWindow(url);
    })
  );
});
