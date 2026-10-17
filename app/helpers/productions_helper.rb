module ProductionsHelper
  # Nome do setor como a empresa usa (do corte), ou "Aprontes".
  def production_sector_label(result, sector)
    return "Aprontes" if sector == ProductionPlanner::APRONTES

    result.items.find { |item| item.product.sector == sector }&.product&.cut&.sector_name || Cut::SECTOR_NAMES[sector]
  end

  # "16/10 às 14:05 · Maria" de uma versão enviada aos setores.
  def production_version_text(plan)
    [ l(plan.sent_at, format: "%d/%m às %H:%M"), plan.sent_by&.name ].compact.join(" · ")
  end

  # Resumo no histórico de envios: "primeiro envio, 22 itens", "igual à v1" ou "3 mudanças em relação à v1".
  def production_version_summary(plan)
    return "primeiro envio, #{plural(plan.to_result.items.size, 'item', 'itens')}" unless plan.previous

    changes = plan.changes_from_previous.size
    changes.zero? ? "igual à v#{plan.previous.version}" : "#{plural(changes, 'mudança', 'mudanças')} em relação à v#{plan.previous.version}"
  end
end
