@name = File.basename(File.expand_path("."))

gem_group :development do
  gem 'shelly', '>= 0.0.62'
end

# check if user has account on shelly
`shelly list`
if $? != 0
  say_custom "shellycloud", "Please log in or register with Shelly Cloud."
  say_custom "shellycloud", "You can do that by running `shelly login` or `shelly register`"
  exit 1
end

required_dbs = %w[postgresql mongodb redis]
required_app_servers = %w[thin]

selected_db = required_dbs.find { |db| scroll? db }
unless selected_db
  say_custom "shellycloud", "Please include a DB choice from: #{required_dbs.join ", "}"
  exit_now = true
end

selected_app_server = required_app_servers.find { |app| scroll? app }
unless selected_app_server
  say_custom "shellycloud", "Please include an App Server choice from: #{required_app_servers.join ", "}"
  exit_now = true
end

exit 1 if exit_now

after_everything do
  framework_env = multiple_choice "Which framework environment?", [
    ['Production', 'production'],
    ['Staging', 'staging']
  ]

  app_name = (@repo_name && @repo_name.size > 0) ? @repo_name : @name
  app_name.gsub!(/\W/, '') # only letters and numbers
  app_name.gsub!("_", "-")

  virtual_server_size = "large"
  if framework_env == "production"
    say_custom "shellycloud", "Using large virtual servers for production environment"
  else
    say_custom "shellycloud", "Using small virtual servers for staging environment"
    virtual_server_size = "small"
  end

  code_name = "#{app_name}-#{framework_env}"

  name = File.basename(".")
  command =  "bundle exec shelly add --code_name #{code_name} "
  command += "--databases=#{selected_db} " if selected_db
  command += "--size=#{virtual_server_size}"

  run command

  say_custom "shellycloud", "Adding Cloudfile to your repo"
  run "git add Cloudfile"
  run "git commit -m 'Added Cloudfile'"

  say_custom "shellycloud", "Pushing code to Shelly Cloud"
  sleep(5) # sleep for ssh key to generate on shelly
  run "git push #{code_name} master"

  say_custom "shellycloud", "Your application in now configured for Shelly Cloud"
  say_custom "shellycloud", "You can start it by running `shelly start`."
  say_custom "shellycloud", "For more information, check https://shellycloud.com/documentation"
end

__END__

name: Shelly Cloud
description: Ruby Cloud Hosting in Europe
author: grk

category: deployment
exclusive: deployment

requires: [compile_assets, serve_static_assets, git, thin]
run_after: [git]
