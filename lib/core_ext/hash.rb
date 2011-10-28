class Hash
  def deep_stringify_keys
    new_hash = {}
    self.each do |key, value|
      new_hash.merge!(key.to_s => (value.is_a?(Hash) ? value.deep_stringify_keys : value))
    end
    new_hash
  end

  def deep_symbolize_keys
    new_hash = {}
    self.each do |key, value|
      new_hash.merge!(key.to_sym => (value.is_a?(Hash) ? value.deep_symbolize_keys : value))
    end
    new_hash
  end
end
