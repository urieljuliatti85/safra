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
      GuideStep.new("Programação", [
        "O que cada cliente recebe, por data de entrega, em quatro dias. O Gerente marca cada item: quadrado, produzir no dia; ponto, já pronto.",
        "Em \"Executar em\", o Gerente escolhe o dia em que cada item é feito: a véspera da entrega, ou outro dia para adiantar. Temperos, folhagens e o Yaksoba (marcados com \"Preparo no dia da entrega\" no cadastro do produto) já vêm no dia da entrega.",
        "Bata com o pedido original do cliente."
      ], "Abrir Programação", schedule_path),
      GuideStep.new("Enviar a Planilha de Produção", [
        "A Planilha de Produção de cada dia junta os itens com aquele dia de execução, de todos os clientes.",
        "Confira e clique em Enviar a Planilha de Produção: vira a versão 1.",
        "In natura não entra na produção: vai direto para a compra."
      ], "Abrir Produção", production_path),
      GuideStep.new("Compra da CEASA", [
        "No dia de compra a lista já vem com o volume total de cada matéria-prima, por fornecedor.",
        "Copie o texto para o WhatsApp de cada fornecedor e clique em Enviar aos fornecedores."
      ], "Abrir Compras", purchases_path),
      GuideStep.new("Pesagem", [
        "Na Pesagem, abra o dia de entrega: cada cliente traz os produtos com a quantidade e a unidade do pedido.",
        "Separe, pese e anote o peso real em kg de cada item, inclusive fruta pedida em unidade. Esse peso vai para o faturamento.",
        "O total em kg do cliente aparece quando todos os itens dele foram pesados."
      ], "Abrir Pesagem", weighing_path),
      GuideStep.new("Quando o pedido muda", [
        "Reimporte a planilha ou edite a grade.",
        "Produção e compra mostram \"Mudou depois do envio\", item a item.",
        "Confira e envie a versão 2. A produção sempre vê a versão mais recente."
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
      GuideTopic.new("programacao", "Como a programação é montada", "Nada é digitado: ela sai das linhas de pedido, por cliente e data de entrega.", [
        "Mostra quatro dias de entrega a partir do dia escolhido, mesmo atravessando de uma semana para outra. A mesma programação serve para vários dias.",
        "Cada item traz a quantidade total pedida, sem dividir.",
        "Antes de cada item vem a marca do Gerente de Produção: quadrado, produzir no dia; ponto, já pronto (adiantado). Todo item começa com o quadrado.",
        "A marca fica no item do pedido: aparece em todo período que inclua aquela entrega e continua se a quantidade mudar.",
        "Mudou o pedido, mudou a programação. Ela não tem versão: é sempre a conta do pedido atual."
      ], "Abrir Programação", schedule_path),
      GuideTopic.new("producao", "Como a Planilha de Produção é montada", "Ela sai da escolha do Gerente: o que produzir ou adiantar, e em que dia.", [
        "Entra cada linha de pedido cujo dia de execução (escolhido na Programação; sem escolha, a véspera da entrega ou, no preparo no dia, o dia da entrega) é o dia aberto.",
        "Soma por produto e unidade, com a abertura por cliente e por dia de entrega. As misturas entram pelos ingredientes.",
        "É uma lista só, sem setores.",
        "In natura não entra na produção.",
        "Enviar a Planilha de Produção grava a versão 1. Se o pedido mudar depois, a tela mostra o que mudou para enviar a versão 2."
      ], "Abrir Produção", production_path),
      GuideTopic.new("compras", "Como as compras são calculadas", "A lista da CEASA também é calculada. Ela só é gravada quando você clica em Enviar aos fornecedores.", [
        "Cada linha de pedido vai para a compra do último dia de compra igual ou anterior ao dia de execução dela (sem escolha, a véspera da entrega ou, no preparo no dia, o dia da entrega).",
        "Volume total: o processado vezes o fator de perda da matéria-prima, mais o in natura como foi pedido. Sem fator, ou em outra unidade (un, maço, caixa), entra sem converter e aparece um alerta.",
        "A compra não abate o estoque e não arredonda em caixas.",
        "A lista sai por fornecedor, com o texto pronto para o WhatsApp."
      ], "Abrir Compras", purchases_path),
      GuideTopic.new("cadastros", "O que fica em Cadastros", "A importação não cria produto nem cliente. Ela só ensina apelidos.", [
        "Matérias-primas: fornecedor, fator de perda, kg por caixa ou saco de compra e kg por caixa descascada.",
        "Produtos: matéria-prima + corte (cenoura + cubinhos), grupo e unidade.",
        "Clientes: em cada cliente, os apelidos, ou seja, como ele escreve cada produto. Os nomes que você escolheu na importação ficam aqui. Apelido errado se remove aqui, senão o erro se repete na próxima planilha.",
        "Cortes: o setor de produção e a antecedência de cada corte.",
        "Fornecedores: para quem vai cada lista da CEASA.",
        "Dias de compra: os dias da semana em que se compra na CEASA (segunda e quinta, por padrão)."
      ], "Abrir Cadastros", raw_materials_path)
    ]
  end
end
