ServerPilot API Shell Wrapper
================

Manage your [ServerPilot](https://serverpilot.io) servers, system users, apps, and databases with command line!

## Requirements
* [Curl](https://github.com/curl/curl)
* [jq](https://github.com/stedolan/jq) (version 1.5 or later)

## Authentication
Set the following variables to your credentials. If these variables are not set when the script is loaded, it will look for them in the "serverpilot_config" file which can either be located in the same directory as the script or in your home directory.
```
export serverpilot_client_id="CLIENT ID"
export serverpilot_api_key="API KEY"
```

## Installation
Replace `CLIENT ID` and `API KEY`, then run the following two commands:

```
$ curl -sSL https://raw.githubusercontent.com/kodie/serverpilot-shell/master/lib/serverpilot.sh > /usr/local/bin/serverpilot && chmod a+x /usr/local/bin/serverpilot
$ a="CLIENT ID"; b="API KEY"; printf '\nexport serverpilot_client_id="'$a'"\nexport serverpilot_api_key="'$b'"' >> ~/.bash_profile && source ~/.bash_profile
```

The first command will download `serverpilot.sh` to `/usr/local/bin/serverpilot` and make it executable.

The second command will set the `serverpilot_client_id` and `serverpilot_api_key` variables in your `~/.bash_profile` file.

To test for a successful installation, just run `serverpilot servers`.

To update to the latest version at any time, just run the first command again.

## Options
Options can be used with commands to do different things.

| Option   | Name     | Description
| :------: | :------: | :---------------------------------------
| `-f` | Force | Skips "Are you sure?" prompts. Used on all delete functions.
| `-r` | Raw | Returns raw JSON response instead of user friendly text. Used on all functions that return a response.
| `-s` | Silent | Returns nothing. Used on all functions that return a response. Takes priorty over "raw" option and enables "force" option.
| `-w` | Wait | Waits for action to complete before finishing. Used on all functions that return an action id.
This would delete the system user without prompt and would wait for the action to complete before finishing:
```
$ serverpilot -f -w sysusers delete PPkfc1NECzvwiEBI
```
This would return a JSON object containing all server info:
```
$ serverpilot -r servers
```

# Find
An added feature of this API wrapper is the `find` function.

| Name   | Type     | Description
| ------ | :------: | :---------------------------------------
| `find` | `string` | A comma separated list of fields and values to search for. i.e: `name=www2` or `id=UXOSIYrdtL4cSGp3,firewall=true`
| `fields` | `string` | A comma separated list of fields to return. i.e: `id,name`
This would list all apps on the "www2" server:
```
$ serverpilot find apps serverid=$(serverpilot find servers name=www2 id)
```

# Resources
**Servers**
* [List All Servers](#list-all-servers)
* [Connect a New Server](#connect-a-new-server)
* [Retrieve an Existing Server](#retrieve-an-existing-server)
* [Delete a Server](#delete-a-server)
* [Update a Server](#update-a-server)

**System Users**
* [List All System Users](#list-all-system-users)
* [Create a System User](#create-a-system-user)
* [Retrieve an Existing System User](#retrieve-an-existing-system-user)
* [Delete a System User](#delete-a-system-user)
* [Update a System User](#update-a-system-user)

**Apps**
* [List All Apps](#list-all-apps)
* [Create an App](#create-an-app)
* [Get Details of an App](#get-details-of-an-app)
* [Delete an App](#delete-an-app)
* [Update an App](#update-an-app)
* [Add a Custom SSL Cert](#add-a-custom-ssl-cert)
* [Enable AutoSSL](#enable-autossl)
* [Delete a Custom SSL Cert or Disable AutoSSL](#delete-a-custom-ssl-cert-or-disable-autossl)
* [Enable or Disable ForceSSL](#enable-or-disable-forcessl)

**Databases**
* [List All Databases](#list-all-databases)
* [Create a Database](#create-a-database)
* [Retrieve an Existing Database](#retrieve-an-existing-database)
* [Delete a Database](#delete-a-database)
* [Update a Database User Password](#update-a-database-user-password)

**Actions**
* [Check the Status of an Action](#check-the-status-of-an-action)

## Servers
### List All Servers

```
$ serverpilot servers
```

### Connect a New Server
| Name   | Type     | Description
| ------ | :------: | :---------------------------------------
| `name` | `string` | **Required**. The nickname of the Server. Length must be between 1 and 255 characters. Characters can be of lowercase ascii letters, digits, a period, or a dash ('abcdefghijklmnopqrstuvwxyz0123456789-'), but must start with a lowercase ascii letter and end with either a lowercase ascii letter or digit. `www.store2` is a valid name, while `.org.company` nor `www.blog-` are.
```
$ serverpilot servers create www2
```

### Retrieve an Existing Server
```
$ serverpilot servers UXOSIYrdtL4cSGp3
```

### Delete a Server
```
$ serverpilot servers delete 4zGDDO2xg30yEeum
```

### Update a Server
| Name          | Type     | Description
| ------------- | :------: | :---------------------------------------
| `firewall`    | `bool`   | Describes the "enabled" state of the Server firewall. `false` means the firewall is not enabled.
| `autoupdates` | `bool`   | Describes the "enabled" state of automatic system updates. `false` means automatic system updates are not enabled.
```
$ serverpilot servers update UXOSIYrdtL4cSGp3 firewall false
```

## System Users
### List All System Users
```
$ serverpilot sysusers
```

### Create a System User
| Name       | Type     | Description
| ---------- | :------: | :---------------------------------------
| `serverid` | `string` | **Required**. The id of the Server.
| `name`     | `string` | **Required**. The name of the System User. Length must be between 3 and 32 characters. Characters can be of lowercase ascii letters, digits, or a dash ('abcdefghijklmnopqrstuvwxyz0123456789-'), but must start with a lowercase ascii letter. `user-32` is a valid name, while `3po` is not.
| `password` | `string` | The password of the System User. If user has no password, they will not be able to log in with a password. No leading or trailing whitespace is allowed and the password must be at least 8 and no more than 200 characters long.
```
$ serverpilot sysusers create FqHWrrcUfRI18F0l derek hlZkUk
```

### Retrieve an Existing System User
```
$ serverpilot sysusers PPkfc1NECzvwiEBI
```

### Delete a System User
**Warning**: Deleting a System User will delete all Apps (and Databases)
associated.
```
$ serverpilot sysusers delete PPkfc1NECzvwiEBI
```

### Update a System User
| Name       | Type     | Description
| ---------- | :------: | :----------
| `password` | `string` | **Required**. The new password of the System User. If user has no password, they will not be able to log in with a password. No leading or trailing whitespace is allowed and the password must be at least 8 and no more than 200 characters long.
```
$ serverpilot sysusers update RvnwAIfuENyjUVnl password mRak7S
```

## Apps
### List All Apps
```
$ serverpilot apps
```

### Create an App
| Name        | Type           | Description
| ----------- | :------------: | :---------------------------------------
| `name`      | `string`       | **Required**. The nickname of the App. Length must be between 3 and 30 characters. Characters can be of lowercase ascii letters and digits.
| `sysuserid` | `string`       | **Required**. The System User that will "own" this App. Since every System User is specific to a Server, this implicitly determines on which Server the App will be created.
| `runtime`   | `string`       | **Required**. The PHP runtime for an App. Choose from `php5.4`, `php5.5`, `php5.6`, `php7.0`, or `php7.1`.
| `domains`   | `array`        | An array of domains that will be used in the webserver's configuration. If you set your app's domain name to *example.com*, Nginx and Apache will be configured to listen for both *example.com* and *www.example.com*. **Note**: The complete list of domains must be included in every update to this field.
| `wordpress`   | `object`       | If present, installs WordPress on the App. Value is a JSON object containing keys `site_title`, `admin_user`, `admin_password`, and `admin_email`, each with values that are strings. The `admin_password` value must be at least 8 and no more than 200 characters long.

Creating an App without WordPress:
```
$ serverpilot apps create gallery RvnwAIfuENyjUVnl php7.0 '["example.com","www.example.com"]'
```

Creating an App with WordPress:
```
$ serverpilot apps create wordpress RvnwAIfuENyjUVnl php7.0 '["example.com","www.example.com"]' '{"site_title":"My WordPress Site","admin_user":"admin","admin_password":"mypassword","admin_email":"example@example.com"}'
```

### Get Details of an App
```
$ serverpilot apps nlcN0TwdZAyNEgdp
```

### Delete an App
```
$ serverpilot apps delete B1w7yc1tfUPQLIKS
```

### Update an App
| Name      | Type           | Description
| --------- | :------------: | :---------------------------------------
| `runtime` | `string`       | The PHP runtime for an App. Choose from `php5.4`, `php5.5`, `php5.6`, `php7.0`, or `php7.1`.
| `domains` | `array`        | An array of domains that will be used in the webserver's configuration. If you set your app's domain name to *example.com*, Nginx and Apache will be configured to listen for both *example.com* and *www.example.com*. **Note**: The complete list of domains must be included in every update to this field.
```
$ serverpilot apps update nlcN0TwdZAyNEgdp runtime php5.6
```

### Add a Custom SSL Cert
| Name      | Type     | Description
| --------- | :------: | :---------------------------------------
| `key`     | `string` | **Required**. The contents of the private key.
| `cert`    | `string` | **Required**. The contents of the certificate.
| `cacerts` | `string` | **Required**. The contents of the CA certificate(s). If none, `null` is acceptable.
```
$ serverpilot apps ssl add nlcN0TwdZAyNEgdp \
'-----BEGIN PRIVATE KEY-----\
...the rest of the key file contents here...\
-----END PRIVATE KEY-----' \
'-----BEGIN CERTIFICATE-----\
...the rest of the key file contents here...\
-----END PRIVATE KEY-----' \
null
```

### Enable AutoSSL
| Name      | Type           | Description
| --------- | :------------: | :---------------------------------------
| `auto`    | `bool`         | Value must be `true`.
```
$ serverpilot apps ssl update nlcN0TwdZAyNEgdp auto true
```

### Delete a Custom SSL Cert or Disable AutoSSL
```
$ serverpilot apps ssl delete nlcN0TwdZAyNEgdp
```

### Enable or Disable ForceSSL
| Name      | Type           | Description
| --------- | :------------: | :---------------------------------------
| `force`   | `bool`         | Whether forced redirection from HTTP to HTTPS is enabled.
```
$ serverpilot apps ssl update nlcN0TwdZAyNEgdp force true
```

## Databases
### List All Databases
```
$ serverpilot dbs
```

### Create a Database
| Name             | Type     | Description
| ---------------- | :------: | :---------------------------------------
| `appid`          | `string` | **Required**. The id of the App.
| `name`           | `string` | **Required**. The name of the database. Length must be between 3 and 64 characters. Characters can be of lowercase ascii letters, digits, or a dash ('abcdefghijklmnopqrstuvwxyz0123456789-').
| `user`     | `string` | **Required**. The name of the Database User. Length must be at most 16 characters.
| `password` | `string` | **Required**. The password of the Database User. No leading or trailing whitespace is allowed and the password must be at least 8 and no more than 200 characters long.
```
$ serverpilot dbs create nlcN0TwdZAyNEgdp gallerydb arturo 8apNPT
```

### Retrieve an Existing Database
```
$ serverpilot dbs 8PV1OIAlAW3jbGmM
```

### Delete a Database
```
$ serverpilot dbs delete 8PV1OIAlAW3jbGmM
```

### Update the Database User Password
| Name             | Type     | Description
| ---------------- | :------: | :----------
| `userid`       | `string` | **Required**. The id of the Database User.
| `userpassword` | `string` | **Required**. The *new* password of the Database User. No leading or trailing whitespace is allowed and the password must be at least 8 and no more than 200 characters long.
```
$ serverpilot dbs update 8PV1OIAlAW3jbGmM k2HWtU33mpUsfOdA 8aTWa7
```

## Actions
### Check the Status of an Action
```
$ serverpilot actions g3kiiYzxPgAjbwcY
```

## License
MIT. See the License file for more info.
