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
