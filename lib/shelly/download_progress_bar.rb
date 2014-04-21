require "ruby-progressbar"

module Shelly
  class DownloadProgressBar < ProgressBar::Base
    def initialize(total = nil)
      super(:title => "Progress", :total => total, :format => "%a [%B] %p%% %t | %E")
    end

    def progress_callback
      lambda { |inc_size, total_size|
        self.total = total_size if total_size
        self.progress = progress + inc_size
      }
    end
  end
end
