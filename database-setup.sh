#!/bin/bash

wget -qOenvironment_variables.sh https://codejudge-starter-repo-artifacts.s3.ap-south-1.amazonaws.com/gitpod/environment_variables.sh
chmod 0755 environment_variables.sh
ENV_OUTPUT=$(bash ./environment_variables.sh WEB_MICRO)
DELIMITER=" % "
IFS="$DELIMITER" read -ra parts <<< "$ENV_OUTPUT"
API="${parts[0]}"
REPO_ID="${parts[1]}"
TEST_V="${parts[2]}"

update_setup_status="$API/api/v1/update-setup-status/"
store_user_port_and_url="$API/api/v3/store-user-url/"
verify_connection_url="$API/api/v1/verify-connection/"

# Read language name and version from command line arguments
LANG=$1
VERSION=$2
use_yarn=$3
run_serve_for_node=$4
port=$5


# function install_yarn() {
#   install_yarn=$(npm install --global yarn 2>&1 | tee /dev/tty)
#   if [ "$?" -eq  "0" ]; then
#     set_status "$test_uuid" "$question_id" "$user_id" "ENV_SETUP_FAILED"
#     errorHandler $? "Failed to install yarn with exit code: $?" "$install_yarn"
#     exit $?
#   fi
# }

# Function to handle errors
function errorHandler() {
  local exit_code=$1
  local error_string=$2
  local test_uuid=$3
  local question_id=$4
  local user_id=$5
  wget -qOenhanced_error_handler.sh https://codejudge-starter-repo-artifacts.s3.ap-south-1.amazonaws.com/gitpod/enhanced_error_handler.sh
  chmod 0755 enhanced_error_handler.sh
  bash ./enhanced_error_handler.sh "$exit_code" "$error_string" "$test_uuid" "$question_id" "$user_id"
  exit $exit_code
}

function set_status() {
  local test_uuid=$1
  local question_id=$2
  local user_id=$3
  local status=$4

  make_curl_call "PUT" "$update_setup_status" "$(cat <<EOF
{
      "user_id": "$user_id",
      "ques_id": "$question_id",
      "test_uuid": "$test_uuid",
      "repo_id": "$REPO_ID",
      "status": "$status"
}
EOF
)" "$test_uuid" "$question_id" "$user_id"
}

# Function to make a cURL call
function make_curl_call() {
  local method=$1
  local url=$2
  local data=$3
  local test_uuid=$4
  local question_id=$5
  local user_id=$6
  local response
  if [ "$test_uuid" = "NULL" ]; then
    # Remove the "uuid" field from the JSON data
    data=$(jq 'del(.test_uuid)' <<< "$data")
  fi
  
  if (( $(echo "$TEST_V > 7" | bc -l) )); then
    curl --location --request "$method" "$url" --header 'Content-Type: application/json' --data-raw "$data"
    if [ $? -ne 0 ]; then
      errorHandler "$?" "cURL call failed with exit code: $?" "$test_uuid" "$question_id" "$user_id"
      exit $?
    fi
  fi
}

#setting up chrome driver
function setup_chrome() {
  echo -e "\nSetting up chrome driver..."
  wget -qOchrome-test-setup.sh https://codejudge-starter-repo-artifacts.s3.ap-south-1.amazonaws.com/gitpod/chrome-test-setup.sh
  chmod 0755 chrome-test-setup.sh
  bash chrome-test-setup.sh > output.log 2>&1 &

  pid_1=$!
  if  wait $pid_1; then
    rm output.log || true
    echo -e "Chrome Driver successfully started"
  else
    output=$(tail -n 10 output.log)
    cat output.log
    rm output.log || true
    set_status "$test_uuid" "$question_id" "$user_id" "ENV_SETUP_FAILED"
    errorHandler $? "Error During chrome driver installation: $?. $output" "$test_uuid" "$question_id" "$user_id"
    exit $?
  fi
}

