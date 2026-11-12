# Skills de revisão e QA do Claude Code

O Safra tem quatro skills do Claude Code para revisar e testar o que é construído. Elas ficam em `.claude/skills/` e são carregadas em toda sessão do Claude Code aberta neste repositório.

| Skill | Pergunta que responde | Altera arquivos? |
|---|---|---|
| `pr-reviewer` | Este diff introduz bug, regressão ou risco? | Não |
| `principal-improvements` | Isso se comporta corretamente em produção, com dados reais, várias empresas e mais de uma pessoa usando? | Não |
| `qa-rails` | Funciona de verdade, inclusive quando algo dá errado, e segue a regra confirmada? | Só testes, salvo pedido de correção |
| `senior-improvements` | O código segue as boas práticas de Rails (design, banco, segurança, testes)? | Sim: aplica os ajustes da checklist |

Nenhuma skill confirma regra de negócio. Regra vem da conversa com o Gerente de Produção e fica em `docs/regras.md` (ciclo em `docs/roteiro.md`). As skills conferem se o código segue a regra, não decidem qual é a regra.

## Regra principal: só rodam quando você chama

As quatro têm `disable-model-invocation: true` no `SKILL.md` desde 28/10/2026. Isso quer dizer:

- O Claude Code **não** as aciona sozinho a partir de um pedido em texto ("revisa esse PR" não basta). Elas só rodam com o comando explícito: `/pr-reviewer`, `/principal-improvements`, `/qa-rails`, `/senior-improvements`.
- **Não existe automação em CI, hook ou rotina agendada** para elas, e isso é de propósito. O hook `.githooks/pre-commit` roda RuboCop e testes, não as skills. Não crie uma automação sem rever os riscos da seção "Por que não automatizar".

Nunca remova `disable-model-invocation` sem uma decisão explícita, registrada em `docs/mudancas.md`.

## Como chamar

```text
/pr-reviewer 67                  # revisa o PR 67
/pr-reviewer                     # sem argumento: diff da branch atual contra a main
/principal-improvements cálculo da compra com saldo de produto pronto, antes de implementar
/principal-improvements envio aos setores e versões do plano
/qa-rails                        # sem argumento: valida as alterações da branch atual
/qa-rails importação de pedido por planilha
/qa-rails acesso de outra empresa aos pedidos e à API
/senior-improvements app/services/purchase_planner.rb
```

O argumento é o escopo. Quanto mais preciso, mais focada a revisão: diga o fluxo, o PR, o arquivo, a etapa da esteira ou o risco que preocupa.

## Quando usar cada uma

As skills entram no passo 5 do roteiro ("Implementar"), depois que a regra está confirmada e a decisão registrada em `docs/lacunas.md`:

1. **Antes de implementar algo grande** (muda cálculo, data, unidade, versão de plano, migration, multiempresa ou autorização): `/principal-improvements` sobre o plano ou o fluxo afetado.
2. **Implementação.**
3. **Terminou:** `/qa-rails` na branch, citando a regra de `docs/regras.md` e o exemplo real da conversa, para validar e completar os testes.
4. **Antes do merge:** `/pr-reviewer`, já com os testes da etapa 3.
5. **Validação com o Gerente de Produção** (passo 6 do roteiro). Nenhuma skill substitui esse passo.

Atalhos:

- Mudança pequena (texto, ajuste visual, documentação): só `/pr-reviewer`.
- Defeito em produção: `/qa-rails` para reproduzir e escrever o teste de regressão antes da correção.
- Limpeza de um arquivo ou serviço específico: `/senior-improvements` sobre ele, numa branch própria.
- Fim de uma etapa da esteira, ou dúvida de concorrência, segurança ou desempenho: `/principal-improvements` sobre o fluxo inteiro.

## Boas práticas por skill

### `pr-reviewer`

- Rode no diff final, depois do `/qa-rails`, para revisar também os testes.
- Leia os achados como hipóteses fundamentadas: cada um traz arquivo, linhas, cenário e impacto. Confira o cenário antes de corrigir.
- Ela confere se o PR aponta para a regra em `docs/regras.md` e se tem entrada em `docs/mudancas.md`.
- Ela não comenta no GitHub, não aprova e não faz merge. Se quiser o resultado no PR, peça explicitamente depois de ler.
- Não substitui a sua leitura do diff, principalmente em cálculo de produção e compra, multiempresa e autorização.

### `principal-improvements`

