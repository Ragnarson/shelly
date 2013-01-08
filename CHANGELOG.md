## 0.1.39 / 2013-01-08

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
