require "./base"

module Amber
  module Pipe
    module Headers
      VARY              = "Vary"
      ORIGIN            = "Origin"
      X_ORIGIN          = "X-Origin"
      REQUEST_METHOD    = "Access-Control-Request-Method"
      REQUEST_HEADERS   = "Access-Control-Request-Headers"
      ALLOW_EXPOSE      = "Access-Control-Expose-Headers"
      ALLOW_ORIGIN      = "Access-Control-Allow-Origin"
      ALLOW_METHOD      = "Access-Control-Allow-Method"
      ALLOW_HEADERS     = "Access-Control-Allow-Headers"
      ALLOW_CREDENTIALS = "Access-Control-Allow-Credentials"
      ALLOW_MAX_AGE     = "Access-Control-Max-Age"
    end

    class CORS < Base
      alias OriginType = Array(String | Regex)
      ALLOW_METHODS = %w(PUT PATCH DELETE)
      ALLOW_HEADERS = %w(Accept Content-type)

      property origin, headers, methods, credentials, max_age
      @origin : Origin

      def initialize(
        origins = ["*", %r()],
        @methods = ALLOW_METHODS,
        @headers = ALLOW_HEADERS,
        @credentials = false,
        @max_age : Int32? = 0,
        @expose_headers : Array(String)? = nil,
        @vary : String? = nil
      )
        @origin = Origin.new(origins)
      end

      def call(context : HTTP::Server::Context)
        if @origin.match?(context.request)
          put_response_headers(context)

          Preflight.validate?(context, @methods, @headers) do |context|
            return handle_preflight(context)
          end

          put_expose_header(context)
        end
      end

      private def put_response_headers(context)
        context.response.headers[Headers::ALLOW_CREDENTIALS] = @credentials.to_s if @credentials
        context.response.headers[Headers::ALLOW_ORIGIN] = @origin.request_origin.not_nil!
        context.response.headers[Headers::VARY] = vary unless @origin.any?
      end

      private def handle_preflight(context)
        context.response.headers[Headers::ALLOW_METHOD] = context.request.headers[Headers::REQUEST_METHOD]
        context.response.headers[Headers::ALLOW_HEADERS] = context.request.headers[Headers::REQUEST_HEADERS]
        context.response.headers[Headers::ALLOW_MAX_AGE] = @max_age.to_s if @max_age
		context.response.content_length = 0
		context.halt!
	  end

      private def put_expose_header(context)
        context.response.headers[Headers::ALLOW_EXPOSE] = @expose_headers.as(Array).join(",") if @expose_headers
      end

      private def vary
        String.build do |str|
          str << Headers::ORIGIN
          str << "," << @vary if @vary
        end
      end
    end

    module Preflight
      extend self

      def validate?(context, methods, headers)
        if context.request.method == "OPTIONS"
          yield context
        end
      end

      def valid_method?(request, methods)
		p request.headers[Headers::REQUEST_METHOD]?
        methods.includes? request.headers[Headers::REQUEST_METHOD]?
      end

	  def valid_headers?(request, headers)

	  end
    end

    struct Origin
      getter request_origin : String?
      @filtered_origin : String?

      def initialize(@origins : Array(String | Regex))
      end

      def match?(request)
        return false if @origins.empty?
        return false unless origin_header?(request)
        return true if any?

        @origins.any? do |origin|
          case origin
          when String then origin == request_origin
          when Regex  then origin =~ request_origin
          end
        end
      end

      def any?
        @origins.includes? "*"
      end

      private def origin_header?(request)
        @request_origin ||= request.headers[Headers::ORIGIN]? || request.headers[Headers::X_ORIGIN]?
      end
    end
  end
end
