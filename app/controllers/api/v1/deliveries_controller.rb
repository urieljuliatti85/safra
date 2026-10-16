# Entregas de um dia para logística e roteirização: uma parada por cliente, com endereço, janela e carga.
# JSON por padrão; .csv traz uma linha por parada, no formato que roteirizadores importam.
require "csv"

module Api
  module V1
    class DeliveriesController < BaseController
      CSV_COLUMNS = %w[date customer customer_name address district city state postal_code latitude longitude
                       delivery_from delivery_until delivery_notes kg_total other_units items].freeze

      def index
        date = date_param(:date, Date.current)
        stops = DeliveryList.new(company: current_company, date: date).call
        if request.format.csv?
          send_data csv(date, stops), type: "text/csv; charset=utf-8", disposition: "inline"
        else
          render json: ApiPresenter.deliveries(date, stops)
        end
      end

      private

      # BOM no início para o Excel reconhecer o UTF-8.
      def csv(date, stops)
        "﻿" + CSV.generate do |out|
          out << CSV_COLUMNS
          stops.each do |stop|
            c = stop.customer
            out << [ date.iso8601, c.code, c.name, c.address, c.district, c.city, c.state, c.postal_code, c.latitude&.to_f, c.longitude&.to_f,
                     c.delivery_from&.strftime("%H:%M"), c.delivery_until&.strftime("%H:%M"), c.delivery_notes, stop.kg_total.to_f,
                     stop.other_units.map { |unit, quantity| "#{quantity.to_f} #{unit}" }.join("; "), stop.lines.size ]
          end
        end
      end
    end
  end
end
