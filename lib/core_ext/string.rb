class String
  def dasherize
    self.tr('_', '-')
  end

  def humanize
    self.tr('_', ' ')
  end
end