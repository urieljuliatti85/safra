# Código estável de um cadastro novo, feito do nome ("Batata baroa" -> "batata_baroa"), sem repetir um existente.
# O código não muda depois: planilhas de referência, seeds e apelidos apontam para ele.
module CodeGenerator
  module_function

  def call(model, name, prefix: nil)
    base = "#{prefix}#{name.to_s.parameterize(separator: '_')}".presence || "#{prefix}item"
    code = base
    suffix = 2
    while model.exists?(code: code)
      code = "#{base}_#{suffix}"
      suffix += 1
    end
    code
  end
end
