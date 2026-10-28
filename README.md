# Safra

Sistema de planejamento de produção e compras para atacadista de hortifrúti e processadora de vegetais minimamente processados. Só o pedido é digitado: programação, produção por setor, aprontes e compras CEASA são calculados e versionados. Contexto de produto e regras de negócio em [`CLAUDE.md`](CLAUDE.md), processo de referência em [`docs/esteira.md`](docs/esteira.md) e pauta com o Gerente de Produção em [`docs/duvidas.md`](docs/duvidas.md).

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

Abra <http://localhost:3000> e entre com um dos usuários de desenvolvimento (veja "Acesso e papéis"). Quem é do escritório cai no Painel; Pedidos, Programação, Produção, Compras e Conferência ficam no menu superior.

Nos próximos dias, só os passos 1 e 3 (o passo 1 é seguro repetir: se o container já estiver rodando, não muda nada).

### Banco de dados

Em desenvolvimento e teste a conexão usa `localhost`, usuário `postgres`, senha `postgres`. Para outro servidor, defina `DATABASE_HOST`, `DATABASE_USERNAME` e `DATABASE_PASSWORD`.

Os dados vêm de `db/seeds_data/*.yml` (fornecedores, matérias-primas, cortes, produtos, clientes, apelidos e os pedidos da semana). O seed **só cria o que falta**: nunca sobrescreve um cadastro editado na tela nem apaga pedidos já lançados, então é seguro rodar de novo, inclusive em produção. Os pedidos da semana entram só na primeira carga de cada cliente.

```bash
bin/rails db:seed          # cria o que falta (cadastros, pedidos da primeira carga e usuários de desenvolvimento)
bin/rails db:reset         # apaga o banco e recomeça do zero (precisa de nenhum servidor ou editor com o banco aberto)
```

### Telas

| Tela | O que faz |
|---|---|
| Painel | Página inicial do escritório e do administrador: as quatro etapas do dia (Pedidos, Programação, Produção, Compras) com o estado de cada uma em palavras, o que falta, o que mudou depois do envio, e a faixa da semana. Só lê o que as outras telas já calculam; cada etapa leva à sua tela. A Produção continua caindo na própria tela. |
| Pedidos | Grade por cliente e semana (da segunda até a segunda seguinte; data fora disso é recusada). Quantidade vazia ou 0 apaga a linha. "Importar planilha" lê xlsx, xls, ods e csv e mostra o que muda antes de gravar; ODT ou imagem (pedido colado como print, como o da Aurora) abre a imagem ao lado da grade para digitar olhando. |
| Programação | O que cada cliente pediu para um dia de entrega e quando cada item é produzido. |
| Produção | Lista do dia por setor (filtro por setor e aprontes, na tela e no PDF), envio aos setores em versões, diferença depois do envio e histórico de envios. Quem trabalha na produção vê só a versão enviada. **Avisos no celular** (veja "Avisos de produção no celular") avisam, por setor, quando sai versão nova. |
| Compras | Compra da CEASA por fornecedor, texto para WhatsApp e envio em versões. |
| Estoque | Contagem da câmara fria por matéria-prima e dia, em kg. A compra da CEASA abate o que está contado; a sobra segue para a compra seguinte, até uma contagem nova. Campo vazio é não contado, 0 é câmara vazia. |
| Conferência | Alertas de fator, unidade, data e observações. **Comparar com as planilhas** mostra, semana a semana, os números das planilhas feitas à mão ao lado do que o Safra calcula, com o motivo de cada diferença (veja "Validar o teste com as planilhas"). |
| Cadastros | Matérias-primas (fator de perda, peso da embalagem, fornecedor) numa grade editável em lote, produtos, clientes com os apelidos dos produtos e fornecedores. |
| Regras | Antecedência da produção por corte e por produto, do in natura e os dias de compra na CEASA. **Ver efeito sem salvar** mostra o placar contra as planilhas antes e depois, item por item. |

Programação, Produção e Compras têm PDF (botão "PDF" ou `/production.pdf?date=2026-10-13`).


## Acesso e papéis

O sistema exige login. Cada usuário pertence a uma empresa e só enxerga os dados dela (multiempresa com `acts_as_tenant`).

