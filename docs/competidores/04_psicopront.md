# PsicoPront — funcionalidades

**Data:** 14/10/2026 · **Fonte:** `psicopront.com.br`, `/recursos`, `/privacidade` + probe REA.
**Perfil:** web. Plano único **R$ 79/mês**. CNPJ 64.195.021/0001-92 (Curitiba/PR). Foco em
**escrituração fiscal** do psicólogo autônomo.

> Escopo público. O site entrega **pouquíssimo JavaScript** (server-rendered) — probe REA não
> encontrou rotas nem fornecedores no cliente.

## 1. Financeiro / cobrança
- Público: **Livro Caixa** (receitas/despesas, categorias, **despesas recorrentes**, formas de
  pagamento), **recibos com assinatura digital** (código de verificação), export **CSV/PDF**.
- **Fiscal** (é o diferencial): **Carnê Leão** — geração automática do arquivo de escrituração no
  formato da Receita (IN RFB nº 2240/2024), **código de ocupação 255**, importação em lote (até 1000
  recibos); **Receita Saúde** via portal e-CAC; para PJ, livro caixa exportável para contabilidade.
- **Não** há (publicamente) **cobrança online/Pix/recorrência** — o foco é **escrituração**, não
  recebimento. Fornecedor de pagamento: **nenhum** (não é gateway).

## 2. Mensagens profissional → paciente
- Público: **não destacado** no material de recursos. Há **links de coleta de dados** e **links de
  contrato** para assinatura, mas nenhuma automação de mensageria é anunciada. Canal observado: **nenhum**.

## 3. Teleconsulta
- **Não anunciada** na página de recursos (não há vídeo/sala). Pela material público, o PsicoPront
  **não** oferece teleconsulta integrada.

## 4. Achados do probe REA (14/10/2026)
- Marketing e `/login`: **JS mínimo**, sem rotas de API expostas no cliente e sem domínio de terceiro.
- IA: **OpenAI GPT-4o-mini** (declarado), **apenas texto** ("áudio nunca é enviado à IA"), opcional.

## 5. Implicações para o MentAll
- O PsicoPront **não compete** em mensageria/teleconsulta — compete em **fiscal/contábil** (Carnê
  Leão/Receita Saúde). É uma frente **nossa ausente** e relativamente barata de copiar (CSV/planilha),
  a avaliar em `docs/competidores/07_sintese.md`.
- Reforça que "IA só com texto" é uma escolha de postura comum no mercado.
