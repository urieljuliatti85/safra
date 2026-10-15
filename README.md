# Safra

Sistema de planejamento de produção e compras para atacadista de hortifrúti e processadora de vegetais minimamente processados. Só o pedido é digitado: programação, produção por setor, aprontes e compras CEASA são calculados e versionados. Contexto de produto e regras de negócio em [`CLAUDE.md`](CLAUDE.md), dúvidas em aberto em [`docs/duvidas.md`](docs/duvidas.md).

## Requisitos

- Ruby 3.3.11 (veja `.ruby-version`; com rbenv: `rbenv install 3.3.11`)
- PostgreSQL 16 (local ou em Docker)
- Para os testes de sistema: Google Chrome

## Como rodar

```bash
# 1. Banco de dados em Docker. Sobe o container se ele já existe; senão, cria
docker start safra-pg 2>/dev/null || docker run -d --name safra-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16

# 2. Dependências, hook de pre-commit, banco e dados da semana de 12/10/2026
bin/setup --skip-server

# 3. Servidor (Rails + Tailwind em modo watch)
bin/dev
```

Abra <http://localhost:3000>. A primeira tela é a grade de pedidos; Programação, Produção, Compras e Conferência ficam no menu superior.

Nos próximos dias, só os passos 1 e 3 (o passo 1 é seguro repetir: se o container já estiver rodando, não muda nada).

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
| Pedidos | Grade por cliente e semana. Quantidade vazia ou 0 apaga a linha. "Importar planilha" lê xlsx, xls, ods e csv e mostra o que muda antes de gravar; ODT ou imagem (pedido colado como print, como o da Aurora) abre a imagem ao lado da grade para digitar olhando. |
| Programação | O que cada cliente pediu para um dia de entrega e quando cada item é produzido. |
| Produção | Lista do dia por setor, aprontes, envio aos setores em versões e diferença depois do envio. |
| Compras | Compra da CEASA por fornecedor, texto para WhatsApp e envio em versões. |
| Conferência | Alertas de fator, unidade, data e observações, e comparação com as planilhas de 13 e 15/10. |

Programação, Produção e Compras têm PDF (botão "PDF" ou `/production.pdf?date=2026-10-13`).

Não há login ainda: o app usa a única empresa cadastrada (Hortifruti Modelo).

## Importar pedidos de planilhas

Os clientes mandam o pedido em planilha (xlsx, xls, ods ou csv). Em **Pedidos > Importar planilha** você escolhe o cliente e envia o arquivo:

1. O sistema acha sozinho a linha das datas, a coluna do produto e a da unidade, e reconhece cada nome pelos apelidos já confirmados do cliente (depois pelo nome do produto).
2. A tela **Conferir planilha** mostra, por produto e por dia, a quantidade nova contra a que está no pedido hoje (novo, alterado, removido). Nomes novos pedem o produto.
3. **Importar no pedido** grava. Nomes novos viram apelido do cliente e são reconhecidos sozinhos da próxima vez.

Regras que ajudam a entender a conferência:

- "5 + 2" é somado (7) e avisado; número guardado como texto ("0.5") entra e é avisado; texto que não é número bloqueia a importação e aponta a linha e o dia.
- Linhas sem nenhuma quantidade são ignoradas. A planilha manda nos produtos que ela traz: célula vazia numa linha com outras quantidades apaga a linha do pedido.
- Com mais de uma aba (por exemplo, cotação e pedido), vale a que tem mais produtos com quantidade.
- Uma planilha por vez: processados e in natura costumam vir em arquivos separados.

Planilhas de exemplo ficam em `referencia/planilhas` (fora do git). Se essa pasta existir, os testes importam as planilhas reais e conferem que reproduzem os pedidos dos seeds.

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

## Solução de problemas

**Depois de atualizar a `main`, o app não sobe ou mostra "Migrations are pending".** Rode `bin/setup --skip-server`: instala os gems novos (`bundle install`) e aplica as migrations. É seguro repetir.

**`docker run` falha com "The container name /safra-pg is already in use".** O container já foi criado antes; não precisa criar de novo. Use `docker start safra-pg` (o passo 1 já faz isso sozinho). Para recomeçar do zero, apague e recrie: `docker rm -f safra-pg` e rode o passo 1 (os dados do container são perdidos, e `bin/setup --skip-server` recarrega os seeds).

**`docker run` falha com "port is already allocated" ou "address already in use" na 5432.** Outro PostgreSQL (instalado no Mac ou outro container) usa a porta. Veja quem: `lsof -nP -iTCP:5432 -sTCP:LISTEN`. Pare o outro servidor, ou use o dele (informe `DATABASE_HOST`, `DATABASE_USERNAME` e `DATABASE_PASSWORD`; o usuário precisa poder criar bancos).

**`Cannot connect to the Docker daemon`.** O Docker Desktop não está aberto. Abra o app e espere ele iniciar.

**`PG::ConnectionBad` ou "connection refused".** O PostgreSQL não está de pé. Com o container do passo 1: `docker start safra-pg` (ou `docker ps` para ver se ele existe). Se o servidor não for `localhost` com usuário e senha `postgres`, defina `DATABASE_HOST`, `DATABASE_USERNAME` e `DATABASE_PASSWORD`.

**`bin/dev` encerra na hora, com `css.1 | exited with code 0` e `sending SIGTERM to all processes`.** O processo do Tailwind (`css` no `Procfile.dev`) sai quando o `bin/dev` não roda num terminal interativo, como em segundo plano ou num botão "Run" do editor, e o foreman derruba o servidor junto. Rode `bin/dev` num terminal normal. Se precisar rodar sem terminal, use `bin/rails tailwindcss:watch[always]` na linha `css` do `Procfile.dev`.

**A página abre sem estilo.** O CSS não foi gerado: rode `bin/rails tailwindcss:build` (o `bin/dev` mantém o watcher ligado).

**`Address already in use` na porta 3000.** Há outro servidor rodando. Veja com `lsof -i :3000` e encerre, ou suba em outra porta: `bin/rails server -p 3001`.

**Os testes falham com erro de banco.** Prepare o banco de teste: `bin/rails db:test:prepare`. Os testes dependem dos seeds, que são carregados sozinhos no início da execução.

**Os testes de sistema não acham o navegador.** `bin/rails test:system` precisa do Google Chrome instalado.

## Fluxo de trabalho

Cada mudança vai em branch a partir da `main` atualizada, com PR e CI verde antes do merge. Commits são juntados antes do push para evitar vários deploys.

## Estrutura

- `app/models`: modelos multiempresa (`acts_as_tenant` por `Company`).
- `app/services`: `ProductionPlanner`, `PurchasePlanner`, `WeekOverview`, `PlanPublisher`, `PlanDiff`, `ConferenceChecker`, `OrderGridSaver` e, em `order_imports/`, a leitura de planilhas (`SheetReader`), o reconhecimento de nomes (`Matcher`), a prévia (`Preview`) e a gravação (`Applier`).
- `app/pdfs`: PDFs com Prawn (fonte Bricolage Grotesque embutida).
- `db/seeds_data`: dados reais da semana de 12/10/2026 em YAML.
- `referencia/planilhas`: planilhas originais dos clientes. Não são versionadas (dados de clientes).
- `prototipo/safra.html`: protótipo funcional, referência da lógica de cálculo.
- `PRODUCT.md` e `DESIGN.md`: produto e sistema visual (Calendário de safra).

## Deploy

Configuração do Kamal em `config/deploy.yml`, ainda com os valores padrão do Rails: precisa de servidor, domínio e credenciais antes do primeiro deploy.
