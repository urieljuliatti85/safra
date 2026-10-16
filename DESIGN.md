---
name: Safra
description: Calendário de safra. Planejamento de produção e compras de hortifrúti, lido na bancada sob luz forte e impresso em A4.
colors:
  field: "#2e7d32"
  field-deep: "#1e5a24"
  sprout: "#8bc34a"
  sprout-mid: "#5aa84b"
  sprout-pale: "#cfe3bf"
  field-wash: "#e7f1e2"
  leaf: "#f4f7f0"
  surface: "#ffffff"
  ink: "#14231a"
  ink-soft: "#4a5d50"
  line: "#cbd7c4"
  line-soft: "#e3eadd"
  sun: "#f2b705"
  change: "#b3261e"
  change-wash: "#fdecea"
  soil: "#8a6a3c"
typography:
  page-title:
    fontFamily: "Bricolage Grotesque, Bricolage Fallback, ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(1.5rem, 1.1rem + 1.6vw, 2rem)"
    fontWeight: 800
    lineHeight: 1.1
    letterSpacing: "-0.02em"
  data:
    fontFamily: "Bricolage Grotesque, Bricolage Fallback, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.25rem"
    fontWeight: 800
    lineHeight: 1.2
    fontFeature: "tnum"
  section:
    fontFamily: "Bricolage Grotesque, Bricolage Fallback, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.125rem"
    fontWeight: 800
    letterSpacing: "-0.01em"
  dense:
    fontFamily: "Bricolage Grotesque, Bricolage Fallback, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 400
  small:
    fontFamily: "Bricolage Grotesque, Bricolage Fallback, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 700
  label:
    fontFamily: "Bricolage Grotesque, Bricolage Fallback, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 700
    letterSpacing: "0.06em"
rounded:
  sm: "4px"
  md: "8px"
  lg: "12px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
components:
  button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
    height: "40px"
  button-hover:
    backgroundColor: "{colors.field-wash}"
  button-primary:
    backgroundColor: "{colors.field}"
    textColor: "{colors.surface}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
    height: "40px"
  button-primary-hover:
    backgroundColor: "{colors.field-deep}"
  panel:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
  panel-head:
    backgroundColor: "{colors.field-wash}"
    textColor: "{colors.field-deep}"
    typography: "{typography.section}"
    padding: "12px 16px"
  pill-sent:
    backgroundColor: "{colors.field}"
    textColor: "{colors.surface}"
    rounded: "{rounded.pill}"
    padding: "2px 12px"
  chip:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "4px 16px"
    height: "40px"
  chip-current:
    backgroundColor: "{colors.field}"
    textColor: "{colors.surface}"
  change-box:
    backgroundColor: "{colors.change-wash}"
    padding: "12px 16px"
  week-bar:
    backgroundColor: "{colors.sprout}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    height: "24px"
  week-bar-buy:
    backgroundColor: "{colors.soil}"
    height: "10px"
  week-day-today:
    backgroundColor: "{colors.sun}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
  week-day-open:
    backgroundColor: "{colors.field}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sm}"
---

# Design System: Safra

## Overview

**Creative North Star: "Calendário de safra"**

Safra é uma ferramenta de operação: quem a abre está na bancada ou na câmara fria, com luz forte e refletida, área úmida, às vezes com a mão ocupada. O sistema nasce dessa cena, não de um gosto por temas escuros. Por isso é claro, de tinta escura sobre fundo de folha, e o PDF impresso é cidadão de primeira classe: as mesmas cores, a mesma fonte e a mesma coluna de quantidades valem na tela e no papel A4.

A metáfora é o calendário do plantio: uma semana em colunas, um canteiro por setor, barras que crescem onde há trabalho. Os verdes são de lavoura e fazem todo o trabalho de estrutura. Duas cores de sinal têm dono único e quase nunca aparecem: o amarelo-sol só diz "hoje", o vermelho só diz "mudou depois do envio". Modo Operate: densidade confortável, nada decorativo, a quantidade é sempre o que se lê primeiro.

Não há modo escuro, e isso é decisão de uso, não omissão. Não há ilustração nem foto; a identidade vem da cor, da fonte única e da faixa da semana.

