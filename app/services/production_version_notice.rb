# O aviso de uma versão enviada: quais setores mudaram em relação à versão anterior e o texto de cada pessoa,
# que só vê os setores que escolheu acompanhar. Versão igual à anterior não avisa ninguém.
class ProductionVersionNotice
  Message = Data.define(:title, :options)

  SHOWN_CHANGES = 3

  def initialize(plan)
    @plan = plan
    @result = plan.to_result
    @changes = plan.changes_from_previous
  end

  # Setores com itens (primeira versão) ou com mudança (da segunda em diante); "aprontes" quando as caixas mudaram.
  def sectors
    @sectors ||= if @plan.previous.nil? then @result.sectors
    else (@changes.filter_map(&:sector) + (aprontes_changed? ? [ ProductionPlanner::APRONTES ] : [])).uniq
    end
  end

  # nil quando nada do que a pessoa acompanha mudou.
  def message_for(chosen)
    hit = sectors & chosen
    return if hit.empty?

    Message.new(
      title: "Produção #{Formatting.weekday_date(@plan.date)}: v#{@plan.version} enviada",
      options: { body: body(hit), tag: "producao-#{@plan.date.iso8601}", renotify: true, icon: "/icon.png",
                 data: { path: path(hit) } }
    )
  end

  private

  def body(hit)
    return "Primeiro envio: #{hit.map { |sector| label(sector) }.join(', ')}." if @plan.previous.nil?

    shown = @changes.select { |change| hit.include?(change.sector) }
    parts = shown.first(SHOWN_CHANGES).map { |change| "#{change.label}: #{helpers.change_text(change)}" }
    parts << "e mais #{shown.size - SHOWN_CHANGES}" if shown.size > SHOWN_CHANGES
    parts << "Aprontes: caixas mudaram" if hit.include?(ProductionPlanner::APRONTES)
    parts.join("; ")
  end

  def path(hit)
    Rails.application.routes.url_helpers.production_path(date: @plan.date.iso8601, sector: (hit.first if hit.one?))
  end

  def label(sector) = helpers.production_sector_label(@result, sector)

  def aprontes_changed?
    boxes = ->(result) { result.aprontes.to_h { |apronte| [ apronte.raw_material.id, apronte.boxes ] } }
    boxes.call(@plan.previous.to_result) != boxes.call(@result)
  end

  def helpers = ApplicationController.helpers
end
