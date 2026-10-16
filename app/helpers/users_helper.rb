module UsersHelper
  # Quem já escolheu a própria senha perde essa senha: o aviso diz isso com todas as letras.
  def reset_password_confirmation(user, last_access)
    if user.must_change_password
      "Gerar outra senha provisória para #{user.name}? A provisória anterior deixa de valer."
    else
      seen = last_access ? " e entrou pela última vez em #{l(last_access, format: '%d/%m às %H:%M')}" : ""
      "#{user.name} já escolheu a própria senha#{seen}. Gerar uma provisória nova substitui a senha de #{user.name} e derruba os acessos abertos. " \
        "Só faça isso se #{user.name.split.first} esqueceu a senha. Continuar?"
    end
  end
end
