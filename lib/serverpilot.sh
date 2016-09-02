#!/bin/sh

# ServerPilot API Shell Wrapper
# by Kodie Grantham (http://kodieg.com)
# https://github.com/kodie/serverpilot-shell

# Check if api creds have been set. If not, check if they're in the config file.
if [[ ! "$serverpilot_client_id" || ! "$serverpilot_api_key" ]]; then
  if [ -e "serverpilot_config" ]; then
    . "serverpilot_config"
  fi
fi

# Main API call function (Internal)
# Example: sp_run "sysusers" '{"serverid":'"$serverid"',"name":'"$name"',"password":'"$password"'}' "POST"
function sp_run {
  if [ "$2" ]; then local d="-d "$2; fi
  if [ "$3" ]; then local X="-X "$3; fi
  local response=$(curl -s https://api.serverpilot.io/v1/$1 -u $serverpilot_client_id:$serverpilot_api_key -H "Content-Type: application/json" $d $X)
  if [ ! "$response" ]; then response='{"error":{"message":"No response from ServerPilot."}}'; fi
  echo $response | tr '\n' ' '
}

# Checks for raw, silent, and wait options as well as errors (Internal)
# Example: sp_data_check "$response"
function sp_data_check {
  if [ "$sp_options_wait" == "true" ]; then
    local actionid="$(echo "$1" | jq -rc ".actionid")"
    if [[ "$actionid" && ! "$actionid" == "null" ]]; then
      sp_actions_wait "$actionid"
    fi
  fi

  if [[ "$sp_options_raw" == "true" && ! "$sp_options_silent" == "true" ]]; then
    echo $1
    exit 0
  elif [ ! "${error=$(echo "$1" | jq -rc ".error.message")}" == "null" ]; then
    if [ ! "$sp_options_silent" == "true" ]; then
      echo "Error: $error" >&2
    fi
    exit 1
  elif [ "$sp_options_silent" == "true" ]; then
    exit 0
  fi
}

# Splits a string by a delimiter (Internal)
# Example: sp_data_split "," $string
function sp_data_split {
  IFS="$1"
  local arr=($2)
  unset IFS
  echo ${arr[@]}
}

# Displays data in a nice table (Internal)
# Example: sp_data_table "${data[@]}"
function sp_data_table {
  local keys=($(echo "${@:0:1}" | jq -r ". | keys_unsorted | .[]"))
  COLUMNS=100
  printf "%-20s" ${keys[@]}
  echo

  local i
  for i in "$@"; do
    local value=$(echo "$i" | jq -r ".[]")
    printf "%-20s" ${value[@]}
    echo
  done
}

# Default setup for sp_data_table function (Internal)
# Example: sp_table "$response" "$selector"
function sp_table {
  local o=($(echo "$1" | jq -rc "$2"))
  sp_data_table "${o[@]}"
}

# Checks if required args are set
# Example: sp_args_check 1 "$@"
function sp_args_check {
  local a=("${@:2}")
  local c="$1"

  if [ "${#a[@]}" -lt "$c" ]; then
    echo "Error: Missing required arguments."
    exit 1
  fi
}

# Wrap quotes around string args - Used when args are being used in JSON (Internal)
# Example: set $(sp_args_quote "$@")
# Example: set -- "${@:1:1}" $(sp_args_quote ""${@:2}"")
function sp_args_quote {
  local a=($@); local i;
  for i in "${!a[@]}"; do
    if [[ ${a[$i]} \
        && ${a[$i]} != true \
        && ${a[$i]} != false \
        && ${a[$i]} != "null" \
        && ${a[$i]:0:1} != "[" \
        && ${a[$i]:0:1} != "{" ]]
    then
      a[$i]='"'${a[$i]}'"'
    fi
  done
  echo ${a[@]}
}

# Builds the jq string for find function (Internal)
# Example: s=$(sp_find_setup "$@")
function sp_find_setup {
  if [ "$1" ]; then
    local find=($(sp_data_split "," "$1"))
    local s; local i;
    for i in "${find[@]}"; do
      local f=($(sp_data_split "=" "$i"))
      s=$s" | select(.${f[0]}==\"${f[1]}\")"
    done
  fi

  if [ "$2" ]; then
    local out=($(sp_data_split "," "$2"))
    local k; local x;
    for x in "${out[@]}"; do
      if [ "$sp_options_raw" == "true" ]; then
        k=$k",$x:.$x"
      else
        k=$k",.$x"
      fi
    done
    if [ "$sp_options_raw" == "true" ]; then
      k=" | {"${k:1}"}"
    else
      k=" | "${k:1}
    fi
  fi

  echo $s$k
}

# Finds a server, system user, app, or database based on "search" field and returns specified fields.
# Example: serverpilot find servers "name=production-1" "id"
# Example: serverpilot find apps 'serverid=$serverid,runtime=php7.0' "id,name"
# Note: Does not obey the "-s (Silent)" option.
function sp_find {
  sp_args_check 1 "$@"
  local s=$(sp_find_setup "${@:2}")
  local response=$(sp_run "$1")
  local f=".data[] $s"

  if [ "$sp_options_raw" == "true" ]; then
    f="{data:[.data[] $s]}"
  fi

  local results=$(echo "$response" | jq -rc "$f")

  if [[ ! "$3" && ! "$sp_options_raw" == "true" ]]; then
    case "$1" in
      "apps") sp_apps_table "$results" ".";;
      "dbs") sp_dbs_table "$results" ".";;
      *) sp_table "$results" ".";;
    esac
  else
    echo ${results[@]}
  fi
}

