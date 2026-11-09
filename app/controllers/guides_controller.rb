# Passo a passo do fluxo da semana, do pedido à compra. Mesmo público do tour guiado.
class GuidesController < ApplicationController
  before_action { authorize :tour, :show? }
  # Escondido junto com o tour enquanto config.x.guides_enabled estiver desligado.
  before_action { redirect_to root_path unless Rails.configuration.x.guides_enabled }

  def show
  end
end
