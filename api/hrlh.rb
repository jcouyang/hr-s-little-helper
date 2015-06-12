require 'grape'
require 'orchestrate'
require 'time'
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
        interviewer = result.value.merge({"key"=>result.key})
        interviewer["experience"] = work_from_to_experience(interviewer["work_from"])
        interviewer
      end

      def work_from_to_experience work_from
        work_from ? Time.now.year - work_from.to_i : 0
      end
      
      def experience_to_work_from experience
        experience ? Time.now.year - experience.to_i : Time.now.year
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
        work_from = experience_to_work_from(params[:experience])
        interview_db
        .create(
            {
                name: params[:name],
                email: params[:email],
                work_from: work_from,
                language: params[:language]
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
          interviewer[:language] = params[:language] if params[:language]
          interviewer[:work_from] = experience_to_work_from(params[:experience]) if params[:experience]
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
        interview_db.map{|result| to_interviewer(result)}
      end
    end

  end
end
