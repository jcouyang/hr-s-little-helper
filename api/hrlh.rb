require 'grape'
require 'orchestrate'
require_relative '../models/interviewer'

module HRLH
  class API < Grape::API
    version 'v1', using: :path
    format :json
    prefix :api
    helpers do
      def database
        @database ||= Orchestrate::Application.new(ENV['ORCH_API_KEY'],ENV['ORCH_REGION'])
      end

      def interview_db
        database['interviewer']
      end

      def to_interviewer(result)
        result.value.merge({"key"=>result.key})
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
        interview_db
        .create(
            {
                name: params[:name],
                email: params[:email]
            }
        ).value
      end

      desc 'single interviewer'
      params do
        requires :key, type: String
      end
      route_param :key do
        get do
          to_interviewer(interview_db[params[:key]])
        end

        put do
          interviewer = interview_db[params[:key]]
          interviewer[:name] = params[:name] if params[:name]
          interviewer[:email] = params[:email] if params[:email]
          interviewer.save
        end

        delete do
          interview_db.delete(params[:key])
        end
      end
    end

    resource :interview do
      desc 'create interiew'
      params do
        requires :description, type: String
        requires :name, type: String
        requires :interviewers, type: Array
      end
      post do
        resp = database.client.post('interview', {
                                      description: params[:description],
                                      name: params[:name]
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
        interview_db.map{|result| to_interviewer(result)}
      end
    end

    resource :interviews do
      desc 'list all interviews'
      get do
        database['interview'].map{ |interview|
          {
            key: interview.key,
            name: interview.value['name'],
            description: interview.value['description']
          }
        }
      end
    end
  end
end
