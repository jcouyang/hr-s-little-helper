require 'spec_helper'
require 'score_computer'

describe ScoreComputer do

  describe '#compute_preciseness' do
    let(:comment1){{"score"=>1,"content"=>'c1'}}
    let(:comment2){{"score"=>-1,"content"=>'c1'}}
    let(:comment3){{"score"=>1,"content"=>'c1'}}

    let(:key1){123456}
    let(:key2){654321}

    let(:interview1){{"comments"=>{key1 =>[comment1,comment2,comment3], key2=>[comment2]}}}
    let(:interview2){{"comments"=>{key1 =>[comment2,comment3], key2=>[comment2]}}}

    let(:interviewer1){double(key: key1, relations: {attend:[interview1, interview2]} )}
    it 'should return average precise' do
      expect(ScoreComputer.compute_preciseness(interviewer1)).to be_within(0.0001).of(0.5834)
    end

    context 'interviewer attend interview without comments' do
      let(:interview1){{"comments"=>{key2=>[comment2]}}}
      let(:interview2){{"comments"=>{}}}
      it 'should return 0 as precise' do
        expect(ScoreComputer.compute_preciseness(interviewer1)).to be_within(0.0001).of(0)
      end
    end

    context 'interviewer has no interview' do
      let(:interviewer1) { double(key: key1, relations: {attend: []}) }
      it 'should return 0 as precise' do
        expect(ScoreComputer.compute_preciseness(interviewer1)).to be_within(0.0001).of(0)
      end
    end

    context 'interviewer has no interview(nil)' do
      let(:interviewer1) { double(key: key1, relations: {attend: nil}) }
      it 'should return 0 as precise' do
        expect(ScoreComputer.compute_preciseness(interviewer1)).to be_within(0.0001).of(0)
      end
    end
  end

end