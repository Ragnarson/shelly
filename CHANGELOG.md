# master

* [feature] `shelly config create` will check if config already exists in
  specified path
* [bugfix] With multiple clouds in `Cloudfile`, `shelly config create`
  should not open the editor if no cloud is specified
* [bugfix] Fixed wrong usage values given by `shelly info`

## 0.4.29 / 2014-03-27

* [bugfix] Use childprocess to start ssh related commands. Fixes tty issue
  when using `shelly console` on JRuby
* [bugfix] Capture password without echo only if terminal is present
* [feature] Support for `shelly ssh` command

## 0.4.28 / 2014-03-25

* [bugfix] Fix password no_echo input on Ruby 1.9
* [improvement] Show clockwork output in deployment logs

## 0.4.27 / 2014-03-19

* [bugfix] Don't send body with GET and HEAD requests
* [bugfix] Disable echo when providing password for JRuby users

## 0.4.26 / 2014-03-05

* [feature] Removed monitoring_email from Cloudfile

## 0.4.25 / 2014-02-28

* [bugfix] Print user-friendly message if user tries to open console on non
 application virtual server
* [improvement] Add `add` alias for `shelly config create`
* [improvement] Add `new` and `create` aliases for `shelly user add`
* [improvement] Add `new` alias for `shelly backup create`
* [improvement] Add `new` and `create` aliases for `shelly organization add`

## 0.4.24 / 2014-02-25

* [improvement] Show recent information about filesystem, database and traffic
  usage in `shelly info` output

## 0.4.23 / 2014-02-17

* [improvement] Force pseudo-tty allocation when connection via ssh - fixes ssh
  connection on jruby

## 0.4.22 / 2014-02-07

