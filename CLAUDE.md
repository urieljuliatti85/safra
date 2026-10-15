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

- **Matéria-prima** (`db/seeds_data/materias_primas.yml`): cenoura, batata, abóbora... com fornecedor e fatores.
- **Corte** (`cortes.yml`): cubos, cubinhos, ralado, palitos, picado, floretes... Cada corte define o setor e a antecedência de produção.
- **Produto processado = matéria-prima + corte** (ex.: cenoura + cubinhos). Produto in natura = a própria matéria-prima. Frutas descascadas ou embaladas são vendidas por unidade.
- **Grupos de pedido**: processados, in natura, frutas embaladas ou descascadas.
- **Apelido** (`apelidos.yml`): como cada cliente escreve cada produto ("Batata Inglesa Cubos Pequenos" → batata + cubinhos). Confirmado uma vez, reconhecido sempre.
- **Setores de produção**: descascados inteiros, cortes manuais, ralados/picados/rodelas, palitos, cubinhos, frutas.

### Fórmulas (da tabela de conversões)

```
kg in natura          = kg processado × fator_multiplicar
embalagens a comprar  = ROUND(kg in natura ÷ kg_por_embalagem)   # caixa ou saco
caixas para aprontar  = ROUND(kg processado ÷ kg_por_caixa_descascada)
```
Folhas (alface, couve) são compradas em kg. Matéria-prima sem fator gera alerta, não erro.

### Regras de produção (hipótese, a confirmar)

- Cada linha de pedido tem data de entrega. A data de produção = entrega − antecedência (do corte, com exceção por produto).
- Comparando com as planilhas de 13 e 15/10/2026: ralados, picados e rodelas batem 100% com produção **no dia da entrega**; cubos, cubinhos e palitos variam (véspera, ou véspera mais o dia seguinte).
- Domingo não tem produção: cai para sábado.
- Cada compra na CEASA abastece a produção desde o dia da compra até a véspera da compra seguinte. Estoque da câmara fria é abatido antes.
- Dúvidas em aberto: `docs/duvidas.md`.

## Stack e convenções

- Ruby on Rails 8, PostgreSQL, Hotwire (Turbo + Stimulus), Solid Queue, Propshaft, importmap. Sem React.
- Monólito modular. Multiempresa com `acts_as_tenant` (`Company`), autorização com Pundit.
- Código, tabelas e classes em inglês; interface, mensagens e seeds em português do Brasil.
- Quantidades em `decimal(10,3)`. Datas sem hora (`date`). Fuso `America/Sao_Paulo`.
- PDFs (programação, produção por setor, compras) com Prawn. Interface usável no celular (PWA).
- Testes com Minitest. Os números de `referencia_planilhas.yml` são fixtures: o sistema deve chegar neles ou a diferença deve ser explicada por uma regra cadastrada.

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

Dentro: cadastros (carregados dos seeds), lançamento de pedidos em grade por cliente, importação dos Excel de Bom Pastor e Horizonte, programação, produção por setor, aprontes, compras CEASA por fornecedor (texto para WhatsApp), estoque simples, versões e avisos de alteração, conferência, PDFs.

Fora: portal do cliente, leitura de pedido por foto/WhatsApp com IA, nota fiscal, preços, rastreabilidade de lotes, integração com ERP.

## Arquivos

- `db/seeds_data/`: dados reais da semana de 12/10/2026 em YAML.
- `prototipo/safra.html`: protótipo funcional (abrir no navegador). A lógica de cálculo dele é a referência para os serviços.
- `referencia/planilhas/`: planilhas originais da Hortifruti Modelo e pedidos dos clientes. Não versionar no Git (dados de clientes).
- `docs/`: análise das planilhas, dúvidas de regra e plano do MVP.
