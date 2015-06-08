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
        .set(
            params[:email],
            {
                name: params[:name],
                email: params[:email]
            },
            false
        ).value
      end
    end

    resource :interview do
      desc 'create interiew'
      params do
        requires :description, type: String
        requires :interviewers, type: Array
      end
      post do
        resp = database.client.post('interview', {
                                      description: params[:description]
                                    })
        return resp if resp.status!=201
        key = resp.location.match(/interview\/(?<key>.*)\/refs/)[:key]

        database['interviewer'].search("email:#{params[:interviewers].join(' or ')}").find.each do |score, interviewer|
          interviewer.relations[:attend] << database['interview'][key]
          database['interview'][key].relations[:attend_by] << interviewer
        end
      end
    end

    resource :interviewers do
      desc 'get all interviews'
      get do
        interviewer =database['interviewer']
        interviewer.find_all.map(&:value)
      end
    end
  end
end
