class OrderImportsController < ApplicationController
  authorize_resource :order_import
  before_action :load_customers
  before_action :load_import, only: %i[show apply undo grid settings]

  def new
    @customer = @customers.find { |c| c.code == params[:customer] } || @customers.first
  end

  SHEET_EXTENSIONS = %w[.xlsx .xls .ods .csv].freeze
  IMAGE_EXTENSIONS = %w[.odt .png .jpg .jpeg .webp .gif].freeze

  # Quem lança escolhe o tipo (R1.29 a R1.33, D22). Na alteração e no extra o arquivo é opcional: sem arquivo,
  # abre a grade do pedido da semana da data de entrega escolhida, nesse dia, no modo do tipo (R1.35, R1.36, D23).
  # "week" continua aceito no lugar da data.
  def create
    @customer = @customers.find { |c| c.code == params[:customer] }
    @entry_type = params[:entry_type].to_s
    @date = date_param(:date, nil) || date_param(:week, nil)
    file = params[:file]
    problem = if @customer.nil? then "Escolha o cliente."
    elsif EntryType.missing(@entry_type) then EntryType::MESSAGE
    elsif file.blank? && @entry_type == "new" then "Pedido novo: escolha o arquivo."
    elsif file.blank? && @date.nil? then "Sem arquivo: informe a data de entrega."
    end
    return render_new_with(problem) if problem
    return redirect_to(orders_path(customer: @customer.code, week: @date.beginning_of_week, tipo: @entry_type, dia: @date)) if file.blank?

    imports = Array(read_file(file))
    imports.each { |import| import.update!(payload: import.payload.merge("entry_type" => @entry_type)) unless import.af? }
    redirect_to order_import_path(imports.first)
  rescue OrderImports::SheetReader::Unreadable, OrderImports::OdtReader::Unreadable, OrderImports::AfReader::Unreadable => e
    render_new_with(e.message)
  end

  def show
    return show_afs if @import.af?
    return show_image if @import.image?

    @late_alterations = @import.applied? ? [] : OrderImports::Applier.new(import: @import, mappings: {}).late_alterations
    @preview = OrderImports::Preview.new(@import)
    @products = Product.order(:name).group_by(&:product_group)
    load_undo
  end

  # Pedido em imagem: grava o que foi digitado olhando a imagem, na grade do cliente e da semana.
  def grid
    return head(:not_found) unless @import.image?

    order = image_order
    result = if (missing = EntryType.missing(params[:entry_type]))
      OrderGridSaver::Result.new(errors: [ missing ], changed_dates: [])
    else
      OrderGridSaver.new(order: order, quantities: params.fetch(:quantities, {}).to_unsafe_h, source: "image", import: @import,
                         entry_type: params[:entry_type], late_confirmed: params[:late_confirmed] == "1",
                         explicit_removal: true).call
    end
    if result.ok?
      notice = result.changed_dates.empty? ? "Nada mudou no pedido: as quantidades já eram essas." : "Pedido salvo."
      redirect_to order_import_path(@import), notice: notice, alert: StalePlans.warning(current_company)
    else
      @errors = result.errors
      show_image(status: :unprocessable_entity)
    end
  end

  def settings
    attrs = {}
    attrs[:customer] = @customers.find { |c| c.code == params[:customer] } if params[:customer].present?
    attrs[:week_start] = date_param(:week, @import.week_start).beginning_of_week if params[:week].present?
    # Planilha só sai de "aplicada" desfazendo, para o pedido voltar junto.
    attrs[:status] = params[:status] if @import.image? && %w[pending applied].include?(params[:status])
    @import.update!(attrs.compact)
    redirect_to order_import_path(@import)
  end

  def apply
    return apply_afs if @import.af?

    applier = OrderImports::Applier.new(import: @import, mappings: params.fetch(:mappings, {}).to_unsafe_h,
                                        late_confirmed: params[:late_confirmed] == "1")
    result = applier.call
    if result.ok?
      redirect_to orders_path(customer: @import.customer.code, week: @import.week_start),
                  notice: "Planilha importada no pedido de #{@import.customer.short_name}.", alert: StalePlans.warning(current_company)
    else
      @preview = OrderImports::Preview.new(@import)
      @products = Product.order(:name).group_by(&:product_group)
      @errors = result.errors
      @late_alterations = applier.late_alterations
      render :show, status: :unprocessable_entity
    end
  end

  # Devolve o pedido ao que era antes da planilha. Planos enviados não são reenviados: o aviso diz quais mudaram.
  def undo
    return head(:not_found) if @import.af?

    result = OrderImports::Undoer.new(import: @import).call
    if result.ok?
      redirect_to order_import_path(@import), notice: "Importação desfeita: o pedido de #{@import.customer.short_name} voltou ao que era antes.",
                                              alert: StalePlans.warning(current_company)
    else
      redirect_to order_import_path(@import), alert: result.errors.to_sentence
    end
  end

  private

  def render_new_with(message)
    flash.now[:alert] = message
    @customer ||= @customers.first
    render :new, status: :unprocessable_entity
  end

  def read_file(file)
    extension = File.extname(file.original_filename).downcase
    args = { company: current_company, customer: @customer, path: file.tempfile.path, filename: file.original_filename }
    if SHEET_EXTENSIONS.include?(extension)
      OrderImports::Importer.new(**args).call
    elsif extension == ".pdf"
      OrderImports::AfImporter.new(**args).call
    elsif IMAGE_EXTENSIONS.include?(extension)
      OrderImports::ImageBatch.new(**args, content_type: file.content_type, date: date_param(:date, nil)).call
    else
      raise OrderImports::SheetReader::Unreadable, "Formato não aceito. Envie xlsx, xls, ods, csv, um ODT, uma imagem ou o PDF de AFs."
    end
  end

  def load_customers
    @customers = Customer.order(:name).to_a
  end

  # PDF de AFs: cada AF no pedido da semana da entrega (D2, D3, D4).
  def apply_afs
    result = OrderImports::AfApplier.new(import: @import, late_confirmed: params[:late_confirmed] == "1").call
    if result.ok?
      weeks = result.weeks.map { |week| Formatting.short_date(week) }.to_sentence(last_word_connector: " e ")
      redirect_to orders_path(customer: @import.customer.code, week: result.weeks.first),
                  notice: "AFs de #{@import.customer.short_name} aplicadas nos pedidos das semanas de #{weeks}.", alert: StalePlans.warning(current_company)
    else
      @errors = result.errors
      show_afs(status: :unprocessable_entity)
    end
  end

  def load_import
    @import = OrderImport.find(params[:id])
  end

  def load_undo
    @undoer = OrderImports::Undoer.new(import: @import)
    return unless @undoer.undoable?

    @later_edits = @undoer.later_edits
    @stale_after_undo = @undoer.stale_after_undo
  end

  def show_afs(status: :ok)
    @late_alterations = @import.applied? ? [] : OrderImports::AfApplier.new(import: @import).late_alterations
    render :af, status: status
  end

  def image_order
    Order.find_or_create_by!(customer: @import.customer, week_start: @import.week_start)
  end

  # Modo da grade: ?tipo=extra (acréscimo), ?tipo=total (grade do pedido) ou o tipo escolhido ao importar.
  def show_image(status: :ok)
    @tipo = params[:entry_type].presence || (params[:tipo] == "total" ? nil : params[:tipo].presence || @import.payload["entry_type"])
    @tipo = nil unless OrderVersion::ENTRY_TYPES.key?(@tipo)
    @add_product = Product.find_by(id: params[:add])
    @grid = OrderGrid.new(order: image_order, add_product: @add_product)
    render :image, status: status
  end
end
