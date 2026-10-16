# Cadastros da empresa, só leitura: para o sistema de fora mapear os códigos.
module Api
  module V1
    class CatalogController < BaseController
      def customers = render(json: { data: Customer.order(:name).map { |record| ApiPresenter.customer_with_address(record) } })

      def suppliers = render(json: { data: Supplier.order(:name).map { |record| ApiPresenter.supplier(record) } })

      def cuts = render(json: { data: Cut.order(:name).map { |record| ApiPresenter.cut(record) } })

      def raw_materials
        render json: { data: RawMaterial.includes(:supplier).order(:name).map { |record| ApiPresenter.raw_material(record) } }
      end

      def products
        render json: { data: Product.includes(:raw_material, :cut).order(:name).map { |record| ApiPresenter.product(record) } }
      end
    end
  end
end
