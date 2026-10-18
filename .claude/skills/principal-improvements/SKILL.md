---
name: principal-improvements
description: A Principal Rails engineer should review Claude-generated code for correctness, failure handling, security, and maintainability. Clean syntax matters, but the key question is whether the code behaves correctly in production.
tags: ["review", "quality", "audit"]
---

# O que um Principal Rails revisa no Safra

Checklist de revisão para o Safra (Rails 8.1, PostgreSQL, `acts_as_tenant`, Pundit, Solid Queue, Hotwire). A pergunta de fundo não é "o código está limpo?", e sim **"isso se comporta corretamente em produção, com dados reais e mais de uma pessoa usando?"**.

Ordem de prioridade: integridade de dados, segurança, deploy, concorrência, desempenho, design, testes, observabilidade. Estilo vem por último e é trabalho do RuboCop.

## Postura

- Achar os problemas que importam, não o máximo de problemas. Se o código está bom, dizer isso em uma linha.
- Explicar impacto concreto: "gera 51 queries por request numa lista de 50 itens", não "isso é N+1".
- Questionar o problema antes da solução. Existe algo mais simples que o Rails já oferece?
- Desconfiar de abstração prematura (service para tudo) tanto quanto de model gordo sem controle.
- Marcar hipóteses como hipóteses. Não afirmar comportamento do Rails sem conferir a versão instalada.

## Antes de opinar

1. `git diff` contra a `main` e os arquivos tocados.
2. Versões: `.ruby-version`, `Gemfile.lock`.
3. `db/schema.rb`: índices, `null: false`, chaves estrangeiras, tipos.
4. Testes que cobrem a mudança. Eles falhariam sem ela?
5. Padrões já usados no projeto (serviços em `app/services`, concerns, `Data.define` para resultados).

## 1. Integridade de dados e regras de negócio

O princípio do Safra: **só o pedido é digitado; o resto é calculado**. Logo, o que mais importa é o cálculo estar certo e reproduzível.

- Fórmulas (`kg in natura = kg processado × fator`, `ROUND(kg ÷ kg_por_embalagem)`, caixas para aprontar) batem com `referencia_planilhas.yml`? Diferença sem regra cadastrada é bug.
- Arredondamento: `BigDecimal` do início ao fim, nunca `Float`. Quantidades em `decimal(10,3)`. Conferir `.to_f` em cálculo (só aceitável em serialização para JSON).
- Matéria-prima sem fator gera alerta, não erro. Verificar que nenhum caminho levanta exceção nesse caso.
- Datas: `Date` sem hora, `Time.current` e não `Time.now`, `Date.current` e não `Date.today`. Regra do domingo (cai para sábado) e antecedência por corte com exceção por produto.
- Validações do model sem constraint no banco não protegem de corrida. Para cada `validates :uniqueness`, existe índice único? Para cada invariante, existe `null: false`, FK ou `CHECK`?
- Antes de adicionar constraint em tabela populada, procurar duplicatas e linhas inválidas.
- `update_all`, `delete_all`, `update_column` pulam validações, callbacks e auditoria. Há intenção clara? (`Auditable` não vê essas escritas.)
- Efeitos colaterais externos (e-mail, HTTP, enfileirar job) dentro de transação ou callback: mover para depois do commit.

## 2. Concorrência

O padrão mais comum de bug em sistema de escritório: **ler, decidir, gravar** sem proteção.

- Sequências "máximo + 1" (versões de plano, versões de planilha) precisam de lock ou de retry em `RecordNotUnique`. Ver `PlanPublisher.next_version` e `ReferenceSheets::Importer`.
- Salvar grade de pedido por duas pessoas ao mesmo tempo: `lock!` no pedido ou locking otimista (`lock_version`).
- Duplo clique em botões de efeito externo ("Enviar aos setores"): desabilitar no cliente **e** tornar o servidor seguro sozinho.
- Contadores e saldos: operação atômica no SQL ou `with_lock`.
- Transação cobre só o banco. Não existe rollback de PDF, WhatsApp ou chamada externa.

## 3. Multiempresa e autorização

Este é o risco de maior impacto do produto: vazar dado de uma empresa para outra.

