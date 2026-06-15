# ◆ Patrimônio — Guia Completo de Implantação

Sistema de controle de patrimônio pessoal com **banco de dados em nuvem
(Supabase)**, **painel administrativo com login** e **atualização em
tempo real**. Hospedagem 100% gratuita, sem necessidade de Git, commits
ou deploys para atualizar dados.

---

## 1. Arquitetura escolhida

**GitHub Pages (ou qualquer host estático) + Supabase**

| Critério | Como esta arquitetura atende |
|---|---|
| Custo | R$ 0 — GitHub Pages e o plano Free do Supabase (500MB DB, 50k usuários ativos/mês, realtime incluído) são gratuitos indefinidamente para este volume de dados (45 meses × ~10 ativos ≈ 450 linhas) |
| Manutenção | Um único arquivo `index.html` estático + um projeto Supabase. Sem servidor próprio, sem build, sem dependências para atualizar |
| Usuário não-técnico | Edição via formulários no app (aba ADMIN). Nenhum arquivo precisa ser tocado no dia a dia |
| Segurança | Autenticação Supabase (e-mail/senha) + Row Level Security: leitura pública, escrita só para usuário logado |
| Escalabilidade | Postgres real por baixo — suporta milhares de registros, múltiplas carteiras, novos relatórios, sem mudar de plataforma |
| Backup | Supabase faz backup diário automático (7 dias no plano Free); exportação SQL manual a qualquer momento |
| Tempo real | Supabase Realtime via WebSocket — qualquer alteração no banco aparece instantaneamente em todos os dispositivos abertos, sem recarregar a página |

### Por que não as outras opções

- **GitHub Pages + Firebase**: Firestore (NoSQL) exigiria reestruturar o
  modelo de dados em documentos/coleções sem relações nativas, mais
  difícil para consultas agregadas (somas por categoria, evolução
  histórica). Custo similar ao Supabase, porém SQL é mais natural para
  dados financeiros tabulares.
- **GitHub Pages + Google Sheets**: simples de editar, mas a API do
  Sheets tem limites de requisição baixos, não tem autenticação granular
  nativa (RLS), e o tempo real exige polling (não é instantâneo).
  Boa opção *temporária*, fraca para crescer.
- **Vercel / Netlify / Cloudflare Pages + Supabase**: tecnicamente
  equivalentes ao GitHub Pages neste caso, pois o app é 100% estático
  (sem build, sem funções serverless). GitHub Pages foi escolhido por já
  estar integrado ao fluxo de versionamento e não exigir conta adicional.
  Se preferir, qualquer um desses serve — basta seguir o mesmo processo
  de "arrastar a pasta" (Netlify Drop é a alternativa mais simples).

---

## 2. Análise do projeto anterior — bugs e melhorias identificados

| Problema na versão anterior | Solução nesta versão |
|---|---|
| Dados embutidos no código (`BASE_DATA`) — qualquer alteração exigia editar `index.html` e republicar | Dados agora vivem no Postgres (Supabase); o app lê via API |
| Persistência em `localStorage` — dados diferentes em cada dispositivo/navegador | Fonte única de verdade no banco, sincronizada em tempo real entre todos os dispositivos |
| Nomes de ativos inconsistentes entre anos (`PicPay`, `Picpay`, `Picpay-Nu CC`, `Mercado Pago`/`MercadoPago`, `Genial`/`Genial Investimentos`, etc.) | Tabela `assets` normaliza cada nome único como um registro com categoria; os 9 nomes descontinuados ficam marcados `active=false` (preservam histórico, não aparecem em novos meses) |
| Sem conceito de "categoria"/percentual-alvo | Tabela `categories` com `target_percent` editável — dashboard compara alocação real vs. meta |
| Sem aportes mensais | Tabela `contributions` (1 registro por mês) |
| Edição inline na aba Histórico, sem proteção | Edição centralizada na aba ADMIN, protegida por login (Supabase Auth) |
| Sem segurança — qualquer um podia (em teoria) editar `localStorage` | RLS no Postgres: leitura pública, escrita exige sessão autenticada |

---

## 3. Estrutura do banco de dados

```
categories                    assets
─────────────                 ─────────────────────
id (PK)                        id (PK)
name                           name (único)
color                          category_id ──► categories.id
target_percent                 active (bool)
sort_order                      sort_order

snapshots                      snapshot_values
─────────────                 ─────────────────────
id (PK)                         id (PK)
year                            snapshot_id ──► snapshots.id
month                           asset_id    ──► assets.id
label   (ex: "Abr 2026")        value (numeric)
snapshot_date                   unique(snapshot_id, asset_id)
unique(year, month)

contributions
─────────────────────
id (PK)
snapshot_id ──► snapshots.id (único, 1:1)
amount
note
```

