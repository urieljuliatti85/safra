# Tabelas planas para ferramentas de BI (Metabase, Power BI, Looker Studio): programação, produção, compras e perdas
# de um período, em JSON ou CSV (.csv na URL). Só leitura.
require "csv"

module Api
  module V1
    class BiController < BaseController
      BiReport::DATASETS.each_key do |dataset|
        define_method(dataset) { render_dataset(dataset) }
      end

      private

      def render_dataset(dataset)
        from = date_param(:from, Date.current.beginning_of_week)
        to = date_param(:to, from + 13)
        raise ActionController::BadRequest, "Período inválido: `to` precisa ser igual ou depois de `from`." if to < from
        raise ActionController::BadRequest, "Período longo demais: no máximo #{BiReport::MAX_DAYS} dias." if (to - from).to_i >= BiReport::MAX_DAYS

        report = BiReport.new(company: current_company, from: from, to: to)
        rows = report.rows(dataset)
        if request.format.csv?
          send_data csv(report.columns(dataset), rows), type: "text/csv; charset=utf-8", disposition: "inline"
        else
          render json: { from: from.iso8601, to: to.iso8601, rows: rows }
        end
      end

      # BOM no início para o Excel reconhecer o UTF-8.
      def csv(columns, rows)
        "﻿" + CSV.generate { |out| (out << columns) && rows.each { |row| out << row.values_at(*columns) } }
      end
    end
  end
end
