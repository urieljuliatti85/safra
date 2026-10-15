# Negado por padrão: cada policy diz, por papel, quais ações libera. Admin entra em todas as listas.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # allow :admin, :office, to: %i[index update]
  def self.allow(*roles, to:)
    roles = roles.map(&:to_s)
    Array(to).each do |action|
      define_method(:"#{action}?") { user.present? && roles.include?(user.role) }
    end
  end
end
