require "./base"

module Amber
  module Pipe
    class Websocket < Base
      def initiallize(@router = Amber::Server.router)
      end

      def call(context : HTTP::Server::Context)
        @router.process_websocket(context.request) if websocket?(context.request)
        call_next(context)
      end

      private def process_websocket(request)
        @router.get_socket_handler(request)
      end

      private def websocket?(request)
        request.headers["Upgrade"]? == "websocket"
      end
    end
  end
end
