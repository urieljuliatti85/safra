# Marca que a pessoa já viu o tour, para ele não abrir sozinho de novo.
class ToursController < ApplicationController
  authorize_resource :tour

  def create
    current_user.update!(tour_seen_at: Time.current) if current_user.tour_seen_at.nil?
    head :no_content
  end
end
