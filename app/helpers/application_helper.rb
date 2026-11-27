module ApplicationHelper
  def qty(value) = Formatting.qty(value)
  def short_date(date) = Formatting.short_date(date)
  def weekday_date(date) = Formatting.weekday_date(date)
  # 3919.4 -> "3.919,4"; 198.0 -> "198"
  def kg_text(value) = number_with_precision(value, precision: 1, strip_insignificant_zeros: true, delimiter: ".", separator: ",")

  def need_text(need) = Formatting.need_text(need)

  def plural(count, singular, plural_form)
    "#{count} #{count == 1 ? singular : plural_form}"
  end

  # Antecedência da produção em relação à entrega, em linguagem de cozinha.
  def lead_options
    (0..5).map { |days| [ days.zero? ? "No dia da entrega" : (days == 1 ? "1 dia antes" : "#{days} dias antes"), days ] }
  end

  # Telas do menu principal que a pessoa pode abrir. As que têm ícone viram aba na barra de baixo do celular.
  def nav_items
    [
      { label: "Painel", path: dashboard_path, controllers: %w[dashboards], icon: :dashboard, allowed: policy(:dashboard).show? },
      { label: "Pedidos", path: orders_path, controllers: %w[orders], icon: :orders, allowed: policy(:order).index? },
      { label: "Programação", path: schedule_path, controllers: %w[schedules], allowed: policy(:schedule).show? },
      { label: "Produção", path: production_path, controllers: %w[productions], icon: :production, allowed: policy(:production).show? },
      { label: "Compras", path: purchases_path, controllers: %w[purchases], icon: :purchases, allowed: policy(:purchase).show? },
      { label: "Estoque", path: stock_path, controllers: %w[stocks], allowed: policy(:stock).show? },
      { label: "BI", path: indicators_path, controllers: %w[indicators], allowed: policy(:indicator).show? },
      { label: "Conferência", path: conference_path, controllers: %w[conferences], allowed: policy(:conference).show? },
      { label: "Regras", path: rules_path, controllers: %w[rules], allowed: policy(:rule).show? },
      { label: "Cadastros", path: raw_materials_path, controllers: %w[raw_materials products customers suppliers customer_aliases cuts],
        allowed: policy(:raw_material).index? }
    ].select { |item| item[:allowed] }
  end

  def nav_current?(item) = item[:controllers].include?(controller_name)

  def nav_link(item)
    link_to item[:label], item[:path], class: "nav-link", "aria-current": ("page" if nav_current?(item))
  end

  def tab_link(item)
    link_to item[:path], class: "tab", "aria-current": ("page" if nav_current?(item)) do
      safe_join([ icon(item[:icon]), tag.span(item[:label]) ])
    end
  end

  # Navegação de um dia para o anterior/seguinte, mantendo a página.
  # params: o que a navegação mantém de um dia para o outro (ex.: o setor escolhido na produção).
  def day_nav(date, path_helper, **params)
    tag.div(class: "flex items-center gap-2") do
      safe_join([
        link_to(icon(:chevron_left), send(path_helper, date: date - 1, **params), class: "icon-btn", "aria-label": "Dia anterior"),
        tag.strong("#{weekday_date(date)}/#{date.year}", class: "num min-w-32 text-center"),
        link_to(icon(:chevron_right), send(path_helper, date: date + 1, **params), class: "icon-btn", "aria-label": "Próximo dia")
      ])
    end
  end

  def change_text(change)
    case change.kind
    when :added then "novo: #{qty(change.after)} #{change.unit}"
    when :removed then "removido (era #{qty(change.before)} #{change.unit})"
    else "#{qty(change.before)} → #{qty(change.after)} #{change.unit}"
    end
  end

  AUDIT_VERBS = {
    "create" => "criou", "update" => "alterou", "destroy" => "excluiu", "login" => "entrou no sistema",
    "logout" => "saiu do sistema", "login_failed" => "tentou entrar sem sucesso", "password_changed" => "trocou a própria senha"
  }.freeze

  # Uma mudança só: "alterou matéria-prima: Cenoura". Várias: "alterou 12 linhas de pedido".
  def audit_headline(event)
    return audit_log_headline(event.logs.first) if event.logs.one?

    event.logs.group_by { |l| [ l.action, l.auditable_type ] }.map do |(action, type), group|
      "#{AUDIT_VERBS.fetch(action)} #{group.size} #{type.constantize.model_name.human(count: group.size)}"
    end.to_sentence
  end

  def audit_log_headline(log)
    return AUDIT_VERBS.fetch(log.action) if %w[login logout login_failed password_changed].include?(log.action)

    "#{AUDIT_VERBS.fetch(log.action)} #{log.auditable_type.constantize.model_name.human}: #{log.auditable_label}"
  end

  # "Fator: 1,35 → 1,4" / "Nome: Cenoura" (criação ou exclusão mostra só um lado).
  def audit_change_text(attribute, before, after)
    if before.nil? && after.nil? then attribute
    elsif before.nil? then "#{attribute}: #{after}"
    elsif after.nil? then "#{attribute}: era #{before}"
    else "#{attribute}: #{before} → #{after}"
    end
  end
end
