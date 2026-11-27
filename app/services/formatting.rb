# Formatação pt-BR compartilhada entre views e PDFs.
module Formatting
  WEEKDAYS = %w[Dom Seg Ter Qua Qui Sex Sáb].freeze
  WEEKDAY_NAMES = %w[Domingo Segunda Terça Quarta Quinta Sexta Sábado].freeze
  PACKAGE_LABELS = { "cx" => "cx", "sc" => "sc", "kg" => "kg", "un" => "un" }.freeze

  module_function

  # 12.5 -> "12,5"; 1078.0 -> "1078"; até 3 casas.
  def qty(value)
    return "-" if value.nil?

    ("%.3f" % value.to_f).sub(/(\.\d*?)0+\z/, '\1').sub(/\.\z/, "").tr(".", ",")
  end

  def short_date(date)
    date.strftime("%d/%m")
  end

  def weekday_date(date)
    "#{WEEKDAYS[date.wday]} #{short_date(date)}"
  end

  # Quantidade a comprar de uma PurchasePlanner::Need, com o conteúdo da caixa ou do saco (R4.1, D45):
  # "13 cx de 20 kg", "2 cx de 20 kg e 5 kg", "2 cx de 100 un e 50 un", "42,4 kg", "8 un", "5 mç".
  def need_text(need)
    return "#{qty(need.net_kg)} #{need.unit}" unless need.packages

    package = [ PACKAGE_LABELS.fetch(need.raw_material.purchase_package, need.raw_material.purchase_package), package_content(need) ].compact.join(" de ")
    loose = [ ("#{qty(need.loose_kg)} kg" if need.loose_kg.positive?), ("#{need.loose_units} un" if need.loose_units.positive?) ].compact
    return "#{need.packages} #{package}" if loose.empty?
    return loose.join(" e ") if need.packages.zero?

    "#{need.packages} #{package} e #{loose.join(' e ')}"
  end

  # O que vem em cada caixa ou saco: os kg por embalagem, ou as unidades por embalagem da fruta pedida por unidade.
  # Comprada por unidade (melancia) não tem conteúdo a dizer.
  def package_content(need)
    raw_material = need.raw_material
    return nil if raw_material.purchase_package == "un"
    return "#{qty(raw_material.kg_per_package)} kg" if need.unit == "kg" && raw_material.kg_per_package
    return "#{raw_material.units_per_package} un" if need.unit == "un" && raw_material.units_per_package

    nil
  end
end