# Waits for action to be completed before letting the function continue (Internal)
# Example: sp_actions_wait $actionid
function sp_actions_wait {
  while true; do
    local response=$(sp_run "actions/$1")
    local status=$(echo "$response" | jq -r ".data.status")

    if [[ "$status" == "success" || "$status" == "error" ]]; then
      return
    fi

    sleep 2
  done
}

# Checks the status of an action id
# Example: serverpilot actions $actionid
function sp_actions {
  sp_args_check 1 "$@"
  local response=$(sp_run "actions/$1")
  sp_data_check "$response"

  local status=$(echo "$response" | jq -rc ".data.status")
  case $status in
    "success") echo "The action '$1' has completed successfully.";;
    "open") echo "The action '$1' has not completed yet.";;
    "error") echo "The action '$1' has completed but there were errors.";;
  esac
}

# Gets a list of all servers or details of a specific server if passed a server id
# Example: serverpilot servers
# Example: serverpilot servers $serverid
function sp_servers_get {
  if [ "$1" ]; then
    local response=$(sp_run "servers/$1")
    local selector=".data"
  else
    local response=$(sp_run "servers")
    local selector=".data[]"
  fi

  sp_data_check "$response"
  sp_table "$response" "$selector"
}

# Creates a server
# Example: serverpilot server create $servername
# Note: You will need to run the serverpilot-installer yourself. (https://github.com/ServerPilot/API#connect-a-new-server)
function sp_servers_create {
  sp_args_check 1 "$@"
  set $(sp_args_quote "$@")
  local response=$(sp_run "servers" '{"name":'$1'}')
  sp_data_check "$response"
}

# Updates specified server's info
# Example: serverpilot servers update $serverid firewall true
# Example: serverpilot servers update $serverid autoupdates false
function sp_servers_update {
  sp_args_check 3 "$@"
  set -- "${@:1:1}" $(sp_args_quote ""${@:2}"")
  local response=$(sp_run "servers/$1" '{'$2':'$3'}')
  sp_data_check "$response"
}

# Deletes specified server
# Example: serverpilot servers delete $serverid
function sp_servers_delete {
  sp_args_check 1 "$@"

  if [[ ! "$sp_options_force" == "true" && ! "$sp_options_silent" == "true" ]]; then
    read -p "You are aboute to delete server '$1'. This cannot be undone! Are you sure? " -n 1 -r && echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then break; else return; fi
  fi

  local response=$(sp_run "servers/$1" "" "DELETE")
  sp_data_check "$response"
}

# Namespace function for servers - Defaults to listing servers
function sp_servers {
  case "$1" in
    "") sp_servers_get "${@:2}";;
    "create") sp_servers_create "${@:2}";;
    "update") sp_servers_update "${@:2}";;
    "delete") sp_servers_delete "${@:2}";;
    *) echo "Error: Invalid command." >&2; exit 1;;
  esac
}

# Gets a list of all system users or details of a specific system user if passed a system user id
# Example: serverpilot sysusers
# Example: serverpilot sysusers $sysuserid
function sp_sysusers_get {
  if [ "$1" ]; then
    local response=$(sp_run "sysusers/$1")
    local selector=".data"
  else
    local response=$(sp_run "sysusers")
    local selector=".data[]"
  fi

  sp_data_check "$response"
  sp_table "$response" "$selector"
}

# Creates a system user
# Example: serverpilot sysusers create $serverid $name $password
# Note: "password" field is optional. If user has no password, they will not be able to log in with a password.
function sp_sysusers_create {
  sp_args_check 2 "$@"
  set $(sp_args_quote "$@")
  if [ "$3" ]; then local p=',"password":'$3; fi
  local response=$(sp_run "sysusers" '{"serverid":'$1',"name":'$2$p'}')
  sp_data_check "$response"
}