**Key Characteristics:**
- Fundo de folha (#f4f7f0) com painéis brancos e bordas verde-acinzentadas finas; profundidade só por tom e borda.
- Uma família tipográfica (Bricolage Grotesque), cinco papéis de tamanho, quantidades tabulares e alinhadas à direita.
- Verde como estrutura; sol e vermelho como sinais de uso único; terra só para a cobertura da compra.
- A faixa da semana é a assinatura: oito dias, uma raia por setor, uma raia contínua de compra.
- Impresso e tela são o mesmo sistema.

## Colors

Paleta de lavoura sobre folha clara: verdes em quatro tons de trabalho, neutros esverdeados, e três cores com papel reservado.

### Primary
- **Verde de Lavoura** (#2e7d32, `field`): ação primária, aba atual, dia aberto na faixa, selo "enviada", barras de nível alto, foco de cursor. Texto branco sobre ele.
- **Verde Fundo** (#1e5a24, `field-deep`): hover do primário, marca e nome Safra, títulos de painel, anel de foco (3px).

### Secondary
- **Broto** (#8bc34a, `sprout`): barras de nível baixo (1 a 2 itens), seleção de texto, borda de aviso positivo. Texto de tinta sobre ele, nunca branco.
- **Broto Médio** (#5aa84b, `sprout-mid`): barras de nível médio (3 a 5 itens). Só existe como o degrau do meio da escala de barras.
- **Broto Pálido** (#cfe3bf, `sprout-pale`): declarado no tema para apoio de superfície verde; ainda sem uso nas telas.
- **Lavagem de Lavoura** (#e7f1e2, `field-wash`): cabeça de painel, grupos da grade, dia aberto na faixa (coluna inteira), hover de botão.

### Tertiary (papéis reservados)
- **Sol** (#f2b705, `sun`): exclusivamente "hoje": dia de hoje na faixa e na grade, e o ponto do ícone do app. Nunca decoração.
- **Mudou** (#b3261e, `change`) e **Lavagem de Mudança** (#fdecea, `change-wash`): exclusivamente "mudou depois do envio" e erros: linha alterada, etiqueta "mudou", caixa de diferença, alerta. Texto sobre a lavagem usa um vermelho mais escuro (#6f1710).
- **Terra** (#8a6a3c, `soil`): exclusivamente a barra contínua da compra CEASA e os avisos de conferência de matéria-prima (fundo #f6f0e6, borda #d8c8ac, texto #6b5230).

### Neutral
- **Folha** (#f4f7f0, `leaf`): fundo da página e da área de texto do WhatsApp.
- **Branco** (#ffffff, `surface`): painéis, barra de navegação, botões, células da grade.
- **Tinta** (#14231a, `ink`): texto principal.
- **Tinta Suave** (#4a5d50, `ink-soft`): metadados, cabeçalhos de coluna, unidades, contorno de rascunho.
- **Linha** (#cbd7c4, `line`): bordas de painel, botão, divisão de cabeçalho.
- **Linha Suave** (#e3eadd, `line-soft`): divisões entre linhas, hachura de domingo.

### Named Rules
**The Dono Único Rule.** Sol é "hoje", vermelho é "mudou", terra é "compra". Nenhuma dessas cores serve de enfeite nem de ênfase genérica; a raridade é o que as faz ser lidas.

**The Papel Impresso Rule.** Toda cor de tela que importa no PDF existe também em `BasePdf` com o mesmo hex (tinta, tinta suave, verdes, lavagem, linha, sol, mudou). Cor nova entra nos dois lugares ou em nenhum.

## Typography

**Display e Body:** Bricolage Grotesque (variável, 400 a 800, eixo óptico automático), hospedada em `app/assets/fonts` (latin e latin-ext), licença SIL OFL 1.1. Fallback "Bricolage Fallback", Arial com métricas ajustadas (size-adjust 96%, ascent 96,9%, descent 28,1%), depois `ui-sans-serif, system-ui`.

**Character:** Uma família só, sem par. Pesos fortes (700 a 800) nos títulos e nas quantidades dão a hierarquia; o corpo é calmo e curto. Os números são tabulares onde se comparam.

### Hierarchy
- **Título de página** (800, clamp(1.5rem, 1.1rem + 1.6vw, 2rem), 1.1, -0.02em): um por tela, com subtítulo em tinta suave até 68ch.
- **Quantidade** (800, 1.25rem, 1.2, tabular): a quantidade em cada linha de setor, legível de longe. Sempre na mesma coluna fixa.
- **Seção** (800, 1.125rem, -0.01em): título de painel, em verde fundo sobre a lavagem.
- **Denso** (400, 0.9375rem): células de grade, "quem pediu", observação.
- **Pequeno** (700 em dias e pílulas, 400 em metadado; 0.875rem): legenda, metadado, dia da semana, pílula.
- **Rótulo** (700, 0.75rem, 0.06em, caixa-alta): somente cabeçalho de coluna de tabela operacional e etiqueta "mudou".

### Named Rules
**The Coluna da Quantidade Rule.** Quantidade é tabular, alinhada à direita, em coluna de largura fixa (6,5rem), igual em todos os setores. No celular a quantidade sobe para a direita da linha com a unidade ao lado.

**The Cinco Papéis Rule.** Só os cinco tamanhos nomeados (rótulo, pequeno, denso, seção, dado) mais o título de página e a marca. Tamanho novo exige papel novo.

**The Mesma Fonte no Papel Rule.** O PDF embute duas instâncias estáticas da mesma variável (regular wght 420 opsz 14; negrito wght 800 opsz 24, em `app/pdfs/fonts`), derivadas da fonte OFL.

## Layout

Coluna única de até 80rem (max-w-7xl) com 1rem de respiro lateral e 1.5rem vertical; telas empilham painéis com 1rem entre eles. A navegação é uma barra branca com linha inferior, marca à esquerda e cinco abas (Pedidos, Programação, Produção, Compras, Conferência); no celular a marca fica acima e as abas rolam na horizontal com máscara nas pontas, a aba atual centralizada por script.

Ritmo: espaçamentos em múltiplos de 4px (4, 8, 12, 16, 24); células de tabela com 10px de altura de padding vertical e 16px lateral. Alvos de toque têm no mínimo 2.5rem (botões, chips, campos, ícone-botão). Abaixo de 640px as tabelas operacionais viram listas em duas colunas (nome e "quem pediu" à esquerda, quantidade à direita). A grade de pedidos tem cabeçalho e primeira coluna fixos, rolagem própria de até 75vh, e barra de salvar presa à base com esmaecimento para o fundo.

A faixa da semana usa uma grade de 11,5rem para rótulos mais 8 colunas de no mínimo 3,25rem (largura mínima 42rem, rolagem horizontal), com o rótulo da raia fixo à esquerda.

## Elevation & Depth

Plano por padrão: não há sombras em nenhum componente. A profundidade vem de tom (painel branco sobre folha), borda de 1px em Linha, e cabeça de painel em lavagem verde. Estado vem de cor e contorno: hover troca fundo e borda para verde, foco usa anel sólido de 3px em verde fundo com offset de 2px, hover de barra usa contorno de tinta de 2px. A única camada flutuante é a barra de salvar, que se separa do conteúdo por esmaecimento em degradê, não por sombra.

Movimento: as barras da faixa crescem da esquerda em 0,5s (`cubic-bezier(.16,1,.3,1)`), sem rebote; desligado com `prefers-reduced-motion`. Botões trocam cor em 0,15s.

### Named Rules
**The Plano Rule.** Superfícies não têm sombra; separe por tom e linha de 1px.

## Shapes

Cantos suaves em três degraus: 4px para etiquetas e foco, 8px (0.5rem) para botões, campos e avisos, 12px (0.75rem) para painéis, faixa e grade. Pílulas (999px) para chips de seleção e status; barras da faixa são cápsulas (altura 1.5rem, raio 0.75rem). A barra de compra é a exceção de propósito: sem raio no meio, com cantos arredondados só na primeira e na última célula, para ler como uma faixa contínua. Domingo é marcado por hachura diagonal fina em Linha Suave, não por cor. Ícones: traço único de 1,75px, `currentColor`, pontas arredondadas, 24x24 exibidos a 1,125rem; desenhados à mão neste projeto (sem biblioteca). Marca: dois brotos de folha em traço de 2px; no ícone do app, traço Folha sobre quadrado Verde de Lavoura (raio 112/512) com ponto sol.

## Components

### Buttons
- **Shape:** cantos de 8px, altura mínima 2.5rem, padding 8px 16px, texto 700, ícone opcional de 1.125rem à esquerda.
- **Padrão:** fundo branco, borda Linha, texto tinta. Hover: fundo lavagem verde e borda verde de lavoura.
- **Primário:** fundo Verde de Lavoura, texto branco; hover Verde Fundo. Um por região, a ação que avança (enviar aos setores, salvar).
- **Ícone-botão:** quadrado 2.5rem com o mesmo comportamento (navegação de dia).

### Chips
- Pílula de 2.5rem, branca com borda Linha, texto 600. Selecionado (`aria-current`): fundo e borda Verde de Lavoura, texto branco. Usados para escolher cliente na grade de pedidos.

### Painéis
- Branco, borda Linha de 1px, raio 12px, sem sombra. Cabeça em lavagem verde com título de seção em verde fundo à esquerda e metadado em tinta suave à direita. Cada setor de produção é um painel.

### Status e mudança
- Pílula "enviada" (verde sólido, texto branco) e "rascunho" (branca com contorno de tinta suave). Depois do envio, uma caixa de diferença em Lavagem de Mudança com ícone de alerta em vermelho lista o que mudou; as linhas afetadas ganham fundo da mesma lavagem e a etiqueta "mudou" (contorno vermelho, 0.75rem, 800).
- Avisos: `flash` com ícone (verde para aviso, vermelho para erro); itens de conferência em branco, e em terra clara quando há alerta de matéria-prima.

### Tabelas operacionais
- Cabeçalho em rótulo caixa-alta; linhas separadas por Linha Suave; colunas fixas: quantidade (6,5rem, direita, 1.25rem 800), unidade (3,5rem, tinta suave), "quem pediu" em tinta suave. Mesmo desenho em todo setor, aprontes e compras.

### Grade de pedidos
- Células de 3,75rem, texto à direita e tabular, sem borda até hover; preenchida fica em 700. Cabeçalho de dia de hoje em sol; domingo hachurado; grupos em lavagem verde fixos à esquerda. Foco com anel de 3px.

### Campos
- Altura 2.5rem, borda tinta suave, raio 8px, fundo branco. A área do WhatsApp é um bloco sem borda lateral, fundo Folha, leitura em 0.9375rem/1.5, com botão de copiar que confirma "Copiado" por 2 segundos.

### Navegação
- Abas de texto 600 em tinta suave; hover tinta; atual com tinta e sublinhado de 3px em Verde de Lavoura. Marca em Verde Fundo, 800, 1.375rem, com o duplo broto.

### BI (painel escuro)
- Exceção deliberada e só desta tela (`/bi`, menu "BI", admin e escritório): painel escuro de sala de controle, escolhido pelo usuário para análise no computador do escritório. Fundo verde-quase-preto (#0c1810), painéis #12251a, linha #274533, tinta #eaf3e4, tinta suave #a3bba8; a nav fica escura nesta tela. Mesma fonte (Bricolage), mesmos verdes (Broto como cor de dado), sol só para "hoje" (coluna do dia), terra clara (#d9b27a) só para compra. No papel (`@media print`) volta à base clara com os mesmos tokens.
- Papéis: uma exceção de tamanho, o número da semana em 3,5 a 6rem, 800, tabular, só nesta tela. O resto usa os cinco papéis.
- Gráficos em HTML e CSS puros (sem biblioteca): colunas verticais por dia, barra empilhada por setor em cinco tons de verde com legenda de valores, barra "bullet" de perda (comprimento = kg in natura; verde = vira produto; hachurada = perda) e barras horizontais para compras (terra) e rankings (verde). Totais só em kg; outras unidades são contadas em nota.

### Faixa da Semana (assinatura)
- Oito colunas de dia (abreviação e número), uma raia por setor de produção e uma raia de compra CEASA. Em cada célula com trabalho, uma barra-cápsula com a contagem de itens em três níveis de verde: 1 a 2 (broto, texto tinta), 3 a 5 (broto médio, texto tinta), 6 ou mais (verde de lavoura, texto branco). Hoje é o dia em sol; o dia aberto é verde de lavoura com a coluna em lavagem. A compra é uma barra contínua de terra de 10px que cobre os dias até a véspera da próxima compra. Toda barra é um link para o dia, com rótulo acessível, e a legenda embaixo explica níveis, terra e sol.

## Do's and Don'ts

### Do:
- **Do** manter a base clara: fundo Folha (#f4f7f0), painéis brancos, tinta #14231a. O uso real é luz forte e papel.
- **Do** reservar sol para "hoje", vermelho para "mudou depois do envio" e terra para a cobertura da compra.
- **Do** alinhar toda quantidade à direita, tabular, na coluna fixa de 6,5rem, em 1.25rem 800.
- **Do** separar superfícies por tom e borda de 1px em Linha; foco visível com anel de 3px em Verde Fundo.
- **Do** manter alvos de toque de pelo menos 2.5rem e transformar tabelas em listas abaixo de 640px.
- **Do** espelhar no PDF qualquer cor ou peso novo que importe na bancada.
- **Do** desenhar ícones novos em traço único de 1,75px com `currentColor`, no `IconHelper`.

### Don't:
- **Don't** usar sol, vermelho ou terra como acento decorativo, nem verde como sinal de erro.
- **Don't** adicionar sombras: a profundidade é tonal.
- **Don't** introduzir uma segunda família tipográfica nem tamanhos fora dos cinco papéis.
- **Don't** colocar texto branco sobre Broto ou Broto Médio: as barras de nível 1 e 2 levam tinta.
- **Don't** depender só de cor para estado: acompanhe com texto (pílula "enviada", etiqueta "mudou"), hachura (domingo) ou rótulo acessível.
- **Don't** usar biblioteca de ícones nem emoji como ícone.

## Not canonized

- O degrau médio da barra (#5aa84b) e o texto de aviso (#6f1710, #6b5230, #f6f0e6, #d8c8ac, #f1c6c1) estão codificados como literais em `application.css`, fora de `@theme`: dívida de tokenização, não regra.
- `sprout-pale` está no tema sem uso nas telas.
- Lacunas conhecidas e intencionais: sem modo escuro; sem manifesto PWA ligado (`app/views/pwa/manifest.json.erb` é o padrão do Rails, com `theme_color` vermelho, e o link está comentado no layout); a raia "entrega" pálida do esboço e a ligação de cor entre raia e lista não foram construídas.
