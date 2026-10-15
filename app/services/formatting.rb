# Formatação pt-BR compartilhada entre views e PDFs.
module Formatting
  WEEKDAYS = %w[Dom Seg Ter Qua Qui Sex Sáb].freeze
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

  # Quantidade a comprar de uma PurchasePlanner::Need: "13 cx", "42,4 kg", "5 mç".
  def need_text(need)
    if need.packages
      "#{need.packages} #{PACKAGE_LABELS.fetch(need.raw_material.purchase_package, need.raw_material.purchase_package)}"
    else
      "#{qty(need.net_kg)} #{need.unit}"
    end
  end
end
