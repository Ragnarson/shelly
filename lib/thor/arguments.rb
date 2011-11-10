class Thor
  class Arguments

    private

    def parse_array(name)
      return shift if peek.is_a?(Array)
      array = []
      while current_is_value?
        results = shift.split(/[\s,]/).reject(&:blank?)
        results.each { |result| array << result  }
      end
      array
    end

  end
end
