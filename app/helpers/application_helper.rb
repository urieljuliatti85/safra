module ApplicationHelper
  def qty(value) = Formatting.qty(value)
  def short_date(date) = Formatting.short_date(date)
  def weekday_date(date) = Formatting.weekday_date(date)
  def need_text(need) = Formatting.need_text(need)

  def plural(count, singular, plural_form)
    "#{count} #{count == 1 ? singular : plural_form}"
  end

  # Antecedência da produção em relação à entrega, em linguagem de cozinha.
  def lead_options
    (0..5).map { |days| [ days.zero? ? "No dia da entrega" : (days == 1 ? "1 dia antes" : "#{days} dias antes"), days ] }
  end

  def nav_link(label, path, controllers)
    current = Array(controllers).include?(controller_name)
    link_to label, path, class: "nav-link", "aria-current": (current ? "page" : nil), data: { reveal_target: ("current" if current) }.compact
  end

  # Navegação de um dia para o anterior/seguinte, mantendo a página.
  def day_nav(date, path_helper)
    tag.div(class: "flex items-center gap-2") do
      safe_join([
        link_to(icon(:chevron_left), send(path_helper, date: date - 1), class: "icon-btn", "aria-label": "Dia anterior"),
        tag.strong("#{weekday_date(date)}/#{date.year}", class: "num min-w-32 text-center"),
        link_to(icon(:chevron_right), send(path_helper, date: date + 1), class: "icon-btn", "aria-label": "Próximo dia")
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