# Updates specified system user's info
# Example: serverpilot sysusers update $sysuserid password $password
function sp_sysusers_update {
  sp_args_check 3 "$@"
  set -- "${@:1:1}" $(sp_args_quote ""${@:2}"")
  local response=$(sp_run "sysusers/$1" '{'$2':'$3'}')
  sp_data_check "$response"
}

# Deletes specified system user
# Example: serverpilot sysusers delete $sysuserid
function sp_sysusers_delete {
  sp_args_check 1 "$@"

  if [[ ! "$sp_options_force" == "true" && ! "$sp_options_silent" == "true" ]]; then
    read -p "You are aboute to delete system user '$1'. This cannot be undone! Are you sure? " -n 1 -r && echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then break; else return; fi
  fi

  local response=$(sp_run "sysusers/$1" "" "DELETE")
  sp_data_check "$response"
}

# Namespace function for system users - Defaults to listing system users
function sp_sysusers {
  case "$1" in
    "") sp_sysusers_get "${@:2}";;
    "create") sp_sysusers_create "${@:2}";;
    "update") sp_sysusers_update "${@:2}";;
    "delete") sp_sysusers_delete "${@:2}";;
    *) echo "Error: Invalid command." >&2; exit 1;;
  esac
}

# Apps setup for sp_data_table function (Internal)
# Example: sp_apps_table "$response" "$selector"
function sp_apps_table {
  local o=($(echo "$1" | jq -rc "$2 | del(.ssl) | del(.domains)"))
  sp_data_table "${o[@]}"
}

# Gets a list of all apps or details of a specific app if passed an app id
# Example: serverpilot apps
# Example: serverpilot apps $appid
# Note: "ssl" and "domains" fields are omitted in table view for user readability.
function sp_apps_get {
  if [ "$1" ]; then
    local response=$(sp_run "apps/$1")
    local selector=".data"
  else
    local response=$(sp_run "apps")
    local selector=".data[]"
  fi

  sp_data_check "$response"
  sp_apps_table "$response" "$selector"
}

# Creates an app
# Example: serverpilot apps create $name $sysuserid $runtime '["domain.com", "www.domain.com"]' '$wordpressObj'
# Note: "domains" and "wordpress" fields are optional.
function sp_apps_create {
  sp_args_check 3 "$@"
  set $(sp_args_quote "$@")
  if [ "$4" ]; then local d=',"domains":'$4''; fi
  if [ "$5" ]; then local w=',"wordpress":'$5''; fi
  local response=$(sp_run "apps" '{"name":'$1',"sysuserid":'$2',"runtime":'$3$d$w'}')
  sp_data_check "$response"
}

# Updates specified apps's info
# Example: serverpilot apps update $appid runtime $runtime
# Example: serverpilot apps update $appid domains "[$domain1, $domain2]"
function sp_apps_update {
  sp_args_check 3 "$@"
  set -- "${@:1:1}" $(sp_args_quote ""${@:2}"")
  local response=$(sp_run "apps/$1" '{'$2':'$3'}')
  sp_data_check "$response"
}

# Deletes specified app
# Example: serverpilot apps delete $appid
function sp_apps_delete {
  sp_args_check 1 "$@"

  if [[ ! "$sp_options_force" == "true" && ! "$sp_options_silent" == "true" ]]; then
    read -p "You are aboute to delete app '$1'. This cannot be undone! Are you sure? " -n 1 -r && echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then break; else return; fi
  fi

  local response=$(sp_run "apps/$1" "" "DELETE")
  sp_data_check "$response"
}

# Namespace function for apps - Defaults to listing apps
function sp_apps {
  case "$1" in
    "") sp_apps_get "${@:2}";;
    "create") sp_apps_create "${@:2}";;
    "update") sp_apps_update "${@:2}";;
    "delete") sp_apps_delete "${@:2}";;
    "ssl") sp_apps_ssl "${@:2}";;
    *) echo "Error: Invalid command." >&2; exit 1;;
  esac
}

# Adds an SSL certificate to an app
# Example: serverpilot apps ssl add $appid $key $cert $cacerts
function sp_apps_ssl_add {
  sp_args_check 4 "$@"
  set -- "${@:1:1}" $(sp_args_quote ""${@:2}"")
  local response=$(sp_run "apps/$1/ssl" '{"key":'$2',"cert":'$3',"cacerts":'$4'}')
  sp_data_check "$response"
}

# Updates specified apps's SSL certificate info
# Example: serverpilot apps ssl update $appid auto true
# Example: serverpilot apps ssl update $appid force false
function sp_apps_ssl_update {
  sp_args_check 3 "$@"
  set -- "${@:1:1}" $(sp_args_quote ""${@:2}"")
  local response=$(sp_run "apps/$1/ssl" '{'$2':'$3'}')
  sp_data_check "$response"
}

