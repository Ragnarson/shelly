class Array
  def each_error
    self.each do |index,message|
      yield [index.gsub('_',' ').capitalize, message]
    end
  end
end
