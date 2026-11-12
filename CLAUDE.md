# Safra

Sistema de planejamento de produção e compras para atacadista de hortifrúti e processadora de vegetais minimamente processados (higienizados, cortados e embalados) para clientes B2B: hospitais, refeitórios industriais, hotéis e supermercados.

Primeiro cliente. Objetivo de produto: vender depois para outros atacadistas e processadoras (multiempresa desde o início).

## Problema

Hoje os pedidos semanais chegam por cliente (Excel, PDF do sistema do cliente, print de tela) e são redigitados em três planilhas que dependem umas das outras:

1. `01 - PROG. DE PRODUÇÃO`: uma aba por dia, com os pedidos de cada cliente numa janela de 4 dias de entrega.
2. `02 - PLANILHA DE PRODUÇÃO`: uma aba por dia, com ordens por setor (descascador e aprontes em caixas, cortes em kg).
3. `03 - COMPRAS CEASA`: uma aba por compra (2 vezes por semana), lista digitada à mão por fornecedor.

Dores relatadas: (1) redigitação; (2) consolidação por produto e corte sem perder cliente e data; (3) cálculo de matéria-prima com fatores de perda; (4) alteração de pedido que precisa ser propagada a todas as relações; (5) conferência de quantidades, unidades e datas.

**Princípio do sistema: só o pedido é digitado. Programação, produção por setor, aprontes e compras são sempre calculados e versionados, nunca digitados.**

## Domínio

**A referência de domínio é a esteira operacional (`docs/esteira.md`)**, enviada pelo Gerente de Produção e Responsável Técnico em 27/10/2026. Ela está acima das planilhas: as planilhas mostram o resultado, a esteira mostra o processo.

**Só fatos confirmados.** Uma regra de negócio só entra no sistema depois de confirmada com o Gerente de Produção, etapa por etapa, na pauta `docs/duvidas.md` (resposta, fonte, data), e registrada em `docs/regras.md`, a única fonte de regra para o código. O ciclo completo (preparar, conversar, consolidar, decidir, implementar, validar) e a situação de cada etapa estão em `docs/roteiro.md`. Nada de regra deduzida das planilhas. O que o sistema faz hoje em cada etapa, comparado com a esteira, está em `docs/lacunas.md`.

O que o código já tem (abaixo) foi modelado a partir das planilhas, antes da esteira, e **não está confirmado**:

- **Matéria-prima** (`db/seeds_data/materias_primas.yml`): cenoura, batata, abóbora... com fornecedor e fatores.
- **Corte** (`cortes.yml`): cubos, cubinhos, ralado, palitos, picado, floretes... Cada corte define o setor e a antecedência de produção.
- **Produto processado = matéria-prima + corte** (ex.: cenoura + cubinhos). Produto in natura = a própria matéria-prima. Frutas descascadas ou embaladas são vendidas por unidade.
- **Grupos de pedido**: processados, in natura, frutas embaladas ou descascadas.
- **Apelido** (`apelidos.yml`): como cada cliente escreve cada produto ("Batata Inglesa Cubos Pequenos" → batata + cubinhos). Confirmado uma vez, reconhecido sempre.
- **Setores de produção**: descascados inteiros, cortes manuais, ralados/picados/rodelas, palitos, cubinhos, frutas.

### Cálculo e regras de produção

Não há fórmula nem regra de produção confirmada. O que o código faz hoje (antecedência por corte, domingo para sábado, cobertura de cada compra, arredondamento único das embalagens, estoque abatendo só a compra) saiu das planilhas e está descrito, com arquivo e linha, em `docs/lacunas.md`. **A esteira vem antes do código:** no passo "Decidir" de cada etapa, cálculo deduzido das planilhas é removido e refeito a partir de `docs/regras.md`, e não ajustado (`docs/roteiro.md`). O que ainda vem das planilhas está listado no topo de `docs/lacunas.md`. A ordem de cálculo que a esteira descreve (saldo de produto pronto, fator, saldo de matéria-prima, arredondamento por produto) é um exemplo ilustrativo do documento e também está na pauta. As regras observadas nas planilhas estão em `docs/analise-planilhas.md`, como observação e não como regra.

## Stack e convenções

- Ruby on Rails 8, PostgreSQL, Hotwire (Turbo + Stimulus), Solid Queue, Propshaft, importmap. Sem React.
- Monólito modular. Multiempresa com `acts_as_tenant` (`Company`), autorização com Pundit.
- Código, tabelas e classes em inglês; interface, mensagens e seeds em português do Brasil.
- Quantidades em `decimal(10,3)`. Datas sem hora (`date`). Fuso `America/Sao_Paulo`.
- PDFs (programação, produção por setor, compras) com Prawn. Interface usável no celular (PWA).
- Testes com Minitest. Os números de `referencia_planilhas.yml` são fixtures: registram o que as planilhas mostraram, não uma regra confirmada. Diferença entre o sistema e eles vira pergunta na pauta (`docs/duvidas.md`), não regra nova.

## Modelo de dados (MVP)