| Papel | O que pode |
|---|---|
| Administrador | Tudo, mais gerenciar usuários e ver o histórico (no menu da conta, ao lado do nome). |
| Escritório | Painel, pedidos, importação, programação, produção, compras, conferência, estoque (com a compra ao lado), regras, cadastros e envio aos setores. |
| Produção | Vê Programação, Produção e os PDFs, e conta a câmara fria em Estoque (sem ver colunas nem avisos de compra). Não altera mais nada e não vê o botão de enviar. |

**Usuários de desenvolvimento** (criados por `bin/setup` ou `bin/rails db:seed`, só em desenvolvimento e teste), todos com a senha `safra-dev-123`:

- `admin@safra.local` (Administrador)
- `escritorio@safra.local` (Escritório)
- `producao@safra.local` (Produção)

Se o banco já existia antes do login, rode `bin/rails db:seed` para criá-los.

**Dono da plataforma.** Além do papel dentro da empresa, um usuário pode ser o dono da plataforma: só ele cria, renomeia e suspende empresas (menu da conta > **Empresas**). Não é um papel que se conceda pela tela, e ele **não vê os dados** das outras empresas. O primeiro administrador do seed (`admin@safra.local` em desenvolvimento, `SAFRA_ADMIN_EMAIL` em produção) é o dono da plataforma. Num banco que já existia, a migration promove o primeiro administrador.

**Em produção** não há usuário de exemplo. O primeiro administrador sai do seed, com `SAFRA_ADMIN_EMAIL` e `SAFRA_ADMIN_PASSWORD` definidos ao rodar `bin/rails db:seed`; a senha vale só até o primeiro acesso. Depois, o administrador cadastra os demais em **Usuários**.

**Senha provisória.** Ao criar um usuário ou redefinir a senha, o sistema gera uma senha provisória e mostra **uma única vez**, na tela, para o administrador repassar. A pessoa é obrigada a trocar no primeiro acesso, e os acessos abertos dela caem. Não há recuperação por e-mail: quem esquecer a senha pede ao administrador uma nova. Desativar um usuário também encerra as sessões dele.

## Cadastros

Em **Cadastros** a equipe mantém o que antes só vinha por seed:

- **Matérias-primas:** uma grade para completar vários de uma vez: fornecedor, embalagem de compra (caixa, saco, kg, unidade), kg por embalagem, fator de perda e kg por caixa descascada. Os filtros **Incompletas** (sem fator em item processado, ou sem peso da embalagem em item comprado por caixa ou saco) e **Usadas nos pedidos** mostram por onde começar, e o placar de compras contra as planilhas importadas sobe conforme o cadastro fica completo. Sem o fator, a compra do item processado não é convertida; sem o peso da embalagem, não vira número de caixas ou sacos.
- **Produtos:** grupo (processado, fruta ou in natura), matéria-prima, corte e unidade. Processado e fruta exigem corte; in natura não tem.
- **Clientes:** nome, nome curto e como o pedido chega, mais os **apelidos** dos produtos como o cliente os escreve (a importação usa a lista; nomes novos entram sozinhos).
- **Cortes:** como o produto processado é feito (cubos, cubinhos, ralado...). O corte define o **setor** (a lista de produção em que o produto aparece: descascados inteiros, cortes manuais, ralados e picados, palitos, cubinhos ou frutas) e a **antecedência** da produção. Uma empresa nova começa com os cortes padrão e cria os seus. O nome do setor é um só por setor; trocar o setor de um corte em uso muda onde os produtos dele aparecem na produção.
- **Fornecedores.**

O código de cada cadastro é gerado do nome (`Batata roxa` vira `batata_roxa`) e não muda depois, porque seeds, planilhas de referência e apelidos apontam para ele. Decimais aceitam vírgula (`1,35`), e campo vazio fica sem valor. Excluir é barrado quando há dependências (matéria-prima ou corte com produtos, produto ou cliente com pedidos, fornecedor com matérias-primas). As mensagens do sistema estão em português.

## Empresas (multiempresa)

Cada empresa tem os seus usuários, cadastros, pedidos e histórico, isolados das outras. Em **Empresas** o dono da plataforma:

- **Cria uma empresa** com o primeiro administrador (senha provisória mostrada uma vez, troca obrigatória no primeiro acesso) e escolhe os cadastros iniciais: **só os cortes padrão** (a empresa começa vazia) ou **uma cópia do catálogo** de outra empresa (cortes, fornecedores, matérias-primas com fatores e peso da embalagem, produtos e exceções de antecedência). Clientes, apelidos, pedidos, estoque, dias de compra e usuários nunca são copiados. A montagem inicial não aparece no histórico da empresa nova.
- **Renomeia** e **suspende**: ninguém da empresa suspensa entra, as sessões abertas caem e as tentativas ficam no histórico como "empresa suspensa". Os dados ficam guardados e voltam ao reativar. Não é possível suspender a própria empresa, e não há exclusão de empresa.

