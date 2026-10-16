# Uma aba importada de um dia como estava naquele envio. A versão mais nova é a que vale na comparação; as anteriores
# ficam para mostrar o que mudou de um envio para o outro.
class ReferenceSheetVersion < ApplicationRecord
  acts_as_tenant :company

  Line = Data.define(:section, :label, :quantity_text, :quantity, :unit, :group_label, :delivery_date) do
    def self.from(hash)
      new(section: hash["section"], label: hash["label"], quantity_text: hash["quantity_text"], quantity: hash["quantity"]&.to_d,
          unit: hash["unit"], group_label: hash["group_label"], delivery_date: hash["delivery_date"].presence && Date.parse(hash["delivery_date"]))
    end

    def key = [ section, group_label, delivery_date, label ]

    # A quantidade lida com a unidade ("3 kg", "10 cx") ou, se não deu para ler, como a planilha escreveu ("1.½").
    def text = quantity ? [ Formatting.qty(quantity), unit ].compact.join(" ") : quantity_text.to_s
  end

  Change = Data.define(:section, :group_label, :delivery_date, :label, :before, :after) do
    def kind
      if before.nil? then :added
      elsif after.nil? then :removed
      else :changed
      end
    end
  end

  belongs_to :reference_sheet
  belongs_to :sheet_import, optional: true
  belongs_to :imported_by, class_name: "User", optional: true

  validates :version, presence: true, uniqueness: { scope: :reference_sheet_id }

  def self.snapshot(lines) = lines.map { |line| line.to_h.transform_keys(&:to_s).merge("quantity" => line.quantity&.to_s, "delivery_date" => line.delivery_date&.iso8601) }

  def parsed_lines = @parsed_lines ||= lines.map { |hash| Line.from(hash) }

  def previous = reference_sheet.versions.where(version: ...version).last

  # O que mudou em relação à versão anterior; vazio na primeira versão ou quando nada mudou.
  def changes_from_previous
    before = previous&.texts_by_key || {}
    after = texts_by_key
    return [] if previous.nil?

    (before.keys | after.keys).filter_map do |key|
      next if before[key] == after[key]

      section, group_label, delivery_date, label = key
      Change.new(section: section, group_label: group_label, delivery_date: delivery_date, label: label, before: before[key], after: after[key])
    end.sort_by { |change| [ change.section, change.group_label.to_s, change.delivery_date || Date.new, change.label ] }
  end

  protected

  # Uma linha repetida na aba (o mesmo item duas vezes) aparece junta: "2 cx + 1 cx".
  def texts_by_key = parsed_lines.group_by(&:key).transform_values { |list| list.map(&:text).join(" + ") }
end
