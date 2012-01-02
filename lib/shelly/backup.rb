module Shelly
  class Backup < Model
    attr_reader :filename, :size, :human_size, :code_name, :kind

    def initialize(attributes = {})
      @filename   = attributes["filename"]
      @size       = attributes["size"]
      @human_size = attributes["human_size"]
      @code_name  = attributes["code_name"]
      @kind       = attributes["kind"]
    end

    def download(callback)
      shelly.download_backup(code_name, filename, callback)
    end
  end
end
