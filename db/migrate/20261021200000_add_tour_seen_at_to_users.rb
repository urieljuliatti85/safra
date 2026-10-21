# Tour guiado: abre sozinho no primeiro acesso de cada pessoa; depois só pelo botão no canto da tela.
class AddTourSeenAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :tour_seen_at, :datetime
  end
end
