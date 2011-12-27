require "spec_helper"
require "shelly/download_progress_bar"

describe Shelly::DownloadProgressBar do
  before do
    $stderr.stub(:print)
    @bar = Shelly::DownloadProgressBar.new(4444)
  end
  
  it "should inherith from ProgressBar" do
    @bar.should be_kind_of(ProgressBar)
  end
  
  it "should initialize parent with header and given size" do
    @bar.title.should == "Progress"
    @bar.total.should == 4444
  end
  
  describe "#progress_callback" do
    it "should return callback for updating progress bar" do
      @bar.should_receive(:inc).with(10)
      @bar.should_receive(:inc).with(20)
      
      @bar.progress_callback.call(10)
      @bar.progress_callback.call(20)
    end
  end
end