O e-mail de cada usuário é único em todo o sistema, e o login identifica a empresa pelo usuário.

## Histórico (quem alterou o quê)

O sistema registra, com a pessoa, a data, o IP e o **antes e o depois** de cada campo: cadastros (matérias-primas, produtos, clientes, apelidos, fornecedores, cortes), regras de antecedência e dias de compra, contagens de estoque, linhas de pedido, importações, envios de produção e compra, usuários (papel, ativo, senha redefinida, sem nunca guardar a senha) e as entradas, saídas e tentativas erradas de login.

- **Só o administrador vê**, em **Histórico** (menu da conta). Dá para filtrar por pessoa, por tipo, por nome e por data, e abrir o histórico de um cadastro só pelo link "Histórico deste cadastro" na tela de edição.
- O que veio de uma mesma ação (um "Salvar tudo", uma importação) aparece junto, como uma linha que se abre.
- O histórico **só se lê**: ninguém edita nem apaga, e o próprio código recusa.
- **"Ver efeito sem salvar"** (simulação de regras) não deixa registro, porque o registro é desfeito junto com a simulação.
- Só entra o que passa pelo sistema com alguém logado. Seed, console e alterações direto no banco **não** são registrados, e tentativa de login com e-mail que não existe também não (não há empresa para atribuir).
- Os registros não são apagados sozinhos: a tabela `audit_logs` só cresce. Se um dia pesar, o caminho é arquivar por data.

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
- A planilha precisa caber numa semana de pedido, da segunda até a segunda seguinte. Se passar disso (por exemplo, de sexta a terça), a conferência avisa e não deixa importar: separe em uma planilha por semana.
- **Desfazer** (pílula na grade ou na tela da importação) devolve o pedido ao que era antes da planilha nos produtos e dias que ela tocou, apaga os apelidos que ela criou e reabre a importação. Alterações feitas no pedido depois da importação são listadas antes e se perdem.

Planilhas de exemplo ficam em `referencia/planilhas` (fora do git). Se essa pasta existir, os testes importam as planilhas reais e conferem que reproduzem os pedidos dos seeds.

## Validar o teste com as planilhas

Enquanto o Safra roda em paralelo com as planilhas, a equipe continua preenchendo a `01 - PROG. DE PRODUÇÃO`, a `02 - PLANILHA DE PRODUÇÃO` e a `03 - COMPRAS CEASA`. Em **Conferência > Comparar com as planilhas > Importar planilhas** você envia os arquivos como estão (ods, xlsx ou xls) e escolhe a semana:

1. O Safra lê só as abas da semana (a data vem do nome da aba, como `TERÇA 13-10-26`).
   - **01:** blocos por cliente e dia de entrega (`BOM PASTOR ( TER – 13/10 )`), comparados com os pedidos lançados no Safra. Cada cliente e dia vale pela aba mais recente que o traz.
   - **02:** blocos descascador e aprontes (caixas) e cortes (kg), comparados com a produção calculada.
   - **03:** cada matéria-prima com a quantidade (`20 CX`, `10 SC`, `45 KG`, `500 Gr`), comparada com a compra calculada.
   - Instruções, separadores e linhas sem quantidade ficam de fora. Importar o mesmo dia de novo troca os números.
2. Os nomes são reconhecidos pelo cadastro (`ABÓBORA CUBOS` é Abóbora em cubos; `BAROA DESCASCADA` é a matéria-prima baroa; `BATATA INTEIRA DESC.` é Batata inteira descascada; `BOM PASTOR` é o cliente). Nome que o Safra não reconhece aparece no topo para ligar a um produto, matéria-prima ou cliente (ou tirar da comparação); a ligação vale para as próximas semanas. As ligações iniciais estão em `db/seeds_data/apelidos_planilhas.yml` (por exemplo, `CENTRAL` é o Hospital Horizonte Norte).
3. A comparação mostra o placar da semana (itens iguais na programação, na produção e nas compras) e, para cada diferença, o motivo provável:
   - **Programação:** data de entrega diferente, lançado em outro cliente, outro produto da mesma matéria-prima, pedido em outra unidade.
   - **Produção e compras:** outro dia de produção (o mesmo número aparece num dia vizinho), falta de fator, de kg por embalagem ou de kg por caixa no cadastro (com link para completar), estoque abatido, diferença de 1 embalagem, pedido em outra unidade, dia que não é de compra, nenhum pedido que leve ao item.
   - O que sobra fica como **sem regra que explique**, em vermelho: é o que precisa de conversa com a equipe. O descascador aparece, mas ainda não é comparado.
