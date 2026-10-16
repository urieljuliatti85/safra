---
version: 1
slug: "app-views-dashboards-show-html-erb"
primary_target: "app/views/dashboards/show.html.erb"
related_targets: []
---

# Painel inicial (Operate)

Escopo: nova tela `/painel`, página inicial de admin e escritório. Modo Operate. Mundo visual: o do Safra (DESIGN.md, "Calendário de safra"), herdado sem mudança.

Público e tarefa: a equipe do escritório abre o dia e precisa saber o que falta fazer, em que etapa o trabalho está e o que mudou depois do envio. Frequência: várias vezes ao dia. Restrição: só o pedido é digitado; o painel só lê e leva às telas, nunca calcula à parte (usa ProductionPlanner, PurchasePlanner, StalePlans, ConferenceChecker, WeekOverview).

## Direction contract

THESIS: o painel é o caminho do trabalho, não um mural de números. O pedido vira programação, produção e compra, nessa ordem, e a tela mostra em qual etapa cada coisa está e qual é o próximo passo. Recusa o arranjo padrão de dashboard (azulejos de métrica grande, gráficos decorativos).

OWN-WORLD: o do Safra: fundo folha claro, verde campo para o que está em ordem, vermelho só para mudança depois do envio, sol (amarelo) para hoje, solo (marrom) para a compra da CEASA. Bricolage Grotesque, pesos 700 a 800 nos títulos e nas quantidades, números tabulares. Etapas são painéis com cabeçalho verde claro, ligados por uma linha contínua com nós (cheio = em ordem, vazado = pendente, vermelho = mudou).

STORY: a pessoa entende em segundos em qual etapa há pendência, acredita no estado porque ele vem dos mesmos cálculos das telas, e age com o botão da própria etapa (Lançar, Abrir, Enviar, Contar estoque).

FIRST VIEWPORT: título "Painel" com a data de hoje; sob ele, aviso único e curto só quando há algo a conferir. Depois, quatro etapas lado a lado em ordem 1 Pedidos, 2 Programação, 3 Produção, 4 Compras, ligadas pela linha; cada etapa tem um estado em palavras, dois ou três fatos curtos e uma ação. Abaixo, a faixa da semana (componente existente) com hoje em destaque. No celular as etapas empilham em coluna, a linha vira vertical e a faixa rola na horizontal dentro do próprio painel.

FORM: Fluxo em etapas, segunda estrutura sorteada, posição 7 na lista ordenada; seed: fca844e9f9a73cf8. Movimento de assinatura: a linha-fio que liga as etapas e mostra onde o trabalho parou.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.
