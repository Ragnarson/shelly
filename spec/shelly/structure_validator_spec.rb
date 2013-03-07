require "spec_helper"

describe Shelly::StructureValidator do
  before do
    @validator = Shelly::StructureValidator.new
    @validator.stub(:repo_paths => ["Gemfile", "Gemfile.lock", "config.ru", "Rakefile"])
  end

  describe "#gemfile?" do
    context "when Gemfile exists" do
      it "should return true" do
        @validator.gemfile?.should == true
      end
    end

    context "when Gemfile doesn't exist" do
      it "should return false" do
        @validator.stub(:repo_paths => ["Gemfile.lock"])
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
        @validator.stub(:repo_paths => ["Gemfile"])
        @validator.gemfile_lock?.should == false
      end
    end
  end

  describe "#config_ru?" do
    context "when config.ru exists" do
      it "should return true" do
        @validator.config_ru?.should == true
      end
    end

    context "when config.ru doesn't exist" do
      it "should return false" do
        @validator.stub(:repo_paths => ["Gemfile.lock"])
        @validator.config_ru?.should == false
      end
    end
  end

  describe "#rakefile?" do
    context "when Rakefile exists" do
      it "should return true" do
        @validator.rakefile?.should be_true
      end
    end

    context "when Rakefile doesn't exist" do
      it "should return false" do
        @validator.stub(:repo_paths => ["Gemfile"])
        @validator.rakefile?.should be_false
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

    context "when gemfile doesn't exist" do
      it "should return false" do
        @validator.stub(:gemfile? => false)
        @validator.gem?("thin").should be_false
      end
    end

    context "when gemfile.lock doesn't exist" do
      it "should return false" do
        @validator.stub(:gemfile_lock? => false)
        @validator.gem?("thin").should be_false
      end
    end
  end

  describe "#task?" do
    before do
      @validator.should_receive(:'`').at_most(1).with("rake -P").and_return("rake db:migrate")
      @validator.stub(:rakefile? => true)
    end

    it "should return true if task is present" do
      @validator.task?("db:migrate").should be_true
    end

    it "should return false if task is missing" do
      @validator.task?("db:setup").should be_false
    end

    context "when Rakefile doesn't exist" do
      it "should return false" do
        @validator.stub(:rakefile? => false)
        @validator.task?("db:migrate").should be_false
      end
    end
  end
end