- Todo model de domínio tem `acts_as_tenant :company`? Tabela nova sem `company_id` é um achado.
- Consultas com `unscoped`, `ActsAsTenant.without_tenant` ou SQL cru contornam o escopo. Cada uso precisa de justificativa.
- Código fora do request (jobs, console, seeds, serviços chamados em thread) tem tenant definido? `ActsAsTenant.with_tenant` explícito.
- Ids vindos do formulário (`product_id`, `customer_id`) são resolvidos **pelo escopo do tenant**, nunca confiados. Um id de outra empresa deve virar erro de validação, não 500 nem vazamento.
- Pundit: `verify_authorized` ativo; toda ação nova tem policy; papéis (escritório, produção, admin) testados nas bordas.
- API (`api/v1`): autenticação por token com digest, expiração, escopo do tenant, `rate_limit` com cache store compartilhado.
- Sessão exige usuário ativo e empresa ativa. Troca de senha provisória não pode ser contornada.

## 4. Segurança

- Strong parameters: sem `permit!`; `to_unsafe_h` só com validação posterior (ver `OrderGridSaver`).
- SQL: interpolação em `where`, `order`, `pluck`, `find_by_sql`.
- XSS: `html_safe` e `raw` só em constantes, nunca com dado do usuário. Nomes de produto e cliente vêm de importação de Excel, então são entrada não confiável.
- Importação de planilhas e PDFs: tipo e tamanho de arquivo, bombas de descompressão em `.xlsx`, limite de linhas, `rescue` estreito.
- Redirect com parâmetro (`redirect_to params[...]`), `return_to` da sessão, CSRF ativo, headers e `force_ssl` em produção.
- Segredos fora do código; `filter_parameters` cobre senha, token e e-mail; logs sem dados de cliente.
- Ferramentas: `bin/brakeman` e `bundler-audit` no CI, sem warnings novos.

## 5. Migrations e deploy

O deploy dispara a cada push, então a migration roda com a versão antiga ainda atendendo.

- Índice em tabela que cresce (`order_lines`, `audit_logs`): `algorithm: :concurrently` com `disable_ddl_transaction!`.
- `NOT NULL` ou default em tabela populada: adicionar a constraint como `NOT VALID` e validar depois.
- Remover ou renomear coluna: duas etapas (`ignored_columns`, depois remoção).
- Backfill separado da migration de esquema; sem models da aplicação dentro de migration.
- `down` que perde dado não é recuperação segura: documentar o caminho de rollback (o README já tem o guia).
- Compatibilidade código novo + esquema antigo e vice-versa durante o rolling deploy. `/ready` só confirma que o banco responde, não que o esquema está atualizado.

## 6. Consultas e desempenho

- N+1: `includes`, `preload`, `eager_load`. Conferir o que o `includes` realmente faz com o filtro usado. Considerar `strict_loading` nos planejadores.
- Os planejadores (`ProductionPlanner`, `PurchasePlanner`, `ScheduleBuilder`) percorrem todas as linhas da semana: o número de queries deve ser constante em relação a clientes e produtos. Teste que conte queries protege isso.
- Índices pelos predicados reais: `order_lines (company_id, delivery_date)`, `audit_logs` por data e registro. Cuidado com índice que não é usado e encarece a escrita.
- Coleções inteiras em memória: `find_each`, `in_batches`, `pluck`. Telas de histórico e auditoria paginadas.
- `count` repetido em view, `present?` em relação (usar `exists?`).
- Trabalho lento no request (geração de PDF com Prawn, importação grande, `SheetComparison` com 463 linhas): medir antes de mover para job.
- Afirmar gargalo só com medição, não pela aparência do código.

## 7. Jobs e integrações

- Jobs e webhooks podem chegar duas vezes: efeito idempotente, ids em vez de objetos, reconferir o estado na execução.
- Timeouts em toda chamada externa; retry limitado com backoff; distinguir falha transitória, rejeição definitiva e resultado incerto.
- Enfileirar depois do commit (`after_commit` ou `enqueue_after_transaction_commit`, conforme o Rails 8.1 e o Solid Queue em uso).
- Solid Queue: fila, concorrência e jobs que falham em silêncio têm alerta?

## 8. Design e manutenibilidade

