# mewtda-trocas

Central de trocas e devoluções da Mewtda, separada do CRM do **mewtda-painel**.
Rails 8.1 · Ruby 3.4 · Hotwire (Turbo + Stimulus, importmap) · Propshaft · PostgreSQL · Material Design 3 (branco + verde).

## O que tem

**Área logada** (usuários com a mesma estrutura do painel, em banco próprio)
- **Solicitações**: contadores por status, filtro, busca (pedido/nome/e-mail), paginação.
- **Detalhe**: itens com fotos, linha do tempo, aprovar/rejeitar/concluir, cupom gerado, nota interna.
- **Configuração**: página ativa, nome, instruções, prazos, cor de destaque, logo, link público.
- **E-mails**: os 4 templates (recebida, aprovada, rejeitada, concluída) com pré-visualização ao vivo.
- Admin (profile_id 1) troca de loja pelo seletor no topo; usuários comuns veem só a própria loja; afiliados não entram.

**Página pública** — `/troca/:slug` (o mesmo slug do painel; `/crm/troca/:slug` redireciona)
1. Cliente informa nº do pedido + e-mail → busca na Shopify (limite de 10 buscas/5 min por IP).
2. Escolhe itens, troca ou devolução (devolução só dentro do prazo), motivo, quantidade e foto (obrigatória p/ defeito).
3. Solicitação criada → e-mail "recebida" (SES).

Aprovar com itens de troca cria na Shopify um cupom de uso único no valor desses itens.

## Rodando localmente

```bash
bundle install
bin/rails db:setup      # cria banco local, tabelas espelhadas do painel e dados demo
bin/dev                 # http://localhost:3000
```

Login demo: `admin@mewtda.com` / `senha123` · página pública: `/troca/loja-demo`

Testes: `bin/rails test`

## Produção (Heroku: `mewtda-troca`)

O app tem **banco próprio** (Heroku Postgres do `mewtda-troca`), separado do mewtda-painel.
As tabelas têm a mesma estrutura das do painel, mas clientes e usuários são cadastrados aqui.

1. Variáveis: veja `.env.example`. `DATABASE_URL` vem do add-on Heroku Postgres e as `BUCKETEER_*`
   do add-on Bucketeer; configure também `RAILS_MASTER_KEY` (ou `SECRET_KEY_BASE`) e as da SES.
2. Migrations rodam automaticamente no deploy (fase `release` do `Procfile`).
3. Fotos e logos vão para o S3 do Bucketeer (`ACTIVE_STORAGE_SERVICE=amazon`).
4. O token Shopify de cada loja precisa de `read_orders` e `write_discounts`.
5. Jobs (e-mail) rodam no próprio processo (`:async`), sem worker separado.

## Diferenças em relação ao módulo do painel

- Transições de status validadas (pendente → aprovada/rejeitada → concluída).
- Cliente escolhe a **quantidade** de cada item; itens são identificados pela posição no pedido (não só pelo SKU, que pode faltar ou repetir).
- E-mails em HTML com layout, logo e a imagem de destaque do template (no painel a imagem não era enviada).
- Cupom criado com `context` (API Shopify 2026-07) no lugar do `customerSelection`, que foi descontinuado.
