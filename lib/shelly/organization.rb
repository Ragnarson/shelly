module Shelly
  class Organization < Model
    attr_accessor :name, :app_code_names, :redeem_code

    def initialize(attributes = {})
      @name           = attributes["name"]
      @app_code_names = attributes["app_code_names"]
    end

    def apps
      app_code_names.map do |code_name|
        Shelly::App.new(code_name)
      end
    end

    def create
      attributes = {:name => name, :redeem_code => redeem_code}
      shelly.create_organization(attributes)
    end

    def memberships
      @members ||= Array(shelly.members(name)).
        sort_by { |c| c["email"] }
    end

    def owners
      memberships.select { |c| c["owner"] } - inactive_members
    end

    def members
      memberships.select { |c| !c["owner"] } - inactive_members
    end

    def inactive_members
      memberships.select { |c| !c["active"] }
    end

    def send_invitation(email, owner)
      shelly.send_invitation(name, email, owner)
    end

    def delete_member(email)
      shelly.delete_member(name, email)
    end

    def to_s
      name
    end
  end
end
