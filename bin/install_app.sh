#!/bin/bash

###############################################################################
echo -e "${LBLUE}Reading and processing application settings from input file...${WHITE}"

# function needs a file name parameter to operate the substitution on ${var} and $var variables type
# REQUIRED ARGUMENT: file_name
envsubst_preserve_empty_variables(){
file_name=$1
# Step 1: Extracts all variables in the format ${VAR} or $VAR from the file
vars=$(grep -oP '\$\{([a-zA-Z_][a-zA-Z0-9_]*)\}|\$([a-zA-Z_][a-zA-Z0-9_]*)' $file_name | sort -u)
temp_vars=($vars)
if [[ ${#temp_vars[@]} -gt 0 ]]; then
  # echo "variables to be substituted: $vars"

  # Step 2: For each variable found, check whether it is defined in the environment
  while read -r var; do
    # Extracts the variable name, without the parentheses `${}`
    var_name=$(echo "$var" | sed -E 's/\$\{([^}]+)\}/\1/')

    # Extracts the variable name, without the dollar `$`
    var_name=$(echo "$var_name" | sed -E 's/\$//g')

    # If the variable is defined in the environment, replace it
    if [[ -n "${!var_name}" ]]; then
      # Replaces ${var} with the value of the environment variable
      sed -i "s|\${$var_name}|${!var_name}|g" $file_name
      # Replaces $var with the value of the environment variable
      sed -i "s|\$${var_name}|${!var_name}|g" $file_name
    fi
  done <<< "$vars"
fi
# Now the $file_name contains only the replaced variables that are defined in the environment
}

# Function to start app.
# REQUIRED ARGUMENT: github_repo link
#   1) git clone each application provided in main_config.yaml
#   2) apply envsubst (with envsubst_preserve_empty_variables function) on each .yaml file inside cloned project's kubernetes folder
#   3) apply those configuration yaml files
start_app(){
  project_repository=$1
  branch=$2
  app_names=()
  # cloning apps to run on k8s and use "envsubst_preserve_empty_variables() on each k8s file"
  IFS='/' read -r -a app_names <<< $project_repository
  project_name=$(echo ${app_names[4]} | grep -oP '.*(?=\.git)')
  # echo -e "${LBLUE}Starting $project_name${WHITE}"
  git clone --single-branch --branch $branch $project_repository
  app_yaml_files=($(ls ./$project_name/kubernetes/*.yaml | sort))
  for file_name in "${app_yaml_files[@]}"; do
    echo "calling envsubst_preserve_empty_variables on: $file_name"
    envsubst_preserve_empty_variables $file_name
    # apply each configuration yaml file with kubernetes
    kubectl apply -f $file_name
  done
}

# function that reads variables to export as env variables from app_yaml_variables.yaml file.
read_env_var_from_config_and_start_app() {
variables_file="/home/$USER/app_yaml_variables.yaml"

# Get the number of projects
project_count=$(yq '.projects | length' "$variables_file")

# Loop over each project
for (( i=0; i<project_count; i++ )); do
  project_name=$(yq ".projects[$i].name" "$variables_file")
  # echo "Project: $project_name"

  # Get number of env variables for this project
  env_count=$(yq ".projects[$i].env | length" "$variables_file")

  namespace=$(yq ".projects[$i].namespace" "$variables_file")
  github_repo=$(yq ".projects[$i].github_repo" "$variables_file")
  branch=$(yq ".projects[$i].branch // \"master\"" "$variables_file")
  port=$(yq ".projects[$i].port // \"false\"" "$variables_file")
  service_name=$(yq ".projects[$i].service_name // \"$project_name\"" "$variables_file")

  if [[ "$project_name" == "mongodb" ]]; then
      kubectl create namespace $namespace
      apply_tls_certificate
  fi

  # open tcp port on nginx helm installation
  if [[ "$port" != "false" ]]; then
      helm upgrade ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --set tcp.$port="$namespace/$service_name:$port"
  fi
  # Loop over each env variable
  for (( j=0; j<env_count; j++ )); do
    env_name=$(yq ".projects[$i].env[$j].name" "$variables_file")
    env_value=$(yq ".projects[$i].env[$j].value" "$variables_file")
    base64_encoding=$(yq ".projects[$i].env[$j].base64_encoding // \"false\"" "$variables_file")

    # Optional: decode if base64_encoding is true
    if [[ "$base64_encoding" == "true" ]]; then
      env_value=$(echo -n "$env_value" | base64)
    fi

    # echo "  Env Name: $env_name: $env_value"
    export $env_name=$env_value
    echo ""
  done

  # start application:
  echo -e "${LBLUE}Starting application $project_name...${WHITE}"
  start_app $github_repo $branch

  # wait for app to be ready
  kubectl rollout status deployment $project_name -n $namespace --timeout=3000s > /dev/null 2>&1
  # # let's wait for mongodb deployment / stateful set to be ready
  # if [[ "${project_name,,}" == "mongodb" ]]; then
  #   exit_loop=""
  #   ready_deployment_condition="$mongodb_replica_count/$mongodb_replica_count"
  #   while [ "$exit_loop" != "$ready_deployment_condition" ]; do
  #       sleep 10
  #       exit_loop=$(kubectl get deployment  -n $namespace $project_name | awk 'NR==2{print $2}')
  #       echo "Deployment / stateful pod ready: $exit_loop"
  #   done
  # fi
  kubectl wait --for=condition=ContainersReady --all pods --all-namespaces --timeout=3000s &
  wait

  if [[ "$project_name" == "mongodb" ]]; then
    mv 7-mongodb-deployment-tls-config.yaml.bak 7-mongodb-deployment-tls-config.yaml
    kubectl apply -f ./$project_name/kubernetes/7-mongodb-deployment-tls-config.yaml
    kubectl rollout status deployment $project_name -n $namespace --timeout=3000s > /dev/null 2>&1
    kubectl wait --for=condition=ContainersReady --all pods --all-namespaces --timeout=3000s &
    wait
  fi

done
}

apply_tls_certificate(){
  # setting variables for tls certificate
  KEY_FILE='cluster-key-cert.key'
  CERT_FILE='cluster-filecert.crt'
  HOST="$app_server_addr"
  cert_file_name='tls-cert'
  # create a certificate for https protocol
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -subj "/CN=${HOST}/O=${HOST}" -addext "subjectAltName = DNS:${HOST}"
  # creating tls certificate in 'default' namespace

  # create a tls.pem file from combination of $CERT_FILE and $KEY_FILE
  cat $KEY_FILE $CERT_FILE > tls.pem
  # kubectl create secret tls $cert_file_name --key ${KEY_FILE} --cert ${CERT_FILE} -n mongodb
  kubectl create secret generic tls-cert --from-file=tls.crt=tls.pem -n mongodb


  # create mongod.conf file to tell mongodb to use it for configuration (it contains tls certificates)
cat << EOF | sudo tee /home/$USER/mongod.conf > /dev/null
net:
  port: 27017
  bindIp: 0.0.0.0
  tls:
    mode: requireTLS
    certificateKeyFile: /etc/mongodb/tls/tls.crt
    CAFile: /etc/mongodb/tls/tls.crt # i pass the same file as 'certificateKeyFile' because the certificate is self signed
    allowConnectionsWithoutCertificates: false # Recommended for security
EOF
  kubectl create configmap mongodb-config --from-file=/home/$USER/mongod.conf -n mongodb
}

mkdir apps
cd apps
read_env_var_from_config_and_start_app

# # Configuring application settings
# mkdir /home/$USER/temp
# cp -R $repository_root_dir/binanceB/kubernetes/app/* /home/$USER/temp

# rm -rf /home/$USER/temp
# rm -rf /home/$USER/main_config.yaml