```
Company
Supplier(name)
RawMaterial(code, name, supplier, multiply_factor, kg_per_package, kg_per_peeled_box, purchase_package)
Cut(code, name, sector, lead_days)
Product(code, name, group: processed|raw|fruit, raw_material, cut, unit)
ProductionRule(product, lead_days)               # exceção por produto
Customer(code, name, short_name)
CustomerAlias(customer, name_in_order, product)
Order(customer, week_start) / OrderLine(order, product, delivery_date, quantity, unit, note)
StockCount(raw_material, date, kg)
PurchaseDay(date)
ProductionPlan(date, version, sent_at) / ProductionPlanItem(product, quantity, unit, breakdown jsonb)
PurchasePlan(date, version, sent_at)   / PurchasePlanItem(raw_material, kg, packages, breakdown jsonb)
```
Planos são gerados por um serviço (`ProductionPlanner`, `PurchasePlanner`) e salvos como versão quando "enviados aos setores". Alteração de pedido depois do envio mostra a diferença para a versão enviada.

## Escopo do MVP

Dentro: cadastros (carregados dos seeds), lançamento de pedidos em grade por cliente, importação das planilhas, PDFs e imagens dos clientes, programação, produção por setor, aprontes, compras CEASA por fornecedor (texto para WhatsApp), estoque simples, versões e avisos de alteração, conferência, PDFs.

Fora: portal do cliente, leitura de pedido por foto/WhatsApp com IA, nota fiscal, preços, rastreabilidade de lotes, integração com ERP.

## Arquivos

- `db/seeds_data/`: empresa fictícia "Hortifruti Modelo" (semana de 12/10/2026) em YAML, para testes e desenvolvimento. Mesma estrutura dos dados reais, com nomes trocados.
- `docs/dados/`: os dados reais, na mesma estrutura. Entram com `SEEDS_DIR=docs/dados` (README, "Dados reais").
- `docs/prototipo/safra.html`: protótipo funcional (abrir no navegador). O cálculo dele foi modelado a partir das planilhas, antes da esteira: não é referência de regra (a referência é `docs/regras.md`).
- `docs/referencia/planilhas/`: planilhas originais e pedidos dos clientes. `docs/referencia/esteira/`: documento original da esteira.
- `docs/roteiro.md`: roteiro de execução, papel de cada documento e situação de cada etapa. Comece por aqui.
- `docs/esteira.md`: esteira operacional, referência de domínio.
- `docs/regras.md`: regras confirmadas, com a referência da resposta que as confirmou.
- `docs/duvidas.md`: pauta com o Gerente de Produção, por etapa da esteira, com as respostas confirmadas.
- `docs/lacunas.md`: o que o sistema faz hoje em cada etapa, comparado com a esteira.
- `docs/analise-planilhas.md`: o que as planilhas de outubro/2026 contêm (observação, não regra).
- `.claude/skills/README.md`: skills de revisão e QA do Claude Code (`.claude/skills/`), quando usar cada uma e por que só rodam quando chamadas.

## O repositório é público

O `safra` é público: qualquer pessoa lê os arquivos, o histórico, as mensagens de commit e os títulos, descrições e comentários de PR. **Nome, dado ou processo de cliente real não entra no `safra`**, nem em arquivo, nem em commit, nem em PR. Isso vale para o nome da empresa cliente, dos clientes dela, de fornecedores e de pessoas, números de documentos (AF, unidade), quantidades reais e o conteúdo das conversas com o Gerente de Produção.

Esse conteúdo vive no repositório **privado `safra-dominio`**, clonado em `docs/` (o `.gitignore` do `safra` ignora a pasta): os documentos de domínio (`esteira.md`, `duvidas.md`, `regras.md`, `roteiro.md`, `lacunas.md`, `analise-planilhas.md`, `mudancas.md`), os dados reais (`dados/`), o protótipo e as planilhas originais (`referencia/`). Os caminhos `docs/...` deste arquivo continuam valendo na máquina de desenvolvimento.

- O `safra-dominio` **não tem `.github/`** e o Actions fica desligado nele: não há créditos de Actions para repositório privado. Nunca crie workflow lá.
- Mudou algo em `docs/`? Commit e push no `safra-dominio` na mesma hora (com a permissão de sempre), para o GitHub ficar igual ao computador.
- No `safra`, código, testes, seeds e comentários usam só a empresa fictícia "Hortifruti Modelo" e os clientes dela (Hospital Bom Pastor, Hospital Horizonte Norte e Sul, Grupo Aurora, Nutrir · Usina Litoral). Regra citada no código aparece pelo número (R1.20, D14), sem o nome real.
- Na dúvida, antes de commitar no `safra`: isso identifica a empresa cliente, um cliente dela ou uma pessoa? Se sim, vai para o `safra-dominio`.
- Commits do `safra` e do `safra-dominio` usam o e-mail `noreply` do GitHub, configurado no `git config` local de cada um.

## Pull requests

Todo PR ganha uma entrada em `docs/mudancas.md` (no `safra-dominio`), com commit no `safra-dominio` junto com o PR: o que mudou para quem usa, por quê, dados gravados e como reverter. Regra e formato no topo do arquivo; o modelo de descrição está em `.github/pull_request_template.md`.
