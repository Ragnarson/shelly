require "spec_helper"
require "shelly/download_progress_bar"

describe Shelly::DownloadProgressBar do
  before do
    $stdout.stub(:print)
    @bar = Shelly::DownloadProgressBar.new(4444)
  end

  it "should inherith from ProgressBar" do
    @bar.should be_kind_of(ProgressBar::Base)
  end

  it "should initialize parent with size" do
    @bar.total.should == 4444
  end

  describe "#progress_callback" do
    it "should return callback for updating progress bar" do
      @bar.should_receive(:total=).with(1000)
      @bar.should_receive(:progress=).with(10)


      @bar.progress_callback.call(10, 1000)
    end
  end
end
