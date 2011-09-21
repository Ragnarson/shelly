class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def present?
    not blank?
  end
end
