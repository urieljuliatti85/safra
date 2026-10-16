# Empresas da plataforma: só o dono da plataforma cria, renomeia e suspende. Não dá acesso aos dados delas.
class CompaniesController < ApplicationController
  authorize_resource :company
  before_action :load_company, only: %i[edit update]

  def index
    @companies = Company.order(:name).to_a
    @users = User.group(:company_id).count
    @last_access = Session.joins(:user).group("users.company_id").maximum("sessions.created_at")
    ActsAsTenant.without_tenant do
      @customers = Customer.group(:company_id).count
      @products = Product.group(:company_id).count
    end
  end

  def new
    load_sources
  end

  def create
    source = Company.find_by(id: params[:catalog_from]) if params[:catalog_from].present? && params[:catalog_from] != "standard"
    result = CompanyOnboarding.new(name: params[:name], admin_name: params[:admin_name], admin_email: params[:admin_email], catalog_from: source).call
    if result.ok?
      redirect_to companies_path, notice: "Empresa #{result.company.name} criada. Administrador: #{result.admin.email_address}, senha provisória: #{result.password} " \
                                          "(aparece só agora; #{result.admin.name} troca no primeiro acesso)."
    else
      @errors = result.errors
      load_sources
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @company.name = params.dig(:company, :name).to_s.strip
    wants_active = ActiveModel::Type::Boolean.new.cast(params.dig(:company, :active))
    if @company == current_company && !wants_active
      @company.errors.add(:base, "Você não pode suspender a empresa em que você mesmo trabalha.")
      return render :edit, status: :unprocessable_entity
    end

    suspend = @company.active? && !wants_active
    @company.active = wants_active unless suspend
    if @company.save
      @company.suspend! if suspend
      redirect_to companies_path, notice: "Empresa #{@company.name} atualizada#{' e suspensa' if suspend}."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_company
    @company = Company.find(params[:id])
  end

  def load_sources
    @sources = Company.order(:name)
  end
end
