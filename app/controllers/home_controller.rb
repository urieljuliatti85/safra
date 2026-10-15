class HomeController < ApplicationController
  authorize_resource :home

  def show
    redirect_to home_path_for(current_user)
  end
end
