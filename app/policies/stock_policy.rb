class StockPolicy < ApplicationPolicy
  allow :admin, :office, :production, to: %i[show update]
end
