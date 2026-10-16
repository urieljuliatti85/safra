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

  def rows_of(comparison) = comparison.rows.to_h { |row| [ row.key, row ] }

  # Só o que a planilha tem e mudou de valor ou de situação.
  def deltas(before_rows, after_rows)
    after_rows.filter_map do |key, after|
      before = before_rows[key]
      next unless after.scored?
      next if before && before.sistema == after.sistema && before.status == after.status

      Delta.new(kind: after.kind, date: after.date, label: after.label, planilha: after.planilha_text || after.planilha,
                before: before&.sistema, after: after.sistema, before_ok: before&.ok? || false, after_ok: after.ok?)
    end.sort_by { |d| [ d.kind.to_s, d.date, d.label ] }
  end
end