4. **Explicar** abre uma nota em cada diferença ("o cliente mudou o pedido por telefone"). A diferença passa a contar como explicada, com o nome de quem escreveu. Se os números da linha mudarem depois (planilha nova ou pedido alterado), a nota aparece como antiga e a diferença volta a contar como aberta.
5. **PDF da semana** traz o placar, as diferenças por motivo e, dia a dia, cada diferença (as sem explicação em vermelho), para mostrar à empresa. Os dias e itens iguais entram só na contagem.

As planilhas de 13 e 15/10/2026 (`db/seeds_data/referencia_planilhas.yml`) entram pelo seed quando o dia ainda não foi importado; os testes usam esses números como fixture.

## API para integrações (v1)

JSON sob `/api/v1`, documentada em **`/api-docs`** (Swagger UI; o arquivo OpenAPI fica em `swagger/v1/swagger.yaml`).

- **Chave por empresa.** O administrador cria e revoga em **Chaves de API** (menu da conta). O token (`safra_...`) aparece **uma única vez**; no banco fica só o hash (SHA-256). Duas permissões: *só leitura* e *leitura e escrita*. Cada chave enxerga só os dados da própria empresa; chave revogada ou empresa suspensa recebe 401. Envie `Authorization: Bearer <chave>`; guarde a chave como segredo (nunca em código nem em chat).
- **Leitura:** cadastros (`customers`, `products`, `raw_materials`, `cuts`, `suppliers`), pedido de um cliente em uma semana (`GET /orders`), programação, produção e compras já calculadas, com a versão enviada e o que mudou depois (`/schedule`, `/production`, `/purchases`) e estoque (`/stock`).
- **BI e painéis:** tabelas planas de um período (`from` e `to`, padrão 14 dias a partir da segunda-feira desta semana, no máximo 92 dias) em `/api/v1/bi/schedule`, `/production`, `/purchases` e `/losses`, em JSON ou CSV (acrescente `.csv` à URL). Perda = kg in natura − kg processado (só produtos em kg com fator cadastrado). A chave vai no cabeçalho `Authorization`: no Power BI use *Web* com cabeçalhos HTTP; no Looker Studio, um conector ou o Google Sheets via Apps Script (`UrlFetchApp`); no Metabase, uma fonte de dados que leia o CSV ou um script que carregue a tabela. Use uma chave só de leitura.
- **Logística e roteirização:** `GET /deliveries?date=AAAA-MM-DD` traz uma parada por cliente com entrega no dia: endereço (rua e número, bairro, cidade, UF, CEP, latitude e longitude opcionais), janela de recebimento, instruções e a carga (`kg_total` só do que é pedido em kg; outras unidades em `other_units`; linhas por produto). `missing_address` lista quem entrega sem rua e cidade cadastradas. Com `.csv`, uma linha por parada para importar em roteirizadores. O endereço é cadastrado em **Cadastros > Clientes** e também sai em `GET /customers`.
- **Escrita:** `PUT /orders` (linhas do pedido de uma semana, com as mesmas regras da grade: quantidade 0 apaga, linha inválida não grava nada) e `PUT /stock` (contagem da câmara fria). Passam pelos mesmos serviços das telas (`OrderGridSaver`, `StockCountSaver`) e entram no **Histórico** como "API: <nome da chave>".
- **Erros** sempre como `{ "error": { "code", "message", "details" } }`; limite de 300 requisições por minuto por chave.
- **Fora desta versão:** gravar a observação da linha, criar cadastros e enviar produção ou compra aos setores (continuam nas telas).

Os specs de request em `spec/requests/api/v1` (RSpec com rswag) documentam e testam cada endpoint. Depois de mudar a API, regere o OpenAPI e commite: `RAILS_ENV=test bundle exec rake rswag:specs:swaggerize`. O CI recusa o PR se o arquivo estiver desatualizado.

## Testes e qualidade

