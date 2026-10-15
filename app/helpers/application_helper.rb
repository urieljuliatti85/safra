module ApplicationHelper
  def qty(value) = Formatting.qty(value)
  def short_date(date) = Formatting.short_date(date)
  def weekday_date(date) = Formatting.weekday_date(date)
  def need_text(need) = Formatting.need_text(need)

  # Navegação de um dia para o anterior/seguinte, mantendo a página.
  def day_nav(date, path_helper)
    tag.div(class: "flex items-center gap-2") do
      safe_join([
        link_to("‹", send(path_helper, date: date - 1), class: "px-3 py-1 rounded border bg-white", "aria-label": "Dia anterior"),
        tag.strong(weekday_date(date) + "/#{date.year}"),
        link_to("›", send(path_helper, date: date + 1), class: "px-3 py-1 rounded border bg-white", "aria-label": "Próximo dia")
      ])
    end
  end

  def version_label(plan)
    plan ? "Versão #{plan.version} enviada em #{l(plan.sent_at, format: '%d/%m %H:%M')}" : "Ainda não enviada aos setores"
  end

  def change_text(change)
    case change.kind
    when :added then "novo: #{qty(change.after)} #{change.unit}"
    when :removed then "removido (era #{qty(change.before)} #{change.unit})"
    else "#{qty(change.before)} → #{qty(change.after)} #{change.unit}"
    end
  end
end
