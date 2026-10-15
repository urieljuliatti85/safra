# Produção vê a lista do dia (e o PDF), mas só admin e escritório enviam aos setores.
class ProductionPolicy < ApplicationPolicy
  allow :admin, :office, :production, to: :show
  allow :admin, :office, to: :publish
end
