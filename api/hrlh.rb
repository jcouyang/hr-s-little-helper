require 'grape'
require 'orchestrate'

module HRLH
  class API < Grape::API
    version 'v1', using: :path
    format :json
    prefix :api
    helpers do
      def database
        @database ||= Orchestrate::Application.new(ENV['ORCH_API_KEY'],ENV['ORCH_REGION'])
      end
    end
    resource :diagnostic do
      desc "Return a public timeline."
      get do
        {
          heartbeat: 'pong',
          database: database.client.ping.status
        }
      end
    end
  end
end