```bash
bin/rails test           # testes unitários e de integração (usam os seeds)
bin/rails test:system    # testes de navegador (Chrome headless)
bundle exec rspec        # specs de request da API v1 (rswag; o resto do app é Minitest)
bin/rubocop              # estilo
bin/ci                   # rubocop, auditorias de segurança e testes (sem os de sistema)
```

O relatório de comparação com as planilhas (todas as importadas) é gravado em `tmp/conferencia_planilhas.txt`. Para vê-lo no terminal: `VERBOSE_CONFERENCIA=1 bin/rails test test/services/conferencia_planilhas_test.rb`.

### Pre-commit

O `bin/setup` ativa o hook `.githooks/pre-commit`: Rubocop nos arquivos Ruby do commit, a suíte Minitest e os specs da API quando o commit toca código. Sem o hook ativo (clone novo sem rodar o setup): `git config core.hooksPath .githooks`. Em emergência: `git commit --no-verify`.

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

Cada mudança vai em branch a partir da `main` atualizada, com PR e CI verde antes do merge. Commits são juntados antes do push para evitar vários deploys. Mudança de comportamento ganha uma entrada em `docs/mudancas.md` (o que mudou, o que fica no banco e como reverter).

## Estrutura

- `app/models`: modelos multiempresa (`acts_as_tenant` por `Company`), `User` e `Session`.
- `app/models/concerns/auditable.rb` e `AuditLog`: histórico de alterações.
- `app/controllers/api/v1`, `app/presenters/api_presenter.rb` e `ApiToken`: API de integração; `spec/` e `swagger/`: specs rswag e o OpenAPI gerado.
- `app/policies`: autorização com Pundit, negada por padrão e liberada por papel (`allow :admin, :office, to: ...`).
- `app/services`: `ProductionPlanner`, `PurchasePlanner`, `WeekOverview`, `PlanPublisher`, `PlanDiff`, `ConferenceChecker`, `OrderGridSaver`, `SheetComparison` (planilhas × Safra, com os motivos e as notas), em `reference_sheets/` a leitura das planilhas 01, 02 e 03 (`Reader`, `Matcher`, `Importer`) e, em `order_imports/`, a leitura de planilhas (`SheetReader`), o reconhecimento de nomes (`Matcher`), a prévia (`Preview`) e a gravação (`Applier`).
- `app/pdfs`: PDFs com Prawn (fonte Bricolage Grotesque embutida).
- `db/seeds_data`: dados reais da semana de 12/10/2026 em YAML.
- `referencia/planilhas`: planilhas originais dos clientes. Não são versionadas (dados de clientes).
- `prototipo/safra.html`: protótipo funcional, referência da lógica de cálculo.
- `PRODUCT.md` e `DESIGN.md`: produto e sistema visual (Calendário de safra).

## Deploy na Railway

O app roda na Railway a partir do `Dockerfile`, com PostgreSQL da própria Railway e um volume para as imagens dos pedidos. `railway.json` define o build por Dockerfile e o healthcheck em `/up`.

**Serviços do projeto `safra`:**

| Serviço | O que é |
|---|---|
| `safra` | O app (GitHub `main`, deploy automático a cada merge). |
| `Postgres` | O banco. A Railway entrega `DATABASE_URL`; o `config/database.yml` usa essa URL para o banco do app e cria mais três no mesmo servidor (`safra_production_cache`, `_queue` e `_cable`, do Solid Cache, Queue e Cable). |
| Volume em `/rails/storage` | As imagens dos pedidos (Active Storage em disco). |

**Variáveis do serviço `safra`:**

| Variável | Valor |
|---|---|
| `DATABASE_URL` | Referência ao Postgres: `${{Postgres.DATABASE_URL}}`. |
| `SECRET_KEY_BASE` | Segredo longo e aleatório (`bin/rails secret`). Vale no lugar do `RAILS_MASTER_KEY`. |
| `PORT` | `80`, porta em que o Thruster escuta. |
| `RAILWAY_RUN_UID` | `0`, para o app conseguir gravar no volume (que a Railway monta como root). |
| `SAFRA_ADMIN_EMAIL` | E-mail do primeiro administrador. |
| `SAFRA_ADMIN_PASSWORD` | Senha provisória dele (vale até o primeiro acesso). |
| `SOLID_QUEUE_IN_PUMA` | `true`. Sem ele nenhuma tarefa em segundo plano roda (os avisos de produção ficam parados na fila). |
| `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` | Chaves dos avisos no celular (veja abaixo). Sem elas o painel de avisos não aparece. |

