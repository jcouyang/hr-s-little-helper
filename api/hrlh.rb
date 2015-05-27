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
      get do
        {
          heartbeat: 'bidong',
          database: database.client.ping.status
        }
      end
    end

    resource :interviewer do
      desc "create interviewer"
      params do
        requires :name, type: String
        requires :email, type: String
      end
      post do
        database['interviewer']
          .create({
                    name: params[:name],
                    email: params[:email]
                  })
          .id
      end
    end
  end
end
