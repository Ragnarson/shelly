## 0.1.25 / 2012-09-11

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
