require 'spec_helper'
require 'orchestrate'

describe HRLH::API do
  let(:database) {double('database')}
  let(:client) {double('client')}
  let(:collection) {double('collection')}
  before do
    allow(database).to receive(:client) {client}
    allow(client).to receive(:ping) { double('status', :status => status)}
    allow(Orchestrate::Application).to receive(:new) { database }
  end

  describe "GET /diagnostic" do
    let(:status) {200}
    it "returns a status" do
      get "/api/v1/diagnostic"
      expect_json({database: status, heartbeat: 'bidong'})
    end
  end

  describe "POST /interviewer" do
    let(:database) {{'interviewer' => collection}}
    let(:interviewer) {{name:'Jichao', email:'jichao@thoughtworks.com'}}
    before do
      allow(collection).to receive(:set) {double(value: interviewer)}
    end
    it "returns new interviewer id" do

      post "/api/v1/interviewer", interviewer
      expect_json(interviewer)
    end
  end

  describe "GET /interviewers" do
    let(:database) {{'interviewer' => collection}}
    let(:interviewer1) {{name:'Jichao', email:'jichao@thoughtworks.com'}}
    let(:interviewer2) {{name:'Ouyang', email:'ouayng@thoughtworks.com'}}
    before do
      expect(collection).to receive(:find_all).and_return([double(value: interviewer1),double(value: interviewer2) ])
    end
    it "returns all interviewers" do

      get "/api/v1/interviewers"
      expect(json_body).to eql([interviewer1,interviewer2])
    end
  end

end
