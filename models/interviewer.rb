module HRLH
  class Interviewer
    def initialize result
      @attributes = result ? result.value.merge({"key" => result.key}) : nil
    end
    def to_json
      @attributes
    end
  end
end