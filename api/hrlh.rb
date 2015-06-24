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
      def interviewer_tb
        database['interviewer']
      end


      def interview_tb
        database['interview']
      end

      def get_all_comments(result)
          result.relations[:attend].map{|interview| interview['comments'][result.key]}.flatten.compact
      end

      def to_interviewer(result)
        interviewer = result.value.merge({"key"=>result.key})
        interviewer["experience"] = work_from_to_experience(interviewer["work_from"])
        scores  = result.relations[:attend] ? get_all_comments(result).map{|comment|comment['score']} : []
        interviewer["avg_score"] = (scores.size > 0 ? (scores.reduce(:+).to_f / scores.size) : 0).round(2)
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
        interviewer_tb
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
          to_interviewer(interviewer_tb[params[:key]])
        end

        put do
          interviewer = interviewer_tb[params[:key]]
          interviewer[:name] = params[:name] if params[:name]
          interviewer[:email] = params[:email] if params[:email]
          interviewer[:language] = params[:language] if params[:language]
          interviewer[:work_from] = experience_to_work_from(params[:experience]) if params[:experience]
          interviewer.save
        end

        delete do
          interviewer_tb.delete(params[:key])
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
          interview = interview_tb[params[:id]]
          interviewers = interview.relations[:attend_by].map{ |i|
            {
              key: i.key,
              name: i.value['name'],
              email: i.value['email']
            }
          }
          interview.value['interviewers']=interviewers

          if interview['comments']
            comments_list = Hash[interview['comments'].map { |interviewer_id, comments|
              [interviewer_id, {name: interviewers.find { |interviewer| interviewer[:key] == interviewer_id }[:name], comments: comments}]
            }]
            interview.value['comments']=comments_list
          end
          interview.value
        end
        params do
          optional :description, type: String
          optional :name, type: String
          optional :date, type: Date
          optional :interviewers, type: Array
        end
        put do
          interview = interview_tb[params[:id]]
          current_interviewer_ids = interview[:interviewers]
          updated = params.reject{ |key,val|val.nil?}
            .map{ |key, val| interview[key] = val if val!=interview[key]}
            .size
          return 201 unless updated
          interview.save
          if params[:interviewers]
            # delete old relatioins
            current_interviewer_ids.each do |id|
              interviewer = interviewer_tb[id]
              interview.relations[:attend_by].delete(interviewer)
              interviewer.relations[:attend].delete(interview)
            end
            # build new relations
            params[:interviewers].each do |id|
              interviewer = interviewer_tb[id]
              interview.relations[:attend_by] << interviewer
              interviewer.relations[:attend] << interview
            end
          end
        end

        delete do
          interview = interview_tb[params[:id]]
          interviewer_ids =  interview.relations[:attend_by].map{|s|s.key}
          interviewer_ids.each do |interviewer_id|
            interviewer = interviewer_tb[interviewer_id]
            interviewer.relations[:attend].delete(interview)
            interview.relations[:attend_by].delete(interviewer)
          end
          interview_tb.delete(params[:id])
        end
      end

      desc 'create interview'
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
                                      interviewers: params[:interviewers],
                                      comments: params.fetch(:comments,{})
                                    })
        return resp if resp.status!=201
        key = resp.location.match(/interview\/(?<key>.*)\/refs/)[:key]

        params[:interviewers].each do |id|
          interviewer_tb[id].relations[:attend] << interview_tb[key]
          interview_tb[key].relations[:attend_by] << interviewer_tb[id]
        end
      end
    end

    resource :interviewers do
      http_basic do |username, password|
        auth! username, password
      end
      
      desc 'get all interviews'
      get do
        interviewer_tb.map{|result| to_interviewer(result)}
      end
    end

    resource :interviews do
      http_basic do |username, password|
        auth! username, password
      end
      desc 'list all interviews'
      get do
        interview_tb.map{ |interview|
          {
            key: interview.key,
            name: interview.value['name'],
            description: interview.value['description']
          }
        }
      end

      resource :query do
        desc 'query interviews'
        params do
          requires :keyword, type: String
        end
        get do
          interview_tb.search("*#{params[:keyword]}*").order(:rank).find.map do |rank,interview|
            {
              key: interview.key,
              name: interview.value['name'],
              description: interview.value['description']
            }
          end
        end
      end
    end
  end
end
