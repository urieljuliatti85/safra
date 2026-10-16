# Importa as planilhas feitas à mão (02 - produção e 03 - compras CEASA) de uma semana, para comparar com o Safra.
class ReferenceSheetsController < ApplicationController
  authorize_resource :conference

  EXTENSIONS = %w[.ods .xlsx .xls].freeze

  def new
    @week = date_param(:week, Date.current).beginning_of_week
  end

  def create
    @week = date_param(:week, Date.current).beginning_of_week
    files = Array(params[:files]).compact_blank
    return fail_with("Escolha pelo menos um arquivo.") if files.empty?

    wrong = files.reject { |file| EXTENSIONS.include?(File.extname(file.original_filename).downcase) }
    return fail_with("Formato não aceito: #{wrong.map(&:original_filename).to_sentence}. Envie ods, xlsx ou xls.") if wrong.any?

    sheets = ReferenceSheets::Importer.new(
      company: current_company, user: current_user, week_start: @week,
      files: files.map { |file| ReferenceSheets::Importer::File.new(path: file.tempfile.path, filename: file.original_filename) }
    ).call
    return fail_with("Nenhuma aba de #{short_date(@week)} a #{short_date(@week + 6)} nesses arquivos. As abas precisam ter a data no nome, como \"TERÇA 13-10-26\".") if sheets.empty?

    redirect_to conference_sheets_path(week: @week.iso8601), notice: "Planilhas lidas: #{imported_text(sheets)}."
  rescue ReferenceSheets::Reader::Unreadable => e
    fail_with(e.message)
  end

  private

  def fail_with(message)
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end

  def imported_text(sheets)
    sheets.group_by(&:kind).map do |kind, list|
      "#{ReferenceSheet::KIND_LABELS.fetch(kind).downcase} de #{list.map { |sheet| short_date(sheet.date) }.to_sentence}"
    end.join("; ")
  end

  def short_date(date) = Formatting.short_date(date)
end