* [improvement] Update shelly after confirmation
* [improvement] User can specify SSH public key to be
  uploaded with `shelly login --key PATH` (Done by https://github.com/we5)

## 0.4.21 / 2014-01-15

* [improvement] destination path when uploading files to Shelly Cloud
  `shelly files upload source destination`

## 0.4.20 / 2014-01-14

* [improvement] add 2.1.0 and rbx to supported ruby versions
* [improvement] `shelly deploy show` will show output of the on_restart hook

## 0.4.19 / 2013-12-26

* [bugfix] `shelly delete` fixed remove git remote when deleting cloud
* [improvement] `shelly check` makes sure Ruby defined in Gemfile is supported
* [improvement] use Ruby defined in Gemfile to create Cloudfile
* [bugfix] shelly cert arguments inline help reorderd

## 0.4.18 / 2013-12-17

* [improvement] `shelly add` should ask about databases instead of database
* [improvement] Improved messages displayed while deleting the application

## 0.4.17 / 2013-12-03

* [bugfix] Remove ssh_key from Shelly Cloud only if it was already uploaded

## 0.4.16 / 2013-11-26

* [improvement] Validate kind when importing database backup

## 0.4.15 / 2013-11-19

* [bugfix] Deleting SSH key works even after changing user email at the end
  of it

## 0.4.14 / 2013-11-19

* [bugfix] Show proper error message when login failed
* [bugfix] `shelly backups create` without specified database kind should
  backup all possible databases, read from Cloudfile

## 0.4.13 / 2013-11-11

* [improvement] Don't upload SSH key on register,
  it will be uploaded at login which is required anyway after register

* internal changes

## 0.4.12 / 2013-11-05

* [bugfix] Print user-friendly message if user tries to operate on files
  on cloud which is not deployed.

## 0.4.11 / 2013-10-30

* internal changes

## 0.4.10 / 2013-10-30

* [bugfix] Certificates CLI were not Ruby 1.8 compatible
* [bugfix] Travis was failing due to Ruby 1.8 gems incompatibility: guard, mime-types v2.x

## 0.4.9 / 2013-10-29

* [improvement] Show logs from after_successful_deploy deployment hook

## 0.4.8 / 2013-10-28

* [improvement] Deployment log callbacks split into separate entities

## 0.4.7 / 2013-10-18

* [feature] Mange SSL certificate with `shelly cert`

## 0.4.6 / 2013-10-01

* [bugfix] `shelly delete` removes proper git remote.
* [improvement] List all supported services in generated Cloudfile.

## 0.4.5 / 2013-09-24

* [improvement] Print user-friendly message for bad .netrc file permission.
* [improvement] Added 'Running' prefix for commands executed by gem.

## 0.4.4 / 2013-09-10

* [bugfix] Do not show `shelly deploys show last` instruction if last deployment was made by admin and was failed.
* [improvement] There is no longer configuration_failed state for apps.
* [bugfix] Do not create new branch after running `shelly setup`
* [bugfix] Consistent output for `shelly setup` if git remote already exists and if not

## 0.4.2 / 2013-08-29

* [improvement] Use thor version without binaries

## 0.4.1 / 2013-08-26

* [feature] Upload existing config file with `shelly config upload PATH`
* [improvement] Reorganised displaying deploy logs
* [improvement] Show next action depending on cloud state when adding configuration file

## 0.4.0 / 2013-08-13

* [feature] Added `shelly organization add` to create new organizations
* [improvement] Create organization and cloud separately

## 0.3.8 / 2013-08-05

* [bugfix] Show proper path when asking to delete configuration file
* [improvement] Removed `git push` from instructions given by `shelly add`

## 0.3.7 / 2013-07-30

* [improvement] Show warning if application Gemfile contains shelly gem.

## 0.3.6 / 2013-07-22

* [bugfix] Specified remote name is added while creating new app.

## 0.3.5 / 2013-07-17

* [feature] Create SSH tunnels to databases which allow to use third-party database tools.
* [bugfix] Handle case when no deployment logs are available

## 0.3.4 / 2013-07-02

* [improvement] consistent output for `shelly start`, `shelly stop` and deployment progress

## 0.3.3 / 2013-06-28

* [feature] user is able to access MongoDB console
* [feature] user is able to access redis-cli

## 0.3.2 / 2013-06-28

* [improvement] API changes to handle user virtual server interactions

## 0.3.1 / 2013-06-28

* [feature] `shelly database reset` reset PostgreSQL or MongoDB database, also possible to use with `shelly backup import DB_KIND dump --reset` option
* [improvement] Puma starting/stopping output shows up in deployment logs
* [improvement] Affects all commands using ssh connection:
    * `shelly backup import` works when deployment failed
    * `shelly dbconsole` works if database was configured
    * `shelly files *` works if virutal server was at least configured

## 0.3.0 / 2013-06-23

* [improvement] API key is now stored in .netrc

## 0.2.28 / 2013-06-18

* [improvement] user can answer 'y' to 'yes/no' questions

## 0.2.27 / 2013-06-11

* [feature] user is able to download logs for a given day by `shelly logs get [DATE]`

## 0.2.26 / 2013-06-10

* [bug] `shelly backup import` now actually compresses the file (bzip2 is used)
* [improvement] `shelly backup import` also accepts path to dump file

## 0.2.25 / 2013-06-06

* [feature] It's possible to import PostgreSQL and MongoDB database from a dump file with `shelly backup import KIND FILENAME`. See our documentation for more info https://shellycloud.com/documentation/database_backups#import_database

## 0.2.24 / 2013-06-04

* [bug] exit gracefully when downloaded or restored database backup doesn't exist
* [bug] 'shelly config list' doesn't quit with error if cloud has no configuration files
* [improvement] 'shelly backup download' is now aliased to 'shelly backup get'

## 0.2.23 / 2013-05-25

* [bug] `shelly add` ask for existing organization if user owns at least one
* [improvement] Ask for git remote name if default is already taken when adding or setting up cloud

## 0.2.22 / 2013-05-20

* [improvement] default application name is created without -staging/-production suffix
* [improvement] git remote created after `shelly add` and `shelly setup` is named 'shelly'

## 0.2.21 / 2013-05-13

* [improvement] require 'puma' or 'thin' gems if present in Cloudfile when running `shelly check`

## 0.2.20 / 2013-05-09

* [improvement] `shelly info`, `shelly list` and `shelly organization list` now use the new state_description attribute returned by Shelly API

## 0.2.19 / 2013-05-06

* [improvement] warn user that his public SSH key will be uploaded on login and register.

## 0.2.18 / 2013-04-25

* [bug] `shelly add` doesn't prompt the user to provide billing details when adding to existing organization.

## 0.2.17 / 2013-04-12

* [feature] Added '--cloud code_name' to command given in output after failed `shelly redeploy` and `shelly stop`.

## 0.2.16 / 2013-04-04

* [bug] `shelly add` now properly sets puma as web server when run under JRuby
* [bug] `shelly add` now properly sets jruby as ruby_version when run under JRuby

## 0.2.15 / 2013-03-28

* [feature] `shelly files list [PATH]` lists files from cloud's disk
* [feature] Destination virtual server for `shelly console` can be specified.
Example `shelly console --server app1`. When not specyfied virtual server is chosen randomly.

## 0.2.14 / 2013-03-28

* [bug] Structure validator recognizes puma as allowed web server

## 0.2.13 / 2013-03-28

* [improvement] More verbose output for redeploy, start and stop

## 0.2.12 / 2013-03-25

* [bug] shelly check recognizes puma as allowed web server

## 0.2.11 / 2013-03-22

* [bug] Zone option should be string, `shelly add` option fix
* [improvement] Output of `shelly backup list`

## 0.2.10 / 2013-03-18

* [feature] Added default organization option to `shelly add` which creates organization with the same name as cloud's code name

## 0.2.9 / 2013-03-14

* [feature] Added force option (skip confirmation question) for `shelly file delete`

## 0.2.8 / 2013-03-12

* Requires newer version of wijet-thor

## 0.2.7 / 2013-03-07

* [bug] Checking presence of Rakefile and tasks (db:migrate and db:setup)

## 0.2.6 / 2013-03-06 yanked

* [bug] Fixes issues with newer version of Thor gem (> 0.15.0)

## 0.2.5 / 2013-02-24

* [feature] Show starting/stopping sidekiq in deployment logs

## 0.2.4 / 2013-02-18

* [feature] Require sidekiq gem if present in Cloudfile when running `shelly check`
* Changes reflecting new API

## 0.2.3 / 2013-02-12

* [improvement] Handle stopping clouds in different states

## 0.2.2 / 2013-02-01

* Changes reflecting improved API

## 0.2.1 / 2013-01-17

* [improvement] Show redeploy authors in `shelly deploys list`

## 0.2.0 / 2013-01-10

* [feature] shelly now works on JRuby
* [feature] only valid YAML is accepted in Cloudfiles
* [feature] shelly-dependencies is no longer a dependency, add thin to Gemfile separately

## 0.1.40 / 2013-01-08

* [improvement] `shelly deploys pending` fetches references from origin before displaying the list of commits.

## 0.1.39 / 2013-01-08

* [feature] Added `shelly deploys pending` - displays a list of commits which are not deployed to Shelly Cloud yet.

## 0.1.38 / 2012-12-20

* [improvement] Using logs streaming server for logs tail (`shelly logs -f`). Logs are displayed more fluently.

## 0.1.36 / 2012-12-18

* [feature] Let user choose organization when adding new cloud

* [feature] When displaying user list, `--organization=ORGANIZATION_NAME` limits the list to users from a single organization

* [feature] Support for deleting files from disk - `shelly file delete`

## 0.1.35 / 2012-12-06

* [feature] Support for organizations

* [feature] New cloud can be created with existing organizatino with --organization [-o] option

Usage: ```shelly add --organization=ORGANIZATION_NAME```

* Manage users within organization

All ```shelly user``` commands affected

* [feature] Show organizations with associated clouds

## 0.1.34 / 2012-11-11

* [feature] Accept DSA keys when logging in or registering

DSA key is used in the first place, if it doesn't exist RSA key is used

## 0.1.31 / 2012-10-10

* [bug] Writing backups to disk in binary mode to avoid ascii/utf8 conversion errors.

## 0.1.30 / 2012-10-05

* [refactoring] Improved output message in ```backup list```

## 0.1.28 / 2012-09-21

* [feature] Singular form of all subcommands with possibility to invoke them with plural form

  ```shelly user list``` and ```shelly users list``` works the same

## 0.1.27 / 2012-09-12

* [bug] shelly check - wrong method for retrieving databases from Cloudfile

## 0.1.26 / 2012-09-11

* [bug] Fixes -c/--cloud option bug in previous version

## 0.1.25 / 2012-09-11 - yanked

* [feature] `shelly check` checks gems based on Cloudfile
* [bug] Show 10 recent backups in `backup list` command, instead of the oldest

## 0.1.24 / 2012-09-10

* [feature] Support for the extended deploys API
* [feature] Option --help [-h] added to all tasks

## 0.1.23 / 2012-08-08

* Don't display mail server IP address in shelly info

  Set SPF records with https://shellycloud.com/documentation/features#sending_emails

* Removed deprecated shelly execute

## 0.1.22 / 2012-08-06

* [feature] Add dbconsole to access 'rails dbconsole' on Shelly Cloud.

* [feature] Limit backups list to 10 backups, --all option to list all backups.

  Usage: ```shelly backup list --all```

## 0.1.21 / 2012-08-06

* [refactoring] Adjusted shelly console to match new API.