# Deletes custom SSL certificate or disables Auto SSL for specified app
# Example: serverpilot apps ssl delete $appid
function sp_apps_ssl_delete {
  sp_args_check 1 "$@"

  if [[ ! "$sp_options_force" == "true" && ! "$sp_options_silent" == "true" ]]; then
    read -p "You are aboute to delete the SSL certificate for app '$1'. This cannot be undone! Are you sure? " -n 1 -r && echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then break; else return; fi
  fi

  local response=$(sp_run "apps/$1/ssl" "" "DELETE")
  sp_data_check "$response"
}

# Namespace function for ssl - Defaults to nothing
function sp_apps_ssl {
  case "$1" in
    "add") sp_apps_ssl_add "${@:2}";;
    "update") sp_apps_ssl_update "${@:2}";;
    "delete") sp_apps_ssl_delete "${@:2}";;
    *) echo "Error: Invalid command." >&2; exit 1;;
  esac
}

# Database setup for sp_data_table function (Internal)
# Example: sp_dbs_table "$response" "$selector"
function sp_dbs_table {
  local o=($(echo "$1" | jq -rc "$2 |= .+ {"userid":.user.id,"username":.user.name} | del($2.user) | $2"))
  sp_data_table "${o[@]}"
}

# Gets a list of all databases or details of a database if passed a database id
# Example: serverpilot dbs
# Example: serverpilot dbs $dbid
# Note: "user.id" and "user.name" fields are moved to "userid" and "username" in table view for user readability.
function sp_dbs_get {
  if [ "$1" ]; then
    local response=$(sp_run "dbs/$1")
    local selector=".data"
  else
    local response=$(sp_run "dbs")
    local selector=".data[]"
  fi

  sp_data_check "$response"
  sp_dbs_table "$response" "$selector"
}

# Creates an database
# Example: serverpilot dbs create $appid $dbname $dbuser $dbpass
function sp_dbs_create {
  sp_args_check 4 "$@"
  set $(sp_args_quote "$@")
  local response=$(sp_run "dbs" '{"appid":'$1',"name":'$2',"user":{"name":'$3',"password":'$4'}}')
  sp_data_check "$response"
}

# Updates specified db's password
# Example: serverpilot dbs update $dbid $dbuserid $newdbpass
function sp_dbs_update {
  sp_args_check 3 "$@"
  set -- "${@:1:1}" $(sp_args_quote ""${@:2}"")
  local response=$(sp_run "dbs/$1" '{user":{"id":'$2',"password":'$3'}}')
  sp_data_check "$response"
}

# Deletes specified database
# Example: serverpilot dbs delete $dbid
function sp_dbs_delete {
  sp_args_check 1 "$@"

  if [[ ! "$sp_options_force" == "true" && ! "$sp_options_silent" == "true" ]]; then
    read -p "You are aboute to delete database '$1'. This cannot be undone! Are you sure? " -n 1 -r && echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then break; else return; fi
  fi

  local response=$(sp_run "dbs/$1" "" "DELETE")
  sp_data_check "$response"
}

# Namespace function for databases - Defaults to listing databases
function sp_dbs {
  case "$1" in
    "") sp_dbs_get "${@:2}";;
    "create") sp_dbs_create "${@:2}";;
    "update") sp_dbs_update "${@:2}";;
    "delete") sp_dbs_delete "${@:2}";;
    *) echo "Error: Invalid command." >&2; exit 1;;
  esac
}

# Namespace function for everything
# Also sets up our options for us:
#   -f (Force): Skips "Are you sure?" prompts. Used on all delete functions.
#   -r (Raw): Returns raw JSON response instead of user friendly text. Used on all functions that return a response.
#   -s (Silent): Returns nothing. Used on all functions that return a response. Takes priorty over "raw" option and enables "force" option.
#   -w (Wait): Waits for action to complete before finishing. Used on all functions that return an action id.
function serverpilot {
  sp_options_force=false
  sp_options_raw=false
  sp_options_silent=false
  sp_options_wait=false

  local options='frsw'
  while getopts $options option
  do
    case $option in
      "f") sp_options_force=true;;
      "r") sp_options_raw=true;;
      "s") sp_options_silent=true;;
      "w") sp_options_wait=true;;
      \?) exit 1;;
      :) exit 1;;
      *) exit 1;;
    esac
  done
  shift $(($OPTIND - 1))

  case "$1" in
    "find") sp_find "${@:2}";;
    "actions") sp_actions "${@:2}";;
    "servers") sp_servers "${@:2}";;
    "sysusers") sp_sysusers "${@:2}";;
    "apps") sp_apps "${@:2}";;
    "dbs") sp_dbs "${@:2}";;
  esac
}

# Only run if we're not being sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
  serverpilot "$@"
fi
