# Planilha de pedido enviada por um cliente, lida e guardada para conferência antes de entrar no pedido.
class OrderImport < ApplicationRecord
  STATUSES = %w[pending applied].freeze
  KINDS = %w[sheet image].freeze
  IMAGE_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze

  acts_as_tenant :company

  belongs_to :customer
  has_one_attached :image

  scope :images, -> { where(kind: "image") }

  validates :filename, :week_start, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :kind, inclusion: { in: KINDS }
  validate :image_content_type, if: -> { kind == "image" && image.attached? }

  def image?
    kind == "image"
  end

  # Imagens que vieram do mesmo arquivo (um ODT traz várias), na ordem do documento.
  def siblings
    return OrderImport.none unless image? && payload["batch"].present?

    OrderImport.images.where("payload ->> 'batch' = ?", payload["batch"]).order(:id)
  end

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

  private

  def image_content_type
    errors.add(:image, "precisa ser PNG, JPEG, WebP ou GIF") unless IMAGE_TYPES.include?(image.blob.content_type)
  end
end
