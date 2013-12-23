# encoding: utf-8

module Shelly
  module CLI
    class Main < Command
      desc "check", "Check if application fulfills Shelly Cloud requirements"
      # Public: Check if application fulfills shelly's requirements
      #         and print them
      # verbose - when true all requirements will be printed out
      #           together with header and a summary at the end
      #           when false only not fulfilled requirements will be
      #           printed
      # When any requirements is not fulfilled header and summary will
      # be displayed regardless of verbose value
      def check(verbose = true)
        structure = Shelly::StructureValidator.new

        if verbose or structure.invalid? or structure.warnings?
          say "Checking Shelly Cloud requirements\n\n"
        end

        print_check(structure.gemfile?, "Gemfile is present",
          "Gemfile is missing in git repository",
          :show_fulfilled => verbose)

        print_check(structure.gemfile_lock?, "Gemfile.lock is present",
          "Gemfile.lock is missing in git repository",
          :show_fulfilled => verbose)

        print_check(structure.config_ru?, "config.ru is present",
          "config.ru is missing",
          :show_fulfilled => verbose)

        print_check(structure.rakefile?, "Rakefile is present",
          "Rakefile is missing",
          :show_fulfilled => verbose)

        print_check(!structure.gem?("shelly"),
          "Gem 'shelly' is not a part of Gemfile",
          "Gem 'shelly' should not be a part of Gemfile.\n    The versions of the thor gem used by shelly and Rails may be incompatible.",
          :show_fulfilled => verbose || structure.warnings?,
          :failure_level => :warning)

        print_check(structure.gem?("shelly-dependencies"),
          "Gem 'shelly-dependencies' is present",
          "Gem 'shelly-dependencies' is missing, we recommend to install it\n    See more at https://shellycloud.com/documentation/requirements#shelly-dependencies",
          :show_fulfilled => verbose || structure.warnings?, :failure_level => :warning)

        print_check(structure.gem?("thin") || structure.gem?("puma"),
          "Web server gem is present",
          "Missing web server gem in Gemfile. Currently supported: 'thin' and 'puma'",
          :show_fulfilled => verbose)

        print_check(structure.gem?("rake"), "Gem 'rake' is present",
          "Gem 'rake' is missing in the Gemfile", :show_fulfilled => verbose)

        print_check(structure.task?("db:migrate"), "Task 'db:migrate' is present",
          "Task 'db:migrate' is missing", :show_fulfilled => verbose)

        print_check(structure.task?("db:setup"), "Task 'db:setup' is present",
          "Task 'db:setup' is missing", :show_fulfilled => verbose)

        cloudfile = Cloudfile.new
        if cloudfile.present?
          cloudfile.clouds.each do |app|
            if app.cloud_databases.include?('postgresql')
              print_check(structure.gem?("pg") || structure.gem?("postgres"),
                "Postgresql driver is present for '#{app}' cloud",
                "Postgresql driver is missing in the Gemfile for '#{app}' cloud,\n    we recommend adding 'pg' gem to Gemfile",
                :show_fulfilled => verbose)
            end

            if app.delayed_job?
              print_check(structure.gem?("delayed_job"),
                "Gem 'delayed_job' is present for '#{app}' cloud",
                "Gem 'delayed_job' is missing in the Gemfile for '#{app}' cloud",
                :show_fulfilled => verbose)
            end

            if app.whenever?
              print_check(structure.gem?("whenever"),
                "Gem 'whenever' is present for '#{app}' cloud",
                "Gem 'whenever' is missing in the Gemfile for '#{app}' cloud",
                :show_fulfilled => verbose)
            end

            if app.sidekiq?
              print_check(structure.gem?("sidekiq"),
                "Gem 'sidekiq' is present for '#{app}' cloud",
                "Gem 'sidekiq' is missing in the Gemfile for '#{app}' cloud",
                :show_fulfilled => verbose)
            end

            if app.thin?
              print_check(structure.gem?("thin"),
                "Web server gem 'thin' is present",
                "Gem 'thin' is missing in the Gemfile for '#{app}' cloud",
                :show_fulfilled => verbose)
            end

            if app.puma?
              print_check(structure.gem?("puma"),
                "Web server gem 'puma' is present",
                "Gem 'puma' is missing in the Gemfile for '#{app}' cloud",
                :show_fulfilled => verbose)
            end
          end
        end

        if structure.valid?
          if verbose
            say "\nGreat! Your application is ready to run on Shelly Cloud"
          end
        else
          say "\nFix points marked with #{red("✗")} to run your application on the Shelly Cloud"
          say "See more about requirements on https://shellycloud.com/documentation/requirements"
        end
        say_new_line

        structure.valid?
      rescue Bundler::BundlerError => e
        say_new_line
        say_error e.message, :with_exit => false
        say_error "Try to run `bundle install`"
      end
    end
  end
end