- Use antes de codar, quando mudar o desenho ainda é barato.
- Dê o escopo como um fluxo ou uma fronteira ("pedido → produção → compra", "API v1"), não como um arquivo.
- Quando a revisão esbarrar numa regra de negócio (antecedência, arredondamento, saldos), a resposta não é dela: vira pergunta na pauta (`docs/duvidas.md`).
- O veredito vem como "Aprovar", "Aprovar com ajustes" ou "Mudanças necessárias". Sugestões P3 são opcionais; registre o que ficou para depois.

### `qa-rails`

- Sem argumento, valida a branch atual. Para fluxos ou riscos específicos, diga quais.
- O comportamento esperado vem de `docs/regras.md`. Se a regra não estiver lá, ela registra como ambiguidade, e não como requisito.
- Escreve testes de regressão na suíte certa: o app em Minitest (`bin/rails test`, `bin/rails test:system`) e os endpoints da API v1 em RSpec (rswag). Revise os testes que ela criar antes de commitar.
- Não corrige código de produção a menos que você peça ("valida e corrige").
- Testes de carga, força bruta e concorrência pesada rodam só local, **nunca em produção** (Railway).
- Nunca usa os pedidos e planilhas reais de `referencia/` como massa de teste versionada.
- Ela não instala ferramentas novas sem pedir.

### `senior-improvements`

- É a única que altera código por conta própria. Rode numa branch própria, com escopo pequeno, e revise o diff antes de commitar.
- Não mude regra de negócio com ela: refatoração preserva comportamento. Se aparecer uma diferença de comportamento, ela vira pergunta, não ajuste.
- O resultado passa pelo `/pr-reviewer` como qualquer outro PR.

## Depois do relatório

Cada skill entrega um relatório com achados por gravidade: Crítica, Alta, Média e Baixa na `pr-reviewer`; Bloqueante (P0/P1), Importante (P2), Sugestão (P3) e Pergunta na `principal-improvements`; bugs por gravidade e um parecer na `qa-rails`. A partir dele, você decide:

- "corrige os achados de gravidade alta" → correção num commit próprio, com teste;
- "abre uma issue para o de gravidade média";
- "ignora o 3, é pergunta para o Gerente de Produção" → vai para `docs/duvidas.md`.

Ausência de achados não é garantia de ausência de bugs: o relatório lista o que foi coberto e o que ficou de fora.

## Por que não automatizar

Decisão de 28/10/2026: as quatro rodam só manualmente. Os riscos de automatizar:

- **Instruções escondidas no PR (prompt injection):** o revisor lê diff, descrição e comentários. Uma automação com permissão de aprovar, fazer merge ou push poderia ser induzida a isso.
- **Merge vai direto para produção:** a Railway publica a cada merge na `main` e hoje não espera o CI (ver "Deploy na Railway" no `README.md`). Uma automação com permissão de merge publicaria em produção sem ninguém olhar.
- **Credenciais:** em CI, a skill teria acesso ao que o ambiente expõe. Segredos de produção (`DATABASE_URL`, `SECRET_KEY_BASE`, `SAFRA_ADMIN_PASSWORD`, `VAPID_PRIVATE_KEY`, chaves da API) nunca podem estar lá.
- **Dados de clientes:** pedidos de hospitais e refeitórios ficam em `referencia/`, fora do Git. Uma automação local poderia lê-los e levá-los para relatórios, testes ou comentários.
- **`qa-rails` e `senior-improvements` executam e escrevem:** rodando sozinhas, poderiam fazer testes de carga ou de segurança contra o ambiente errado ou commitar código e testes sem revisão.
- **Ruído e custo:** uma revisão a cada push gera comentários repetidos e gasto de tokens, e a equipe passa a ignorá-los.

Se um dia a automação for desejada, o mínimo aceitável é: só a `pr-reviewer`, com permissão apenas de comentar, sem segredos de produção, nunca como check obrigatório e nunca aprovando ou fazendo merge.

## Manutenção

- Cada skill é um `SKILL.md` em `.claude/skills/<nome>/`. Mude por PR, como qualquer código, com entrada em `docs/mudancas.md`.
- As seções "Particularidades deste projeto" (`pr-reviewer`, `qa-rails`) e "Pontos de atenção atuais do Safra" (`principal-improvements`) resumem fatos que mudam: infraestrutura, suítes de teste, documentos de regra. Quando o `CLAUDE.md`, o `README.md` ou o roteiro mudarem nesses pontos, atualize as skills junto.
