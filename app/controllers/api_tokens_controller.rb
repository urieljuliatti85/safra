# Chaves da API da empresa: só o admin cria e revoga. O token aparece uma única vez, na resposta da criação
# (nunca vai para o flash nem fica guardado); depois só resta o prefixo para reconhecer a chave.
class ApiTokensController < ApplicationController
  authorize_resource :api_token

  def index
    @tokens = ApiToken.order(revoked_at: :desc, created_at: :desc).sort_by { |token| [ token.revoked? ? 1 : 0, -token.created_at.to_i ] }
  end

  def new
    @token = ApiToken.new(scope: "read")
  end

  def create
    attributes = params.require(:api_token)
    @token, @plain = ApiToken.issue!(company: current_company, name: attributes[:name].to_s.strip, scope: attributes[:scope].to_s)
    response.headers["Cache-Control"] = "no-store"
    render :created
  rescue ActiveRecord::RecordInvalid => error
    @token = error.record
    render :new, status: :unprocessable_entity
  end

  def destroy
    token = ApiToken.find(params[:id])
    token.revoke!
    redirect_to api_tokens_path, notice: "Chave \"#{token.name}\" revogada. Quem a usa passa a receber 401."
  end
end
