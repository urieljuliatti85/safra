# Respostas comuns da API documentadas e testadas em todo endpoint.
module SwaggerShared
  def it_requires_token
    response "401", "token ausente, inválido ou revogado" do
      schema "$ref" => "#/components/schemas/Error"
      let(:Authorization) { "Bearer safra_invalido" }
      run_test! { |response| expect(JSON.parse(response.body).dig("error", "code")).to eq("unauthorized") }
    end
  end

  def it_requires_write_token
    response "403", "token só de leitura" do
      schema "$ref" => "#/components/schemas/Error"
      let(:Authorization) { "Bearer #{issue_token(scope: 'read')}" }
      run_test! { |response| expect(JSON.parse(response.body).dig("error", "code")).to eq("forbidden") }
    end
  end
end

RSpec.configure { |config| config.extend SwaggerShared, type: :request }
