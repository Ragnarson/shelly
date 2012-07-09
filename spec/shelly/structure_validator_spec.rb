require "spec_helper"

describe Shelly::StructureValidator do
  before do
    @validator = Shelly::StructureValidator.new
    Grit::Repo.stub_chain(:new, :status).and_return([
      mock(:path => "Gemfile"), mock(:path => "Gemfile.lock")
    ])
  end

  describe "#gemfile?" do
    context "when Gemfile exists" do
      it "should return true" do
        @validator.gemfile?.should == true
      end
    end

    context "when Gemfile doesn't exist" do
      it "should return false" do
        Grit::Repo.stub_chain(:new, :status) \
          .and_return([mock(:path => "Gemfile.lock")])
        @validator.gemfile?.should == false
      end
    end
  end

  describe "#gemfile_lock?" do
    context "when Gemfile.lock exists" do
      it "should return true" do
        @validator.gemfile_lock?.should == true
      end
    end

    context "when Gemfile.lock doesn't exist" do
      it "should return false" do
        Grit::Repo.stub_chain(:new, :status) \
          .and_return([mock(:path => "Gemfile")])
        @validator.gemfile_lock?.should == false
      end
    end
  end

  describe "#config_ru?" do
    before do
      Grit::Repo.stub_chain(:new, :status) \
        .and_return([mock(:path => "config.ru")])
    end

    context "when config.ru exists" do
      it "should return true" do
        @validator.config_ru?.should == true
      end
    end

    context "when config.ru doesn't exist" do
      it "should return false" do
        Grit::Repo.stub_chain(:new, :status).and_return([])
        @validator.config_ru?.should == false
      end
    end
  end

  describe "#gem?" do
    before do
      @validator.stub(:gemfile? => true, :gemfile_lock? => true)
      Bundler::Definition.stub_chain(:build, :specs).and_return(
        [mock(:name => "thin"), mock(:name => "mysql")])
    end

    it "should return true if gem is present" do
      @validator.gem?("thin").should be_true
    end

    it "should return false if gem is missing" do
      @validator.gem?("rake").should be_false
    end
  end
end
