# Pedido de um cliente em uma semana (segunda a segunda). PUT grava as linhas enviadas com o mesmo OrderGridSaver
# da tela: quantidade 0 ou vazia apaga a linha, o que não vem no corpo não muda.
module Api
  module V1
    class OrdersController < BaseController
      before_action :require_write!, only: :update
      before_action :load_order

      def show
        render json: ApiPresenter.order(@order)
      end

      def update
        quantities, errors = quantities_from(params.require(:lines))
        return render_error(:unprocessable_entity, "invalid_lines", "Há linhas inválidas.", details: errors) if errors.any?

        result = OrderGridSaver.new(order: @order, quantities: quantities, source: "api").call
        return render_error(:unprocessable_entity, "invalid_lines", "Há linhas inválidas.", details: result.errors) unless result.ok?

        render json: ApiPresenter.order(@order.reload, changed_dates: result.changed_dates)
                           .merge(stale_plans: StalePlans.dates(current_company).map(&:iso8601))
      end

      private

      def load_order
        customer = Customer.find_by!(code: params.require(:customer))
        week_start = date_param(:week) || raise(ActionController::ParameterMissing, :week)
        raise ActionController::BadRequest, "A semana deve começar na segunda-feira." unless week_start.monday?

        @order = update_action? ? Order.find_or_create_by!(customer: customer, week_start: week_start) : Order.find_or_initialize_by(customer: customer, week_start: week_start)
      end

      def update_action? = action_name == "update"

      # [{ product, unit, date, quantity }] -> { "<product_id>|<unit>" => { "AAAA-MM-DD" => "12,5" } }
      def quantities_from(lines)
        errors = []
        week = @order.week_dates
        products = Product.where(code: lines.filter_map { |line| line[:product] if line.respond_to?(:key?) }).index_by(&:code)
        quantities = lines.each_with_index.with_object({}) do |(line, index), grid|
          next errors << "Linha #{index + 1}: formato inválido." unless line.respond_to?(:key?)

          product = products[line[:product].to_s]
          date = parse_date(line[:date])
          unit = line[:unit].presence || product&.unit
          problem = if product.nil? then "produto \"#{line[:product]}\" não existe"
          elsif date.nil? then "data inválida (use AAAA-MM-DD)"
          elsif !week.cover?(date) then "data fora da semana (#{week.first.iso8601} a #{week.last.iso8601})"
          elsif OrderLine::UNITS.exclude?(unit) then "unidade \"#{unit}\" inválida (use #{OrderLine::UNITS.join(', ')})"
          end
          next errors << "Linha #{index + 1}: #{problem}." if problem

          (grid["#{product.id}|#{unit}"] ||= {})[date.iso8601] = line[:quantity].to_s
        end
        [ quantities, errors ]
      end

      def parse_date(text)
        Date.iso8601(text.to_s)
      rescue Date::Error
        nil
      end
    end
  end
end