Segredos (`SECRET_KEY_BASE`, `SAFRA_ADMIN_PASSWORD`, `VAPID_PRIVATE_KEY`) entram só no painel da Railway, nunca no git.

**Avisos de produção no celular.** Quando o escritório envia uma versão aos setores, quem ativou os avisos recebe uma notificação só se algum dos setores que escolheu mudou (na v1, se tem itens nele). O texto traz o que mudou ("Cenoura ralada: 3 → 7 kg") e o toque abre a produção do dia. Quem enviou não recebe o próprio aviso. Para ligar:

1. Gere o par de chaves uma vez: `ruby -e 'require "web-push"; k = WebPush.generate_key; puts k.public_key, k.private_key'`.
2. Coloque `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` e `VAPID_SUBJECT` (um `mailto:` de quem responde pelo sistema) e `SOLID_QUEUE_IN_PUMA=true` no serviço `safra`. Trocar o par de chaves depois obriga todo mundo a ativar de novo.
3. Cada pessoa abre **Produção**, vai em "Avisos no celular", escolhe os setores e toca em "Ativar avisos neste aparelho". No iPhone o aviso só funciona com o Safra instalado na tela inicial (Compartilhar > Adicionar à Tela de Início, iOS 16.4 ou mais).

O envio não tem confirmação de leitura: com o celular sem internet o aviso atrasa ou não chega, então a lista na tela continua sendo a fonte de verdade.

**Primeiro deploy.** O container roda `db:prepare` ao subir: cria os bancos, carrega os esquemas e roda o seed, que cria a empresa, os cadastros e o primeiro administrador. Entre com `SAFRA_ADMIN_EMAIL` e a senha provisória; o sistema pede para trocá-la. Depois, cadastre os demais em **Usuários**. As variáveis `SAFRA_ADMIN_*` podem ser removidas depois que o administrador existe.

**Atualizações.** Cada merge na `main` publica sozinho. A Railway **não espera o CI** hoje (a opção de aguardar as verificações do GitHub, `checkSuites`, está desligada no serviço `safra`; conferido em 17/10/2026), e o GitHub não bloqueia o merge por conta do plano. Por isso só mergeie com o CI verde. Para trancar de vez, ligue essa opção na origem do serviço `safra`. Migrations rodam no `db:prepare` da subida. Para rodar um comando no servidor (por exemplo `bin/rails db:seed` ou o console): `railway ssh` ou o painel da Railway.

**Migrations sem pausa.** A migration roda no início do container novo, enquanto a versão anterior ainda atende. Toda migration precisa, portanto, funcionar com o código antigo: primeiro um PR que adiciona (coluna, tabela, índice) e, com ele no ar, outro que passa a usar ou que remove o que ficou sem uso. Não renomeie nem apague coluna no mesmo PR que muda o código que a lê. Preencher dados na migration é aceitável se for rápido: ela roda antes do app responder e conta no tempo do healthcheck (120 s).

**Saúde do app.** `/up` diz só que o Rails subiu. `/ready` responde 200 quando o banco responde e 503 quando não, sem login e sem detalhes. O healthcheck da Railway usa `/ready` (`railway.json`): uma versão que não alcança o banco não entra no ar, e a anterior segue atendendo.

**Voltar atrás.** Para desfazer um PR específico (por exemplo, a Hortifruti Modelo não quer mais uma mudança), veja `docs/mudancas.md`: cada PR recente tem o que mudou, o que fica no banco e como reverter. Para uma emergência, no painel da Railway: projeto `safra` > serviço `safra` > Deployments > o último deploy que funcionava > Rollback (ou Redeploy). O código volta; o banco não, porque migrations não são desfeitas. Com a regra acima o código antigo funciona com o banco novo, então voltar é seguro, exceto depois de uma migration que removeu algo. Os dados do banco e do volume não mudam. O rollback vale até o próximo merge: ele publica a `main` de novo, então corrija o problema na `main` antes de mergear qualquer coisa.

**Limite conhecido.** O volume só pode ser montado em uma instância: não escale o app para mais de uma réplica enquanto as imagens estiverem em disco local. Para várias réplicas, mover o Active Storage para um bucket S3.

**Kamal.** O `config/deploy.yml` continua com os valores padrão do Rails e não está em uso.
