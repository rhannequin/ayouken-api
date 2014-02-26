module Sinatra
  module Ayouken
    module Helpers

      def json_status(code, data)
        content_type :json
        status code
        {
          status: code,
          data: data
        }.to_json
      end

      def accept_params(params, *fields)
        h = {}
        fields.each do |name|
          h[name] = params[name] if params[name]
        end
        h
      end

    end
  end
end
