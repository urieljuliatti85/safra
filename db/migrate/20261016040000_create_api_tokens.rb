class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      # O token em si nunca é guardado: só o hash (SHA-256) e os primeiros caracteres para o admin reconhecer a chave.
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.string :scope, null: false, default: "read"
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true
  end
end
