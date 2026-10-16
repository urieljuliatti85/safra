# Mostra o efeito de uma mudança de regra sem gravar: compara o placar contra as planilhas antes e depois,
# aplicando a mudança dentro de uma transação que é sempre desfeita.
class RuleSimulation
  Delta = Data.define(:kind, :date, :label, :planilha, :before, :after, :before_ok, :after_ok)
  Result = Data.define(:errors, :before_score, :after_score, :deltas) do
    def improved = deltas.count { |d| !d.before_ok && d.after_ok }
    def worsened = deltas.count { |d| d.before_ok && !d.after_ok }
  end

  def initialize(company:, changes:)
    @company = company
    @changes = changes
  end

  def call
    before = SheetComparison.new(@company)
    before_rows = rows_of(before)
    errors = []
    after_rows = nil
    after = nil
    ActiveRecord::Base.transaction do
      errors = ActsAsTenant.with_tenant(@company) { @changes.apply!(@company) }
      if errors.empty?
        after = SheetComparison.new(@company)
        after_rows = rows_of(after)
      end
      raise ActiveRecord::Rollback
    end
    @company.reload # a transação desfeita não devolve os atributos já alterados em memória
    return Result.new(errors: errors, before_score: before.scores, after_score: nil, deltas: []) if errors.any?

    Result.new(errors: [], before_score: before.scores, after_score: after.scores, deltas: deltas(before_rows, after_rows))
  end

  private

  def rows_of(comparison)
    comparison.production_rows.to_h { |r| [ [ :production, r.date, r.product ], r ] }
              .merge(comparison.purchase_rows.to_h { |r| [ [ :purchase, r.date, r.raw_material ], r ] })
  end

  # Só o que a planilha tem e mudou de valor ou de situação, com o nome do produto ou da matéria-prima.
  def deltas(before_rows, after_rows)
    names = names_for(after_rows.keys)
    after_rows.filter_map do |key, after|
      before = before_rows[key]
      next if after.planilha.nil?
      next if before && before.sistema == after.sistema && before.status == after.status

      kind, date, code = key
      Delta.new(kind: kind, date: date, label: names.fetch([ kind, code ], code), planilha: after.try(:planilha_text) || after.planilha,
                before: before&.sistema, after: after.sistema, before_ok: before&.status == "ok", after_ok: after.status == "ok")
    end.sort_by { |d| [ d.kind.to_s, d.date, d.label ] }
  end

  def names_for(keys)
    codes = keys.group_by(&:first).transform_values { |list| list.map(&:last).uniq }
    ActsAsTenant.with_tenant(@company) do
      Product.where(code: codes[:production]).pluck(:code, :name).to_h { |code, name| [ [ :production, code ], name ] }
             .merge(RawMaterial.where(code: codes[:purchase]).pluck(:code, :name).to_h { |code, name| [ [ :purchase, code ], name ] })
    end
  end
end