- Controller magro: coordena requisição e resposta. Regra de negócio testável fora dele.
- Serviço só quando orquestra de fato mais de um registro ou integração. Os existentes (`OrderGridSaver`, `PlanPublisher`) têm essa justificativa; avaliar novos com o mesmo critério.
- Callbacks com ordem e efeitos escondidos; concerns como gaveta de bagunça (`Auditable` é bom exemplo de concern focado).
- Arquivos que crescem demais (`SheetComparison`, ~460 linhas): dividir por responsabilidade, não por tamanho.
- Código morto, duplicação relevante, abstração sem segundo caso de uso.
- Idioma: código, tabelas e classes em inglês; interface, mensagens e seeds em português.

## 9. Testes

- A mudança tem teste que **falharia sem ela**? Cobre caminho infeliz e borda?
- Regressão para cada bug confirmado, incluindo duplicidade, transição inválida e concorrência quando couber.
- Constraint e lock testados com banco real, não com mock.
- Os números de `referencia_planilhas.yml` são fixtures: testes de planejamento devem chegar neles.
- Evitar teste que espelha a implementação, excesso de stubs, dependência de relógio e de ordem. Usar `travel_to` para datas.
- Autorização: cada papel nas bordas, e tenant A tentando acessar dado do tenant B.
- Relatar exatamente o que rodou e o resultado; nunca insinuar que o não rodado passou.

## 10. Observabilidade e operação

- `rescue => e` que engole erro: relançar ou registrar com contexto, sem dado sensível.
- Auditoria (`AuditLog`) cobre as ações que importam, com usuário, IP e `request_id`.
- Fluxos críticos (envio aos setores, importação, login) com log estruturado e alerta.
- Backup do PostgreSQL com restauração testada; dados de cliente nunca versionados no Git (`referencia/planilhas/`).

## Severidade

| Nível | Quando usar |
|---|---|
| 🔴 **Bloqueante (P0/P1)** | Risco real de perda ou corrupção de dados, vazamento entre empresas, falha de segurança ou deploy inseguro. Corrigir antes do merge. |
| 🟠 **Importante (P2)** | Defeito em caminho limitado, problema de confiabilidade recuperável, regressão de desempenho ou lacuna de teste que vai custar caro. Corrigir agora ou abrir tarefa. |
| 🟡 **Sugestão (P3)** | Melhoria concreta de clareza ou manutenção, com impacto pequeno. Opcional. |
| 💬 **Pergunta** | Falta contexto que pode mudar a avaliação. Não tratar como defeito confirmado. |

A severidade reflete o cenário real e as salvaguardas existentes, não o pior caso imaginável.

## Formato da revisão

Começar com resumo de 2 a 3 linhas: o que a mudança faz, avaliação geral e veredito (**Aprovar**, **Aprovar com ajustes** ou **Mudanças necessárias**). Depois, achados por severidade, omitindo grupos vazios. Para cada um:

- **Onde:** `arquivo:linha`.
- **O quê e por quê:** o defeito e o impacto concreto.
- **Gatilho:** a sequência que o provoca.
- **Como:** a menor correção prática, com código curto quando ajudar.
- **Verificação:** teste ou checagem que prova a garantia.

Encerrar com o que foi verificado (e o que não foi), o que está bem feito (no máximo 2 ou 3 pontos genuínos) e riscos sistêmicos que passam do diff.

## O que evitar

- Nitpick de formatação que o RuboCop resolve.
- Reescrever tudo quando um ajuste pontual basta.
- Recomendar gem ou padrão novo sem justificar o custo.
- Inventar achado para parecer completo.
- Chamar uma revisão de diff de auditoria de segurança completa.

## Pontos de atenção atuais do Safra

Resumo do que já apareceu em revisão e merece vigilância contínua:

1. Sequência "máximo + 1" para versões de plano e de planilha, sem lock (`PlanPublisher`, `ReferenceSheets::Importer`).
2. `OrderGridSaver` com `product_id` fora do tenant ou `unit` inválida virando 500 em vez de erro de validação, e sem proteção contra salvas simultâneas.
3. Limite de tentativas de login e de API dependente do `cache_store` ser compartilhado em produção.
4. Crescimento de `audit_logs` e `order_lines`: índices e paginação.
5. Tamanho e coesão de `SheetComparison`.