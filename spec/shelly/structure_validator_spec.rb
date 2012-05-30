require "spec_helper"

describe Shelly::StructureValidator do
  before do
    File.open("Gemfile", 'w')
    File.open("config.ru", 'w')
    @validator = Shelly::StructureValidator.new
  end

  it "should return Gemfile path" do
    @validator.gemfile_path.should == "Gemfile"
  end

  it "should return Gemfile.lock path" do
    @validator.gemfile_lock_path.should == "Gemfile.lock"
  end

  describe "#gemfile_exists?" do
    context "when Gemfile exists" do
      it "should return true" do
        @validator.gemfile_exists?.should == true
      end
    end

    context "when Gemfile doesn't exist" do
      it "should return false" do
        File.delete("Gemfile")
        @validator.gemfile_exists?.should == false
      end
    end
  end

  describe "#config_ru_exists?" do
    before do
      @config_ru = mock(:path => "config.ru")
      Grit::Repo.stub_chain(:new, :status).and_return([@config_ru])
    end

    context "when config.ru exists" do
      it "should return true" do
        @validator.config_ru_exists?.should == true
      end
    end

    context "when config.ru doesn't exist" do
      it "should return false" do
        Grit::Repo.stub_chain(:new, :status).and_return([])
        @validator.config_ru_exists?.should == false
      end
    end
  end

  describe "#gems" do
    before do
      @thin = mock(:name => "thin")
      @mysql = mock(:name => "mysql")
    end

    it "should return list of used gems" do
      Bundler::Definition.stub_chain(:build, :specs).and_return([@thin, @mysql])
      Bundler::Definition.should_receive(:build).with("Gemfile", "Gemfile.lock", nil)
      @validator.gems.should == ["thin", "mysql"]
    end

    context "when gemfile doesn't exist" do
      it "should return empty array" do
        File.delete("Gemfile")
        @validator.gems.should == []
      end
    end
  end
end