# Function to install Languages and their environment
function install_packages() {
  # local node_version=$1
  local test_uuid=$1
  local question_id=$2
  local user_id=$3

  # Installing and running chrome setup
  setup_chrome

 . "$HOME/.nvm/nvm.sh"
      echo "Node.js installation started"
      installation=$(nvm install $VERSION 2>&1 | tee /dev/tty)
      nvm use $VERSION && nvm alias default $VERSION
      echo "nvm use default &>/dev/null" >> ~/.bashrc.d/51-nvm-fix
      # Install Node.js using NVM
      if [ "$?" -eq "0" ]; then
        echo "Node.js installation completed"
      else
        set_status "$test_uuid" "$question_id" "$user_id" "ENV_SETUP_FAILED"
        errorHandler $? "Node.js installation failed with exit code: $?. $installation" "$test_uuid" "$question_id" "$user_id"
        exit $?
      fi
      echo "Package installation started"
  
  case $LANG in
    "base-js")
      npm_install=$(npm install --global http-server@0.11.1 2>&1 | tee /dev/tty)
      if [ "$?" -ne "0" ]; then
        set_status "$test_uuid" "$question_id" "$user_id" "ENV_SETUP_FAILED"
        errorHandler $? "Package http-server install failed with exit code: $?. $npm_install" "$test_uuid" "$question_id" "$user_id"
        exit $?
      fi
      ;;
    "node")
      if [ "$use_yarn" == "use_yarn" ]; then
        # install_yarn
        pack_install=$(yarn install && yarn upgrade 2>&1 | tee /dev/tty)
      else
        pack_install=$(npm install && npm update 2>&1 | tee /dev/tty)
      fi
      if [ "$?" -eq "0" ]; then
        echo "Package Installation completed"
      else
        set_status "$test_uuid" "$question_id" "$user_id" "ENV_SETUP_FAILED"
        errorHandler $? "Package installation failed with exit code: $?. $pack_install" "$test_uuid" "$question_id" "$user_id"
        exit $?
      fi
      ;;
  esac
}

function start_server() {
  local test_uuid=$1
  local question_id=$2
  local user_id=$3

  case "$LANG" in
  "base-js")
    start_server=$(http-server -p 4200 2>&1 | tee /dev/tty)
    ;;
  "node")
    if [ "$use_yarn" == "use_yarn" ]; then
      if [ "$run_serve_for_node" == "serve" ]; then
        start_server=$(yarn run serve 2>&1 | tee /dev/tty)
      else
        start_server=$(yarn start 2>&1 | tee /dev/tty)
      fi
    else
      if [ "$run_serve_for_node" == "serve" ]; then
        start_server=$(npm run serve 2>&1 | tee /dev/tty)
      else
        start_server=$(npm start 2>&1 | tee /dev/tty)
      fi
    fi
    ;;
  *)
    echo "Invalid LANG: $LANG"
    exit 1
    ;;
  esac
  if [ "$?" -ne "0" ]; then
    set_status "$1" "$2" "$3" "SRVR_CONN_FAILED"
    errorHandler $? "Failed to start server for $LANG with exit code: $?. $start_server" "$test_uuid" "$question_id" "$user_id"
    exit $?
  fi
}

# Arguments
repo_details=$(env | grep GITPOD_REPO_ROOTS | cut -d'=' -f2)
IFS='-' read -ra arr <<< "$repo_details"
if [ "${arr[0]}" = "/workspace/test" ]; then
  uuid="${arr[3]}"
  user_id="${arr[4]}"
elif [ "${arr[0]}" = "/workspace/question" ]; then
  uuid="NULL"
  user_id="${arr[2]}"
fi

ques_id="${arr[1]}"
type="Web"
util_type=""
mode=2
# workspace_url=$(env | grep -oP '(?<=GITPOD_WORKSPACE_URL=).*')
# url="https://${workspace_url/https:\/\//https:\/\/$port-}"
# Generating the URL with port appended using parameter expansion
url=$(gp url 9515)

# Store user port and URL
make_curl_call "POST" "$store_user_port_and_url" "$(cat <<EOF
{
    "url": "$url",
    "port": "$port",
    "type": "$type",
    "util_type": "$util_type",
    "mode": "$mode",
    "setup_status": "SETTING_UP_ENV",
    "repo_id": "$REPO_ID",
    "ques_id": "$ques_id",
    "test_uuid": "$uuid",
    "user_id": "$user_id"
}
EOF
)" "$uuid" "$ques_id" "$user_id"

# Install Packages
install_packages "$uuid" "$ques_id" "$user_id"

# Mark starting server
set_status "$uuid" "$ques_id" "$user_id" "STARTING_SRVR"

# start_server 
start_server "$uuid" "$ques_id" "$user_id"
