class IO
  def read_available_bytes
    readpartial(100000)
  end
end
