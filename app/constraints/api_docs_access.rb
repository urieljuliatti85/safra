# Quem pode abrir a documentação da API (/api-docs): administrador logado no navegador, de empresa ativa e já com a
# senha definitiva. É quem cria as chaves da API. Para os outros a rota não existe (404), nem o login aparece.
class ApiDocsAccess
  def self.matches?(request)
    session_id = request.cookie_jar.signed[:session_id]
    return false if session_id.blank?

    Session.joins(user: :company)
           .where(users: { active: true, role: "admin", must_change_password: false }, companies: { active: true })
           .exists?(id: session_id)
  end
end
