class ScoreComputer
  class << self
    def compute_preciseness interviewer

      avg_precises=[]
      if interviewer.relations[:attend]
        comments_of_each_interview = interviewer.relations[:attend].map { |interview| interview["comments"].fetch(interviewer.key, []) }

        scores_of_each_interview = comments_of_each_interview.map { |comments| comments.map { |comment| comment["score"] } }

        avg_precises = scores_of_each_interview.map { |scores| scores.empty? ? 0 : (scores.select { |s| s>0 }.size.to_f/scores.size).round(4) }
      end
      avg_precises.empty? ? 0 : (avg_precises.reduce(&:+)/avg_precises.size).round(4)
    end
  end
end