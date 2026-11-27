# O recebimento confere o que foi enviado aos fornecedores: quem vê a compra registra o recebido (D47).
class PurchaseReceiptPolicy < ApplicationPolicy
  allow :admin, :office, to: %i[show update]
end
