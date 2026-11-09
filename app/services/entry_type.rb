# Tipo de pedido escolhido por quem lança, na grade e no pedido em imagem (R1.29 a R1.33, D22). O sistema não decide
# sozinho: sem tipo, nada é gravado.
module EntryType
  MESSAGE = "Escolha o tipo: pedido novo, alteração (novo total) ou extra (soma).".freeze

  def self.missing(value)
    MESSAGE unless OrderVersion::ENTRY_TYPES.key?(value.to_s)
  end
end
