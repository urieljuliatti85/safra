# Medida do palito por vegetal (R2.11 revista em 17/11/2026, D32): a vagem em palitos é 40 × 10 mm; os outros palitos,
# 10 × 10 × 60 mm. O corte "palitos" continua de medida única e passa a ter 10 × 10 × 60 mm; a vagem guarda a sua na
# medida do produto. Só troca o que ainda está como a D26 deixou, para não sobrescrever o que foi editado na tela.
class SetPalitoMeasureByVegetable < ActiveRecord::Migration[8.1]
  OLD_CUT_MEASURE = "40 × 10 mm".freeze
  CUT_MEASURE = "10 × 10 × 60 mm".freeze
  VAGEM_MEASURE = "40 × 10 mm".freeze

  def up
    execute <<~SQL.squish
      UPDATE cuts SET reference_measure = #{connection.quote(CUT_MEASURE)}
      WHERE code = 'palitos' AND reference_measure = #{connection.quote(OLD_CUT_MEASURE)}
    SQL
    execute <<~SQL.squish
      UPDATE products SET default_measure = #{connection.quote(VAGEM_MEASURE)}
      WHERE code = 'vagem_palitos' AND (default_measure IS NULL OR default_measure = '')
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE products SET default_measure = NULL
      WHERE code = 'vagem_palitos' AND default_measure = #{connection.quote(VAGEM_MEASURE)}
    SQL
    execute <<~SQL.squish
      UPDATE cuts SET reference_measure = #{connection.quote(OLD_CUT_MEASURE)}
      WHERE code = 'palitos' AND reference_measure = #{connection.quote(CUT_MEASURE)}
    SQL
  end
end
