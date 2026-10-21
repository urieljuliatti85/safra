# Tour guiado pelo fluxo da semana, do pedido à compra. Cada passo abre uma tela e destaca um elemento dela
# (seletor CSS); se o elemento não estiver na tela (dia sem compra, por exemplo), o passo aparece no centro.
module TourHelper
  # Abre sozinho no primeiro acesso, depois da troca da senha provisória.
  def tour_autostart?
    current_user.tour_seen_at.nil? && !current_user.must_change_password
  end

  def tour_steps
    return [] unless authenticated? && policy(:tour).show?

    [
      { path: orders_path, target: "nav[aria-label='Clientes']", title: "Pedidos de cada cliente",
        text: "Só o pedido é digitado. Escolha o cliente aqui; a grade logo abaixo é o pedido dele na semana." },
      { path: orders_path, target: "[data-tour='import']", title: "1. Importar a planilha",
        text: "Pedido que chegou em Excel entra por aqui. Pedido por telefone ou WhatsApp é digitado direto na grade." },
      { path: new_order_import_path, target: "#file", title: "Um arquivo por vez",
        text: "Escolha o cliente e o arquivo. Processados e in natura vêm em planilhas separadas: importe cada uma." },
      { path: new_order_import_path, target: "[data-tour='send-file']", title: "2. Conferir antes de gravar",
        text: "Ao enviar, cada célula aparece como novo, alterada ou apaga. Nome que o sistema não conhece: escolha o produto " \
              "uma vez e ele aprende. Célula vazia numa linha com quantidades apaga aquele dia. Confira e clique em Aplicar." },
      { path: conference_path, target: ".alert-list", title: "3. Conferência",
        text: "Alertas da semana: matéria-prima sem fator, unidade diferente, data estranha. Cada alerta leva à tela onde se corrige." },
      { path: schedule_path, target: "main .panel", title: "4. Programação",
        text: "O que cada cliente recebe em cada dia de entrega e quando cada item é produzido. Bata com o pedido original." },
      { path: production_path, target: "section[aria-label='Estado do envio']", title: "5. Enviar a produção aos setores",
        text: "A produção do dia é calculada dos pedidos. Confira e clique em Enviar aos setores: vira a versão 1 e os setores " \
              "recebem aviso no celular. In natura não entra aqui: vai direto para a compra." },
      { path: production_path, target: "nav[aria-label='Setores']", title: "Lista de cada setor",
        text: "Cada setor vê só a versão enviada, na tela ou no PDF, com os aprontes em caixas." },
      { path: purchases_path, target: "[data-controller='copy']", title: "6. Compra da CEASA",
        text: "No dia de compra a lista já vem com perdas e estoque abatidos, por fornecedor. Copie o texto para o WhatsApp " \
              "de cada um e clique em Enviar aos fornecedores." },
      { path: production_path, target: "section[aria-label='Estado do envio']", title: "7. Quando o pedido muda",
        text: "Reimporte a planilha ou edite a grade. Produção e compra mostram \"Mudou depois do envio\" item a item: " \
              "confira e envie a versão 2." },
      { path: production_path, target: "[data-tour='tab']", title: "Sempre que precisar",
        text: "O tour fica neste botão, no canto da tela, em todas as páginas." }
    ]
  end
end
