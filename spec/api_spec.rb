require 'spec_helper'
require 'orchestrate'
require 'timecop'
require 'time'

describe HRLH::API do
  let(:database) { double('database') }
  let(:client) { double('client') }
  let(:collection) { double('collection') }
  let(:interviewer_record_in_db) { double(value: {'name' => 'Jichao', 'email' => 'jichao@thoughtworks.com', 'language'=>'ruby', 'work_from'=>'2011'}, key: key) }
  let(:interviewer) { {name: 'Jichao', email: 'jichao@thoughtworks.com', language: 'ruby', experience: 4} }

  before do
    ENV['ORCH_API_KEY']='asdfadsf'
    ENV['ORCH_REGION']='asdf'
    Timecop.freeze(Time.parse('2015-4-1'))
    allow(database).to receive(:client) { client }
    allow(database).to receive(:[]).with('interviewer').and_return(collection)
    allow(client).to receive(:ping) { double('status', :status => status) }
    allow(Orchestrate::Application).to receive(:new) { database }
  end

  after do
    Timecop.return
  end

  describe "GET /diagnostic" do
    let(:status) { 200 }
    it "returns a status" do
      get "/api/v1/diagnostic"
      expect_json({database: status, heartbeat: 'bidong'})
    end
  end

  describe "POST /interviewer" do

    before do
      allow(collection).to receive(:create) { double(value: interviewer) }
    end
    it "returns new interviewer id" do
      post "/api/v1/interviewer", interviewer
      expect_json(interviewer)
    end
  end

  describe "GET /interviewers" do
    let(:collection) { [double(value: interviewer1_db, key: '001'), double(value: interviewer2_db, key: '002')] }
    let(:interviewer1_db) { {"name"=> 'Jichao', "email"=> 'jichao@thoughtworks.com', "work_from"=> 2011} }
    let(:interviewer2_db) { {"name"=> 'Ouyang', "email"=> 'ouayng@thoughtworks.com', "work_from"=> 2015} }

    let(:interviewer1_modle) { {name: 'Jichao', email: 'jichao@thoughtworks.com', key: '001', work_from: 2011, experience: 4} }
    let(:interviewer2_modle) { {name: 'Ouyang', email: 'ouayng@thoughtworks.com', key: '002', work_from: 2015, experience: 0} }

    it "returns all interviewers" do
      get "/api/v1/interviewers"
      expect(json_body).to eql([interviewer1_modle, interviewer2_modle])
    end
  end

  describe 'GET /interviewer/:id' do
    let(:key) { '123456' }
    let(:collection) { {'123456' => interviewer_record_in_db} }
    it "returns interviewer with key=:id" do
      get "/api/v1/interviewer/#{key}"
      expect(json_body).to eql({name: 'Jichao', email: 'jichao@thoughtworks.com', key: '123456', experience:4, language: 'ruby', work_from: '2011'})
    end
  end

  describe 'PUT /interviewer/:id' do
    let(:key) { '123456' }
    let(:obj_with_key){double}
    let(:collection) { {'123456' => obj_with_key } }
    it "modify interviewer with key=:id" do
      expect(obj_with_key).to receive(:save)
      expect(obj_with_key).to receive(:[]=).with(:name, "Jichao")
      expect(obj_with_key).to receive(:[]=).with(:email, "jichao@thoughtworks.com")
      expect(obj_with_key).to receive(:[]=).with(:language, "ruby")
      expect(obj_with_key).to receive(:[]=).with(:work_from, 2011)
      put "/api/v1/interviewer/#{key}", interviewer
    end
  end

  describe 'DELETE /interviewer/:id' do
    let(:key) { '123456' }
    before do
      allow(collection).to receive(:delete).and_return(true)
    end

    it "delete interviewer with key=:id" do
      delete "/api/v1/interviewer/#{key}"
      expect(collection).to have_received(:delete)
    end
  end
end
