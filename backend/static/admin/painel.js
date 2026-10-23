(function () {
  "use strict";

  // 1) Registra o service worker (1x) para o navegador permitir instalar o painel.
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker
      .register("/admin/sw.js", { scope: "/admin" })
      .catch(function () {
        /* sem PWA não perde nada: painel continua web normal */
      });
  }

  // 2) No celular, envolve tabelas largas em um container com rolagem horizontal.
  function adaptarTabelas() {
    document.querySelectorAll("table").forEach(function (tabela) {
      if (tabela.parentElement && tabela.parentElement.classList.contains("rolagem")) {
        return;
      }
      var caixa = document.createElement("div");
      caixa.className = "rolagem";
      tabela.parentNode.insertBefore(caixa, tabela);
      caixa.appendChild(tabela);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", adaptarTabelas);
  } else {
    adaptarTabelas();
  }

  // 3) Botão "Instalar app" quando o navegador oferecer a instalação.
  var promptCapturado = null;
  window.addEventListener("beforeinstallprompt", function (evento) {
    evento.preventDefault();
    promptCapturado = evento;
    if (document.querySelector(".instalar-app")) {
      return;
    }
    var botao = document.createElement("button");
    botao.type = "button";
    botao.className = "instalar-app";
    botao.textContent = "Instalar app";
    botao.style.cssText =
      "position:fixed;bottom:16px;right:16px;z-index:99;background:#8806CE;color:#fff;" +
      "border:0;border-radius:999px;padding:11px 18px;font-size:14px;font-weight:600;" +
      "box-shadow:0 3px 10px rgba(0,0,0,.3);cursor:pointer";
    botao.addEventListener("click", function () {
      botao.remove();
      if (promptCapturado) {
        promptCapturado.prompt();
        promptCapturado = null;
      }
    });
    document.body.appendChild(botao);
  });
})();
