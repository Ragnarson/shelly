module Shelly
  class Organization < Model
    attr_reader :name, :app_code_names

    def initialize(attributes = {})
      @name           = attributes["name"]
      @app_code_names = attributes["app_code_names"]
    end

    def apps
      app_code_names.map do |code_name|
        Shelly::App.new(code_name)
      end
    end
  end
end
