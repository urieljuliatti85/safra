# Safra

Sistema de planejamento de produção e compras para atacadista de hortifrúti e processadora de vegetais minimamente processados. Só o pedido é digitado: programação, produção por setor, aprontes e compras CEASA são calculados e versionados. Contexto de produto e regras de negócio em [`CLAUDE.md`](CLAUDE.md), dúvidas em aberto em [`docs/duvidas.md`](docs/duvidas.md).

## Requisitos

- Ruby 3.3.11 (veja `.ruby-version`; com rbenv: `rbenv install 3.3.11`)
- PostgreSQL 16 (local ou em Docker)
- Para os testes de sistema: Google Chrome

## Como rodar

```bash
# 1. Banco de dados (uma vez). Em Docker:
docker run -d --name safra-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16

# 2. Dependências, hook de pre-commit, banco e dados da semana de 12/10/2026
bin/setup --skip-server

# 3. Servidor (Rails + Tailwind em modo watch)
bin/dev
```

Abra <http://localhost:3000>. A primeira tela é a grade de pedidos; Programação, Produção, Compras e Conferência ficam no menu superior.

Nos próximos dias, só os passos 1 (se o container estiver parado: `docker start safra-pg`) e 3.

### Banco de dados

Em desenvolvimento e teste a conexão usa `localhost`, usuário `postgres`, senha `postgres`. Para outro servidor, defina `DATABASE_HOST`, `DATABASE_USERNAME` e `DATABASE_PASSWORD`.

Os dados vêm de `db/seeds_data/*.yml` (fornecedores, matérias-primas, cortes, produtos, clientes, apelidos e os pedidos da semana). O seed é idempotente e recria os pedidos da semana a cada execução:

```bash
bin/rails db:seed          # recarrega os cadastros e os pedidos
bin/rails db:reset         # apaga o banco e recomeça do zero
```

### Telas

| Tela | O que faz |
|---|---|
| Pedidos | Grade por cliente e semana. Quantidade vazia ou 0 apaga a linha. |
| Programação | O que cada cliente pediu para um dia de entrega e quando cada item é produzido. |
| Produção | Lista do dia por setor, aprontes, envio aos setores em versões e diferença depois do envio. |
| Compras | Compra da CEASA por fornecedor, texto para WhatsApp e envio em versões. |
| Conferência | Alertas de fator, unidade, data e observações, e comparação com as planilhas de 13 e 15/10. |

Programação, Produção e Compras têm PDF (botão "PDF" ou `/production.pdf?date=2026-10-13`).

Não há login ainda: o app usa a única empresa cadastrada (Hortifruti Modelo).

## Testes e qualidade

```bash
bin/rails test           # testes unitários e de integração (usam os seeds)
bin/rails test:system    # testes de navegador (Chrome headless)
bin/rubocop              # estilo
bin/ci                   # rubocop, auditorias de segurança e testes (sem os de sistema)
```

O relatório de comparação com as planilhas é gravado em `tmp/conferencia_planilhas.txt`. Para vê-lo no terminal: `VERBOSE_CONFERENCIA=1 bin/rails test test/services/conferencia_planilhas_test.rb`.

### Pre-commit

O `bin/setup` ativa o hook `.githooks/pre-commit`: Rubocop nos arquivos Ruby do commit e a suíte de testes quando o commit toca código. Sem o hook ativo (clone novo sem rodar o setup): `git config core.hooksPath .githooks`. Em emergência: `git commit --no-verify`.

## Fluxo de trabalho

Cada mudança vai em branch a partir da `main` atualizada, com PR e CI verde antes do merge. Commits são juntados antes do push para evitar vários deploys.

## Estrutura

- `app/models`: modelos multiempresa (`acts_as_tenant` por `Company`).
- `app/services`: `ProductionPlanner`, `PurchasePlanner`, `WeekOverview`, `PlanPublisher`, `PlanDiff`, `ConferenceChecker`, `OrderGridSaver`.
- `app/pdfs`: PDFs com Prawn (fonte Bricolage Grotesque embutida).
- `db/seeds_data`: dados reais da semana de 12/10/2026 em YAML.
- `referencia/planilhas`: planilhas originais dos clientes. Não são versionadas (dados de clientes).
- `prototipo/safra.html`: protótipo funcional, referência da lógica de cálculo.
- `PRODUCT.md` e `DESIGN.md`: produto e sistema visual (Calendário de safra).

## Deploy

Configuração do Kamal em `config/deploy.yml`, ainda com os valores padrão do Rails: precisa de servidor, domínio e credenciais antes do primeiro deploy.
