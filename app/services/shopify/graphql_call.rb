# Executa uma mutation/query GraphQL e junta erros de topo e userErrors.
module Shopify
  class GraphqlCall
    class Error < StandardError; end

    def self.call(client, query, variables = {}, key: nil)
      response = Shopify::AdminSession.graphql(client).query(query: query, variables: variables)
      body = response.body
      errors = Array(body["errors"]).map { |e| e["message"] || e.to_s }
      errors += Array(body.dig("data", key, "userErrors")).map { |e| e["message"] } if key
      raise Error, errors.join("; ") if errors.any?

      key ? body.dig("data", key) : body["data"]
    end
  end
end
