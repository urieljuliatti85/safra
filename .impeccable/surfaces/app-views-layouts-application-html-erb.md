---
version: 1
slug: "app-views-layouts-application-html-erb"
primary_target: "app/views/layouts/application.html.erb"
related_targets: ["app/views/productions/show.html.erb","app/views/orders/index.html.erb","app/views/purchases/show.html.erb","app/views/schedules/show.html.erb","app/views/conferences/show.html.erb"]
---

# Surface brief: Safra (app shell e telas operacionais)

Modo: Operate. Redesenho completo das 5 telas (pedidos, programação, produção, compras, conferência) e dos 3 PDFs. Usuário principal: escritório, no computador; produção usa o PDF impresso sob luz forte. Tema claro, escolhido pela cena de uso (luz forte e refletida, área úmida).

Decisões em aberto: PWA e importação de planilhas entram depois; sem modo escuro por enquanto.

## Direction contract

THESIS: A semana é a safra. Toda tela responde "quando" antes de "o quê": uma faixa de calendário com barras reais mostra em que dia cada setor produz e quanto cada compra da CEASA cobre. Recusa o admin genérico de menu lateral e tabela solta.

OWN-WORLD: verdes de lavoura (campo #2E7D32, fundo-folha #1E5A24, broto #8BC34A) sobre branco-folha #F4F7F0 e tinta #14231A. Amarelo-sol #F2B705 reservado para "hoje". Vermelho só para "mudou depois do envio". Bricolage Grotesque, algarismos tabulares. Barras arredondadas de calendário são o único ornamento.

STORY: quem abre Produção vê a semana, entende em que dia cada setor trabalha, lê a lista do dia por setor, vê se já foi enviada e o que mudou desde o envio, e envia a nova versão.

FIRST VIEWPORT: barra de navegação branca de 60px com sublinhado verde no item ativo; título "Produção do dia"; cartão da semana com 8 colunas de dia (hoje em amarelo, dia aberto em verde) e raias por setor e uma de compra CEASA, barras com a contagem de itens; linha de estado com selo "v1 enviada", aviso de mudanças em vermelho e botão Enviar à direita; abaixo, listas por setor com o dia de entrega no título e quantidades à direita em 20px negrito tabular.

FORM: Calendário de safra, escolha do Impeccable (pick). seed: 5aebd2f92d4c2400.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
