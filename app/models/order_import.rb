# Planilha de pedido enviada por um cliente, lida e guardada para conferência antes de entrar no pedido.
class OrderImport < ApplicationRecord
  STATUSES = %w[pending applied].freeze

  acts_as_tenant :company

  belongs_to :customer

  validates :filename, :week_start, presence: true
  validates :status, inclusion: { in: STATUSES }

  def applied?
    status == "applied"
  end

  def rows
    payload.fetch("rows", [])
  end

  def dates
    payload.fetch("dates", []).map { |d| Date.iso8601(d) }
  end

  def errors_list
    payload.fetch("errors", [])
  end
end
