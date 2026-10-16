# Nota da equipe que explica uma diferença entre a planilha e o Safra ("pedido mudou por telefone"). Vale enquanto
# os números da linha não mudarem.
class ComparisonNotesController < ApplicationController
  authorize_resource :conference

  KINDS = %w[schedule production purchase].freeze

  def create
    date = date_param(:date, nil)
    return redirect_back_to_sheets(alert: "Linha da comparação inválida.") unless date && KINDS.include?(params[:kind])

    note = ComparisonNote.find_or_initialize_by(kind: params[:kind], section: params[:section].to_s, date: date, item: params[:item].to_s)
    note.assign_attributes(note: params[:note].to_s.strip, planilha: params[:planilha].presence, sistema: params[:sistema].presence, user: current_user)
    if note.save
      redirect_back_to_sheets(notice: "Nota salva: a diferença conta como explicada.", anchor: anchor_for(note))
    else
      redirect_back_to_sheets(alert: note.errors.full_messages.to_sentence, anchor: anchor_for(note))
    end
  end

  def destroy
    note = ComparisonNote.find(params[:id])
    note.destroy!
    redirect_back_to_sheets(notice: "Nota removida.", anchor: anchor_for(note))
  end

  private

  def redirect_back_to_sheets(anchor: nil, **flash)
    redirect_to conference_sheets_path(week: params[:week].presence, anchor: anchor), **flash
  end

  def anchor_for(note) = "dia-#{note.kind}-#{note.date.iso8601}"
end
