# Tour guiado pelo fluxo do pedido à compra: para quem lança pedidos e envia aos setores.
class TourPolicy < ApplicationPolicy
  allow :admin, :office, to: %i[show create]
end
