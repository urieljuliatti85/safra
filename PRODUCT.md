# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Primário: a equipe de escritório de um atacadista de hortifrúti / processadora de vegetais minimamente processados (primeiro cliente: Hortifruti Modelo). No computador, recebe os pedidos semanais dos clientes (planilha, ODT/PDF, print), lança e confere, envia aos setores e fecha as compras.

Secundário: a produção. Usa a lista do setor **impressa em PDF** na bancada, em ambiente de luz forte ou refletida e de área úmida / câmara fria. Não consulta a tela como ferramenta principal.

Não confirmado: uso no celular ou tablet pela produção e pelo comprador na CEASA. O comprador copia o texto de compra para o WhatsApp dos fornecedores.

## Product Purpose

Planejar produção e compras a partir só do pedido. Hoje os pedidos são redigitados em três planilhas dependentes (programação, produção por setor, compras CEASA). O sistema calcula e versiona tudo: só o pedido é digitado. Sucesso: sem redigitação, mudança de pedido propagada a todas as listas, quantidades, unidades e datas conferidas.

## Positioning

Multiempresa desde o início, para vender a outros atacadistas e processadoras. Entende o domínio do hortifrúti: matéria-prima + corte, fatores de perda, antecedência por corte, janelas de compra na CEASA.

## Operating Context

Clientes B2B: hospitais, refeitórios industriais, hotéis, supermercados. Pedidos semanais, entregas em até 8 dias, produção por setor (descascados, cortes manuais, ralados/picados/rodelas, palitos, cubinhos, frutas), compras na CEASA duas vezes por semana por fornecedor. Fuso America/Sao_Paulo, datas sem hora, quantidades em kg, un, cx, mç.

## Capabilities and Constraints

Rails 8, Hotwire (Turbo + Stimulus), Tailwind v4, Propshaft, importmap. Sem React. Interface em português do Brasil. Telas atuais: pedidos em grade por cliente e semana, programação por dia de entrega, produção do dia por setor (com aprontes), compras CEASA por fornecedor, conferência de alertas, comparação com as planilhas. PDFs (Prawn) de programação, produção e compras. Planos enviados viram versões; mudança de pedido depois do envio aparece como diferença. Em aberto: importação de planilhas; PWA.

## Brand Commitments

Nome do produto: Safra. A mesma marca para todas as empresas (não é white-label); cada empresa aparece pelo nome. Nada além disso foi definido.

## Evidence on Hand

Dados reais da semana de 12/10/2026 em `db/seeds_data/`, protótipo em `prototipo/safra.html`, planilhas originais em `referencia/planilhas/` (não versionadas). Não há logo, paleta nem guia de marca.

## Product Principles

1. Só o pedido é digitado; o resto é calculado e versionado, nunca digitado.
2. Um alerta aponta o que conferir; não bloqueia o trabalho.
3. A lista impressa do setor é um produto de primeira classe, tão importante quanto a tela.
4. Quantidade, unidade e data nunca podem ser ambíguas.
5. Mudança depois do envio é sempre visível.

## Accessibility & Inclusion

Leitura sob luz forte ou refletida (contraste alto, texto grande nas listas de produção). A tela é escura por decisão do usuário (igual ao BI); a lista da bancada continua em PDF claro, por causa da luz forte. Uso em ambiente úmido. Português do Brasil, formatos numéricos e de data brasileiros.