- **Patrimônio total de um mês** = soma de `snapshot_values.value`
  daquele `snapshot_id` — calculado pelo app, sempre em tempo real.
- **Percentual por categoria** = soma dos ativos daquela categoria ÷
  total do mês — comparado com `categories.target_percent`.
- Todo o histórico (45 meses, Fev/2022 → Abr/2026, 351 valores) já vem
  pré-carregado no `schema.sql`.

---

## 4. Arquivos do projeto

```
patrimonio-app/
├── index.html              ← App completo (dashboard, histórico, análise, admin)
├── config.js                ← ÚNICO arquivo que você edita (URL + chave Supabase)
├── manifest.json             ← Configuração PWA
├── sw.js                      ← Service Worker (cache do app shell, dados sempre ao vivo)
├── icon.svg / icon-192.png / icon-512.png
├── supabase/
│   └── schema.sql            ← Script único: cria tabelas, segurança e dados históricos
└── README.md                  ← Este guia
```

---

## 5. Passo a passo de publicação

### Passo 1 — Criar o projeto Supabase (5 min)

1. Acesse **supabase.com** → **Start your project** → faça login com
   GitHub ou e-mail (gratuito).
2. **New Project** → escolha um nome (ex: `patrimonio`), defina uma
   senha de banco (guarde-a) e a região mais próxima (ex: South America
   - São Paulo).
3. Aguarde ~2 minutos enquanto o projeto é provisionado.

### Passo 2 — Executar o schema SQL

1. No painel do projeto, vá em **SQL Editor** (ícone de terminal na
   barra lateral) → **New query**.
2. Abra o arquivo `supabase/schema.sql` deste pacote, copie **todo o
   conteúdo** e cole no editor.
3. Clique em **Run** (ou `Ctrl+Enter`).
4. Resultado esperado: "Success. No rows returned". Isso cria as 5
   tabelas, as políticas de segurança (RLS), habilita o tempo real e
   carrega os 45 meses de histórico.

> Para confirmar que os dados entraram, rode em uma nova query:
> ```sql
> select label, (select sum(value) from snapshot_values sv where sv.snapshot_id = s.id) as total
> from snapshots s order by s.id;
> ```
> Deve listar 45 linhas, terminando em "Abr 2026 — 371216.85".

### Passo 3 — Criar seu usuário administrador

1. No painel, vá em **Authentication → Users**.
2. Clique em **Add user** → **Create new user**.
3. Preencha **Email** e **Password** (essa será sua conta de admin —
   anote a senha).
4. Marque **Auto Confirm User** (assim você não precisa confirmar por
   e-mail) → **Create user**.

> Você pode criar quantos usuários quiser depois, mas para uso pessoal
> um único usuário é suficiente — qualquer usuário autenticado tem
> permissão de escrita (definido no `schema.sql`).

### Passo 4 — Obter URL e chave da API

1. Vá em **Project Settings** (ícone de engrenagem) → **API**.
2. Copie o **Project URL** (ex: `https://abcdefgh.supabase.co`).
3. Copie a chave **anon public** (uma string longa começando com `eyJ...`).

   ⚠️ **Nunca use a chave `service_role`** — ela tem acesso total e
   ignora as regras de segurança. Use sempre a **anon public**.

### Passo 5 — Configurar o app

1. Abra o arquivo `config.js` deste pacote em qualquer editor de texto
   (até o Bloco de Notas funciona).
2. Substitua os dois valores:

```js
window.SUPABASE_CONFIG = {
  url: "https://abcdefgh.supabase.co",
  anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
};
```

3. Salve o arquivo.

### Passo 6 — Publicar (GitHub Pages)

1. Crie um repositório novo no GitHub (pode ser privado ou público —
   GitHub Pages funciona em ambos no plano gratuito para contas
   pessoais, desde que público; para privado é necessário GitHub Pro).
   **Recomendado: repositório público** — os dados financeiros NÃO
   ficam expostos no código, apenas a URL e a chave pública do Supabase
   (que só permite leitura/escrita conforme as regras RLS).
2. Faça upload de **todos os arquivos** desta pasta (`index.html`,
   `config.js`, `manifest.json`, `sw.js`, ícones) para a raiz do
   repositório — pode usar "Add file → Upload files" direto no site do
   GitHub, sem precisar instalar Git.
3. Vá em **Settings → Pages** → em "Branch" selecione `main` e pasta
   `/ (root)` → **Save**.
4. Aguarde ~1 minuto. O GitHub mostrará a URL pública, algo como:
   `https://seu-usuario.github.io/patrimonio/`

