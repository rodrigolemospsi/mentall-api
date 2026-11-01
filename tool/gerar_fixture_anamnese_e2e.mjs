// Gera o fixture de interoperabilidade WebCrypto -> app (AES-256-GCM).
// Uso: node tool/gerar_fixture_anamnese_e2e.mjs > test/fixtures/anamnese_e2e_webcrypto.json
import { webcrypto as crypto } from 'node:crypto';

const chave = crypto.getRandomValues(new Uint8Array(32));
const iv = crypto.getRandomValues(new Uint8Array(12));
const plaintext = JSON.stringify({
  queixa_principal: 'Resposta sintética de teste',
  pensou_morte: false,
  escala_ansiedade: 4,
  lista: ['opcao_a', 'opcao_b'],
});
const key = await crypto.subtle.importKey('raw', chave, 'AES-GCM', false, ['encrypt']);
const ct = new Uint8Array(await crypto.subtle.encrypt(
  { name: 'AES-GCM', iv, tagLength: 128 },
  key,
  new TextEncoder().encode(plaintext),
));
const b64url = (bytes) => Buffer.from(bytes).toString('base64')
  .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
console.log(JSON.stringify({
  observacao: 'Fixture gerado por tool/gerar_fixture_anamnese_e2e.mjs (WebCrypto do Node). Nao editar a mao.',
  versao: 1,
  chave_base64url: b64url(chave),
  iv: Buffer.from(iv).toString('base64'),
  ct: Buffer.from(ct).toString('base64'),
  plaintext,
}, null, 2));
