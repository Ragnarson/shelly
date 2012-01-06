require "progressbar"

module Shelly
  class DownloadProgressBar < ProgressBar
    def initialize(total)
      super("Progress", total)
      self.format_arguments = [:title, :percentage, :bar, :stat_for_file_transfer]
    end

    def progress_callback
      lambda { |size| inc(size) }
    end
  end
end
