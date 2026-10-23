# Passo a passo do fluxo da semana, do pedido à compra. Mesmo público do tour guiado.
class GuidesController < ApplicationController
  before_action { authorize :tour, :show? }

  def show
  end
end
