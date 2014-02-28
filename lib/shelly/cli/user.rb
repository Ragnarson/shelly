require "shelly/cli/command"
require "shelly/cli/organization"
require "shelly/ssh_keys"

module Shelly
  module CLI
    class User < Command
      namespace :user
      include Helpers

      before_hook :logged_in?, :only => [:list, :add, :new, :create, :delete]

      method_option :organization, :type => :string, :aliases => "-o", :desc => "Specify organization"
      desc "list", "List users with access to organizations"
      def list
        organizations = if options[:organization]
          organization = fetch_organization(options[:organization])
          [organization]
        else
          Shelly::User.new.organizations
        end

        organizations.each do |organization|
          say organization.name, :green
          if organization.memberships.present?
            members_table = organization.owners.map { |owner| [owner["email"], "  | owner"] }
            members_table += organization.members.map { |member| [member["email"], "  | member"] }
            members_table += organization.inactive_members.map { |inactive| [inactive["email"] + " (invited)", "  | #{human_owner(inactive["owner"])}"] }
            print_table(members_table, :ident => 2, :colwidth => 45)
            say_new_line
          end
        end
      rescue Client::NotFoundException => e
        raise unless e.resource == :organization
        say_error "Organization '#{options[:organization]}' not found", :with_exit => false
        say_error "You can list organizations you have access to with `shelly organization list`"
      end

      method_option :organization, :type => :string, :aliases => "-o", :desc => "Specify organization"
      desc "add [EMAIL]", "Add new developer to organization"
      map "new" => :add
      map "create" => :add
      def add(email = nil)
        organization = organization_present?(options[:organization], "user add [EMAIL]")

        user_email = email || ask_for_email({:guess_email => false})
        owner = yes?("Should this user have owner privileges? (yes/no)")
        organization.send_invitation(user_email, owner)

        say "Sending invitation to #{user_email} to work on #{organization} organization", :green
      rescue Client::ForbiddenException
        say_error "You have to be organization's owner to add new members"
      rescue Client::NotFoundException => e
        raise unless e.resource == :organization
        say_error "Organization '#{options[:organization]}' not found", :with_exit => false
        say_error "You can list organizations you have access to with `shelly organization list`"
      rescue Client::ValidationException => e
        if e.errors.include?(["email", "#{email} has been already taken"])
          say_error "User #{email} is already in the organization #{organization}"
        else
          e.each_error { |error| say_error error, :with_exit => false }
          exit 1
        end
      end

      method_option :organization, :type => :string, :aliases => "-o", :desc => "Specify organization"
      desc "delete [EMAIL]", "Remove developer from organization"
      def delete(email = nil)
        organization = organization_present?(options[:organization], "user delete [EMAIL]")

        user_email = email || ask_for_email({:guess_email => false})
        organization.delete_member(user_email)

        say "User #{user_email} deleted from organization #{organization}"
      rescue Client::ForbiddenException
        say_error "You have to be organization's owner to remove members"
      rescue Client::ConflictException => e
        say_error e[:message]
      rescue Client::NotFoundException => e
        if e.resource == :user
          say_error "User '#{user_email}' not found", :with_exit => false
          say_error "You can list users with `shelly user list`"
        elsif e.resource == :organization
          say_error "Organization '#{options[:organization]}' not found", :with_exit => false
          say_error "You can list organizations you have access to with `shelly organization list`"
        else
          raise
        end
      end

      no_tasks do
        def human_owner(owner)
          owner ? "owner" : "member"
        end

        def organization_present?(name, action)
          unless name
            say_error "You have to specify organization", :with_exit => false
            say "Select organization using `shelly #{action} --organization ORGANIZATION_NAME`"
            Shelly::CLI::Organization.new.list
            exit 1
          else
            fetch_organization(name)
          end
        end

        def fetch_organization(name)
          Shelly::Organization.new("name" => name).tap do |org|
            org.members
          end
        end
      end
    end
  end
end
