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

/* Ativação de notificações push (avisos de novo e-mail) */
(function () {
  "use strict";
  var botao = document.getElementById("ativar-push");
  if (!botao) return;

  function texto(msg) {
    var alvo = document.getElementById("status-push");
    if (alvo) alvo.textContent = msg;
  }

  function base64ParaUint8(base64) {
    var preenchido = base64.replace(/-/g, "+").replace(/_/g, "/");
    var sobra = preenchido.length % 4;
    if (sobra) preenchido += "=".repeat(4 - sobra);
    var bruto = atob(preenchido);
    var saida = new Uint8Array(bruto.length);
    for (var i = 0; i < bruto.length; i++) saida[i] = bruto.charCodeAt(i);
    return saida;
  }

  async function registraNoServidor(inscricao) {
    var resposta = await fetch("/admin/push/subscribe", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(inscricao),
    });
    if (!resposta.ok) throw new Error("falha ao salvar inscrição");
    return resposta.json();
  }

  botao.addEventListener("click", async function () {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      texto("Este navegador não suporta notificações push.");
      return;
    }
    if (!("Notification" in window)) {
      texto("Este navegador não suporta notificações.");
      return;
    }
    try {
      var permissao = await Notification.requestPermission();
      if (permissao !== "granted") {
        texto("Permissão de notificação negada. Autorize no cadeado do navegador e tente de novo.");
        return;
      }
      var registro = await navigator.serviceWorker.ready;
      var chave = botao.getAttribute("data-public-key") || "";
      if (!chave) {
        texto("Chave VAPID ausente no servidor.");
        return;
      }
      var inscricao = await registro.pushManager.getSubscription();
      if (!inscricao) {
        inscricao = await registro.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: base64ParaUint8(chave),
        });
      }
      var dados = await registraNoServidor(inscricao.toJSON());
      botao.textContent = "Notificações ativadas neste dispositivo";
      botao.disabled = true;
      texto("Pronto: " + (dados.inscricoes || 1) + " dispositivo(s) recebendo avisos.");
    } catch (erro) {
      texto("Não foi possível ativar: " + (erro && erro.message ? erro.message : String(erro)));
    }
  });

  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.ready.then(function (registro) {
      registro.pushManager.getSubscription().then(function (inscricao) {
        if (inscricao) {
          botao.textContent = "Notificações já ativas neste dispositivo";
          texto("Este dispositivo já está inscrito nos avisos.");
        }
      });
    });
  }
})();
