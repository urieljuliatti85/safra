# Contagem da câmara fria por matéria-prima e dia. PUT usa o mesmo StockCountSaver da tela:
# kg vazio ou nulo apaga a contagem (não contado); 0 é câmara vazia.
module Api
  module V1
    class StocksController < BaseController
      before_action :require_write!, only: :update

      def show
        date = date_param(:date, Date.current)
        counts = StockCount.where(date: date).includes(:raw_material).sort_by { |count| count.raw_material.name }
        previous = StockCount.where(date: ...date).includes(:raw_material).order(:date)
                             .each_with_object({}) { |count, latest| latest[count.raw_material_id] = count }.values
        render json: ApiPresenter.stock(date, counts, previous)
      end

      def update
        date = date_param(:date) || raise(ActionController::ParameterMissing, :date)
        entries = params.require(:counts)
        codes = entries.filter_map { |entry| entry[:raw_material] if entry.respond_to?(:key?) }
        materials = RawMaterial.where(code: codes).index_by(&:code)
        unknown = codes.uniq - materials.keys
        return render_error(:unprocessable_entity, "unknown_raw_material", "Matéria-prima inexistente.", details: unknown) if unknown.any?

        counts = entries.each_with_object({}) { |entry, grid| grid[materials.fetch(entry[:raw_material]).id.to_s] = entry[:kg].to_s }
        result = StockCountSaver.new(date: date, counts: counts).call
        return render_error(:unprocessable_entity, "invalid_counts", "Há contagens inválidas.", details: result.errors) unless result.ok?

        render json: { date: date.iso8601, changed: result.changed }
      end
    end
  end
end
