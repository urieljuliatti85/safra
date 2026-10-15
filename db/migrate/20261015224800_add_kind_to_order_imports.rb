class AddKindToOrderImports < ActiveRecord::Migration[8.1]
  def change
    # sheet: planilha lida e conferida; image: print ou documento com imagem, digitado olhando a imagem
    add_column :order_imports, :kind, :string, null: false, default: "sheet"
  end
end
