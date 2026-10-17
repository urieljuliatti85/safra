# Produção vê a lista do dia (e o PDF), mas só admin e escritório enviam aos setores.
# draft: ver o cálculo atual, antes do envio. Os setores só veem o que o escritório enviou.
class ProductionPolicy < ApplicationPolicy
  allow :admin, :office, :production, to: :show
  allow :admin, :office, to: %i[publish draft]
end
