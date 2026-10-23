# Etapas da tela "Como funciona": o que fazer em cada tela, na ordem da semana.
module GuidesHelper
  GuideStep = Data.define(:title, :items, :link_label, :path)

  def guide_steps
    [
      GuideStep.new("Importar o pedido", [
        "Em Pedidos, escolha o cliente e clique em Importar planilha.",
        "Um arquivo por vez: processados e in natura vêm em planilhas separadas.",
        "Pedido em ODT ou print: a imagem fica ao lado da grade para digitar olhando.",
        "Pedido por telefone ou WhatsApp: digite direto na grade do cliente."
      ], "Abrir Pedidos", orders_path),
      GuideStep.new("Conferir a planilha", [
        "Antes de gravar, cada célula aparece como novo, alterada ou apaga.",
        "Nome que o sistema não conhece: escolha o produto uma vez e ele aprende.",
        "Célula vazia numa linha com quantidades apaga aquele dia do pedido.",
        "Confira e clique em Aplicar."
      ], "Importar planilha", new_order_import_path),
      GuideStep.new("Conferência", [
        "Alertas da semana: matéria-prima sem fator, unidade diferente, data estranha.",
        "Alerta não bloqueia nada; cada um leva à tela onde se corrige."
      ], "Abrir Conferência", conference_path),
      GuideStep.new("Programação", [
        "O que cada cliente recebe em cada dia de entrega e quando cada item é produzido.",
        "Bata com o pedido original do cliente."
      ], "Abrir Programação", schedule_path),
      GuideStep.new("Enviar a produção", [
        "A produção do dia é calculada dos pedidos, por setor, com os aprontes em caixas.",
        "Confira e clique em Enviar aos setores: vira a versão 1 e os setores recebem aviso no celular.",
        "In natura não entra na produção: vai direto para a compra."
      ], "Abrir Produção", production_path),
      GuideStep.new("Compra da CEASA", [
        "No dia de compra a lista já vem com perdas e estoque abatidos, por fornecedor.",
        "Copie o texto para o WhatsApp de cada fornecedor e clique em Enviar aos fornecedores."
      ], "Abrir Compras", purchases_path),
      GuideStep.new("Quando o pedido muda", [
        "Reimporte a planilha ou edite a grade.",
        "Produção e compra mostram \"Mudou depois do envio\", item a item.",
        "Confira e envie a versão 2. Os setores sempre veem a versão mais recente."
      ], "Abrir Produção", production_path)
    ]
  end
end
