class OrderImportsController < ApplicationController
  before_action :load_customers
  before_action :load_import, only: %i[show apply grid settings]

  def new
    @customer = @customers.find { |c| c.code == params[:customer] } || @customers.first
  end

  SHEET_EXTENSIONS = %w[.xlsx .xls .ods .csv].freeze
  IMAGE_EXTENSIONS = %w[.odt .png .jpg .jpeg .webp .gif].freeze

  def create
    @customer = @customers.find { |c| c.code == params[:customer] }
    file = params[:file]
    if @customer.nil? || file.blank?
      flash.now[:alert] = "Escolha o cliente e o arquivo."
      @customer ||= @customers.first
      return render :new, status: :unprocessable_entity
    end

    extension = File.extname(file.original_filename).downcase
    if SHEET_EXTENSIONS.include?(extension)
      import = OrderImports::Importer.new(company: current_company, customer: @customer, path: file.tempfile.path, filename: file.original_filename).call
    elsif IMAGE_EXTENSIONS.include?(extension)
      import = OrderImports::ImageBatch.new(company: current_company, customer: @customer, path: file.tempfile.path, filename: file.original_filename,
                                            content_type: file.content_type, date: date_param(:date, nil)).call.first
    else
      raise OrderImports::SheetReader::Unreadable, "Formato não aceito. Envie xlsx, xls, ods, csv, um ODT ou uma imagem."
    end
    redirect_to order_import_path(import)
  rescue OrderImports::SheetReader::Unreadable, OrderImports::OdtReader::Unreadable => e
    flash.now[:alert] = e.message
    @customer ||= @customers.first
    render :new, status: :unprocessable_entity
  end

  def show
    return show_image if @import.image?

    @preview = OrderImports::Preview.new(@import)
    @products = Product.order(:name).group_by(&:product_group)
  end

  # Pedido em imagem: grava o que foi digitado olhando a imagem, na grade do cliente e da semana.
  def grid
    return head(:not_found) unless @import.image?

    order = image_order
    result = OrderGridSaver.new(order: order, quantities: params.fetch(:quantities, {}).to_unsafe_h).call
    if result.ok?
      redirect_to order_import_path(@import), notice: "Pedido salvo.", alert: StalePlans.warning(current_company)
    else
      @errors = result.errors
      show_image(status: :unprocessable_entity)
    end
  end

  def settings
    attrs = {}
    attrs[:customer] = @customers.find { |c| c.code == params[:customer] } if params[:customer].present?
    attrs[:week_start] = date_param(:week, @import.week_start).beginning_of_week if params[:week].present?
    attrs[:status] = params[:status] if %w[pending applied].include?(params[:status])
    @import.update!(attrs.compact)
    redirect_to order_import_path(@import)
  end

  def apply
    result = OrderImports::Applier.new(import: @import, mappings: params.fetch(:mappings, {}).to_unsafe_h).call
    if result.ok?
      redirect_to orders_path(customer: @import.customer.code, week: @import.week_start),
                  notice: "Planilha importada no pedido de #{@import.customer.short_name}.", alert: StalePlans.warning(current_company)
    else
      @preview = OrderImports::Preview.new(@import)
      @products = Product.order(:name).group_by(&:product_group)
      @errors = result.errors
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_customers
    @customers = Customer.order(:name).to_a
  end

  def load_import
    @import = OrderImport.find(params[:id])
  end

  def image_order
    Order.find_or_create_by!(customer: @import.customer, week_start: @import.week_start)
  end

  def show_image(status: :ok)
    @add_product = Product.find_by(id: params[:add])
    @grid = OrderGrid.new(order: image_order, add_product: @add_product)
    render :image, status: status
  end
end