### Alternativa ainda mais simples — Netlify Drop

Se preferir não usar GitHub:

1. Acesse **netlify.com/drop**.
2. Arraste a pasta inteira (com `config.js` já editado) para a página.
3. Pronto — você recebe uma URL HTTPS pública imediatamente.

### Passo 7 — Instalar no iPhone

1. No iPhone, abra **Safari** e acesse a URL publicada.
2. Toque em **Compartilhar (□↑)** → **Adicionar à Tela de Início**.
3. O app abre em tela cheia, como um aplicativo nativo, e funciona
   offline para visualização (os dados ficam em cache até a próxima
   sincronização).

---

## 6. Como usar o painel administrativo

Acesse a aba **ADMIN** (ícone de cadeado) e faça login com o e-mail e
senha criados no Passo 3.

### Atualizar Patrimônio (lançar um novo mês)

1. Aba **Patrimônio** → selecione **"+ Novo mês"**.
2. Os valores são pré-preenchidos com o mês anterior — edite cada um.
3. O **total é recalculado automaticamente** conforme você digita.
4. Toque em **SALVAR**. O dashboard, histórico e gráficos atualizam
   instantaneamente — em qualquer dispositivo aberto.

Para corrigir um mês já lançado, selecione-o no menu em vez de "Novo mês".

### Atualizar Aportes Mensais

Aba **Aportes** → escolha o mês → digite o valor aportado e uma
observação opcional → **SALVAR**.

### Adicionar / Editar / Excluir Investimentos (Ativos)

Aba **Ativos**:
- **Adicionar**: digite o nome (ex: "Itaú", "Avenue") e escolha a
  categoria → **ADICIONAR ATIVO**. Ele passará a aparecer nos próximos
  meses lançados.
- **Editar**: ícone de lápis → altere nome, categoria ou se está
  ativo/inativo → **SALVAR**.
- **Excluir**: ícone de lixeira → confirma a exclusão. ⚠️ Isso remove
  **todo o histórico** daquele ativo. Para apenas "aposentar" um ativo
  sem perder o histórico, marque-o como **inativo** em vez de excluir.

### Atualizar Percentuais das Categorias

Aba **Categorias** → ajuste a "Meta %" de cada categoria → ícone de
disquete para salvar cada uma. O app mostra a soma das metas (ideal:
100%) e, no Dashboard/Análise, compara a alocação real com a meta.

---

## 7. Atualização em tempo real — como funciona

O app abre uma conexão **WebSocket** (Supabase Realtime) com o banco.
Qualquer `INSERT`, `UPDATE` ou `DELETE` nas tabelas monitoradas dispara
um evento que o app recebe e usa para **recarregar e recalcular tudo**
automaticamente — sem precisar atualizar a página. Isso significa que,
se você editar um valor no celular, o dashboard aberto no computador
muda na hora.

---

## 8. Backup

- **Automático**: o Supabase faz backup diário do banco (retenção de 7
  dias no plano Free, configurável/maior em planos pagos).
- **Manual**: em **Database → Backups** você pode baixar um dump SQL a
  qualquer momento. Recomendado fazer isso a cada poucos meses e guardar
  o arquivo localmente (ex: Google Drive).
- **Exportação rápida via SQL Editor**:
  ```sql
  select s.label, a.name, sv.value
  from snapshot_values sv
  join snapshots s on s.id = sv.snapshot_id
  join assets a on a.id = sv.asset_id
  order by s.year, s.month, a.name;
  ```
  Use o botão "Export" do resultado para baixar como CSV.

---

## 9. Segurança

- **Leitura pública**: qualquer pessoa com o link pode *ver* o
  dashboard (sem mostrar credenciais). Se quiser tornar tudo privado,
  é possível alterar as políticas RLS de `select` para exigir login
  também — me avise se quiser esse ajuste.
- **Escrita protegida**: somente usuários autenticados (criados por você
  no painel Supabase) podem alterar dados.
- **Chave anon**: é seguro expor a chave `anon public` no código —
  ela é projetada para uso no navegador e respeita as políticas RLS.
  A chave `service_role` (que NÃO deve ser usada aqui) é que precisa
  ficar secreta.

---

## 10. Manutenção contínua

- **Novo ativo, categoria ou mês**: tudo via painel ADMIN, sem deploy.
- **Mudança visual/layout**: requer editar `index.html` e republicar
  (re-upload no GitHub/Netlify) — mas isso é raro, não faz parte da
  rotina mensal.
- **Esqueceu a senha do admin**: Supabase → Authentication → Users →
  selecione o usuário → "Send password recovery" ou redefina
  diretamente.
