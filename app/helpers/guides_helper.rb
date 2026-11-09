# Etapas da tela "Como funciona": o que fazer em cada tela, na ordem da semana.
module GuidesHelper
  GuideStep = Data.define(:title, :items, :link_label, :path)
  GuideTopic = Data.define(:id, :title, :intro, :items, :link_label, :path)

  def guide_steps
    [
      GuideStep.new("Importar o pedido", [
        "Em Pedidos, escolha o cliente e clique em Importar.",
        "Escolha o tipo: pedido novo, alteração (novo total) ou extra (só o acréscimo; o sistema soma).",
        "Um arquivo por vez: processados e in natura vêm em planilhas separadas.",
        "Pedido em ODT ou print: a imagem fica ao lado da grade para digitar olhando.",
        "Pedido por telefone ou WhatsApp: digite direto na grade do cliente."
      ], "Abrir Pedidos", orders_path),
      GuideStep.new("Conferir a planilha", [
        "Antes de gravar, cada célula aparece como novo, alterada ou apaga.",
        "Nome que o sistema não conhece: escolha o produto uma vez e ele aprende.",
        "Célula vazia numa linha com quantidades apaga aquele dia do pedido.",
        "Confira e clique em Importar no pedido.",
        "Importou errado? Em Pedidos, clique na pill Desfazer da planilha."
      ], "Importar", new_order_import_path),
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

  # Seção "Depois da importação": o que cada tela calcula a partir do pedido e com que critério.
  def guide_after_import
    [
      GuideTopic.new("desfazer", "A importação pode ser desfeita", "Errou o cliente, a semana ou o arquivo? Dá para voltar atrás.", [
        "Em Pedidos, a planilha importada aparece como uma pill vermelha Desfazer. Ela abre a planilha no bloco Desfazer importação.",
        "O pedido volta ao que era antes, só nos produtos e dias que a planilha mexeu.",
        "Os apelidos que a planilha criou são removidos, e os que ela trocou voltam ao produto anterior.",
        "A planilha volta a ficar pendente: corrija e importe de novo, se quiser.",
        "Antes de confirmar, o sistema avisa o que foi mudado no pedido depois da importação: desfazer passa por cima dessas mudanças.",
        "Produção ou compra já enviada não é reenviada sozinha: a tela mostra o que mudou e você envia a nova versão.",
        "Pedido salvo na grade também volta atrás: clique em Versões no topo da tela de Pedidos, abra a versão e clique em Restaurar esta versão.",
        "Cada salvamento que muda o pedido (grade, planilha, imagem, desfazer) vira uma versão, com quem fez, quando e o que mudou. Restaurar grava uma versão nova: nenhuma é apagada."
      ], "Abrir Pedidos", orders_path),
      GuideTopic.new("programacao", "Como a programação é montada", "Nada é digitado: ela sai das linhas de pedido, dia de entrega por dia de entrega.", [
        "Para cada dia de entrega, lista o que cada cliente pediu, separado em processados, in natura e frutas.",
        "Ao lado de cada item vem o dia em que ele é produzido: entrega menos a antecedência do corte (ou a exceção do produto, em Regras).",
        "Domingo não tem produção: o item cai para sábado.",
        "In natura não tem dia de produção: vai direto para a compra.",
        "Mudou o pedido, mudou a programação. Ela não tem versão: é sempre a conta do pedido atual."
      ], "Abrir Programação", schedule_path),
      GuideTopic.new("producao", "Como a produção é calculada", "A produção de um dia junta tudo o que precisa estar pronto naquele dia, de todos os clientes.", [
        "Entra cada linha de pedido cujo dia de produção (entrega menos antecedência) é o dia escolhido.",
        "Soma por produto e unidade, com a abertura por cliente e por dia de entrega.",
        "Separa por setor, conforme o corte: descascados inteiros, cortes manuais, ralados/picados/rodelas, palitos, cubinhos e frutas.",
        "Aprontes: caixas a descascar = kg processado ÷ kg por caixa descascada da matéria-prima, arredondado. Descascados inteiros não entram.",
        "In natura não entra na produção.",
        "Enviar aos setores grava a versão 1 e avisa no celular. Se o pedido mudar depois, a tela mostra o que mudou para enviar a versão 2."
      ], "Abrir Produção", production_path),
      GuideTopic.new("compras", "Como as compras são calculadas", "A lista da CEASA também é calculada. Ela só é gravada quando você clica em Enviar aos fornecedores.", [
        "Cada linha de pedido vai para a compra do último dia de compra igual ou anterior ao dia de produção dela.",
        "Processado em kg: kg in natura = kg processado × fator de perda da matéria-prima. In natura entra como foi pedido.",
        "Sem fator, ou em outra unidade (un, maço, caixa), a quantidade entra sem converter e aparece um alerta.",
        "Abate o estoque da câmara fria: vale a contagem mais recente até o dia da compra, e o que sobra passa para a compra seguinte.",
        "Embalagens = kg a comprar ÷ kg por caixa ou saco, arredondado (mínimo 1). Folhas e itens sem embalagem ficam em kg.",
        "A lista sai por fornecedor, com o texto pronto para o WhatsApp.",
        "Produção antes da primeira compra cadastrada fica fora de qualquer compra: a Conferência avisa."
      ], "Abrir Compras", purchases_path),
      GuideTopic.new("conferencia", "O que é a Conferência", "É a checagem do pedido da semana antes de produzir e comprar. Alerta não bloqueia nada.", [
        "Observações escritas nos pedidos, para ninguém esquecer.",
        "Matéria-prima sem fator de perda: a compra não consegue converter para kg in natura.",
        "A mesma matéria-prima pedida em unidades diferentes (kg e un, por exemplo): não dá para somar.",
        "Matéria-prima sem fornecedor, fator marcado para revisar, entregas no domingo e linhas que ficam fora de qualquer compra.",
        "Quantidade fora do comum: 5 vezes ou mais o que o cliente costuma pedir daquele produto, provável zero a mais.",
        "Cada alerta tem um link para a tela onde se corrige.",
        "Em Sistema × planilhas, os números das planilhas feitas à mão aparecem ao lado do que o Safra calcula, com o motivo provável de cada diferença."
      ], "Abrir Conferência", conference_path),
      GuideTopic.new("regras", "O que são as Regras", "São os critérios de data que a programação, a produção e as compras usam.", [
        "Antecedência por corte: quantos dias antes da entrega cada corte é produzido (0 = no dia da entrega).",
        "Exceções por produto: um produto que foge da regra do corte dele.",
        "In natura: com quantos dias de antecedência o que não é processado entra na compra.",
        "Dias de compra na CEASA: cada compra abastece a produção do dia dela até a véspera da seguinte.",
        "Ver efeito compara a mudança com as planilhas sem gravar nada. Depois de salvar, tudo é recalculado e as versões já enviadas mostram o que mudou."
      ], "Abrir Regras", rules_path),
      GuideTopic.new("cadastros", "O que fica em Cadastros", "A importação não cria produto nem cliente. Ela só ensina apelidos.", [
        "Matérias-primas: fornecedor, fator de perda, kg por caixa ou saco de compra e kg por caixa descascada.",
        "Produtos: matéria-prima + corte (cenoura + cubinhos), grupo e unidade.",
        "Clientes: em cada cliente, os apelidos, ou seja, como ele escreve cada produto. Os nomes que você escolheu na importação ficam aqui. Apelido errado se remove aqui, senão o erro se repete na próxima planilha.",
        "Cortes: o setor de produção e a antecedência de cada corte.",
        "Fornecedores: para quem vai cada lista da CEASA."
      ], "Abrir Cadastros", raw_materials_path)
    ]
  end
end
