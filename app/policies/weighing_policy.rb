# Pesagem (R2.6): o setor de recepção e pesagem anota o peso real; o escritório confere para o faturamento.
class WeighingPolicy < ApplicationPolicy
  allow :admin, :office, :production, to: %i[show update]
end
