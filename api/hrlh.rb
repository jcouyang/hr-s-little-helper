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

      def auth! name, pass
        URI.decode_www_form_component(name)==ENV['ORCH_REGION']&&pass==ENV['ORCH_API_KEY']
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
      http_basic do |username, password|
        auth! username, password
      end
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
      http_basic do |username, password|
        auth! username, password
      end

      desc 'get interview'
      route_param :id do
        get do
          interview = database['interview'][params[:id]]
          interviewers = interview.relations[:attend_by].map{ |i|
            {
              key: i.key,
              name: i.value['name'],
              email: i.value['email']
            }
          }
          interview.value['interviewers']=interviewers
          interview.value
        end
        params do
          optional :description, type: String
          optional :name, type: String
          optional :date, type: Date
          optional :interviewers, type: Array
        end
        put do
          interview = database[:interview][params[:id]]
          updated = params.reject{ |key,val|val.nil?}
            .map{ |key, val| interview[key] = val if val!=interview[key]}
            .size
          return 201 unless updated
          interview.save
          if params[:interviewers]
            # delete old relatioins
            interview[:interviewers].each do |id|
              interviewer = database[:interviewer][id]
              interview.relations[:attend_by].delete(interviewer)
              interviewer.relations[:attend].delete(interview)
            end
            # build new relations
            params[:interviewers].each do |id|
              interviewer = database[:interviewer][id]
              interview.relations[:attend_by] << interviewer
              interviewer.relations[:attend] << interview
            end
          end
        end
      end

      desc 'create interiew'
      params do
        requires :description, type: String
        requires :name, type: String
        requires :interviewers, type: Array
        requires :date, type: Date
      end
      post do
        resp = database.client.post('interview', {
                                      description: params[:description],
                                      name: params[:name],
                                      date: params[:date],
                                      interviewers: params[:interviewers]
                                    })
        return resp if resp.status!=201
        key = resp.location.match(/interview\/(?<key>.*)\/refs/)[:key]

        params[:interviewers].each do |id| 
          interviewer[id].relations[:attend] << database['interview'][key]
          database['interview'][key].relations[:attend_by] << interviewer[id]
        end
      end
    end

    resource :interviewers do
      http_basic do |username, password|
        auth! username, password
      end
      
      desc 'get all interviews'
      get do
        interview_db.map{|result| to_interviewer(result)}
      end
    end

    resource :interviews do
      http_basic do |username, password|
        auth! username, password
      end
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
