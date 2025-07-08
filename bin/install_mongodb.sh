#!/bin/bash

# Install mongodb

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

# setting variables for tls certificate
KEY_FILE="tls-cert.key"
CERT_FILE="mongodb.pem"

# create mongodb namespace
kubectl create namespace mongodb

. /home/$USER/.profile
export mongo_root_username=$(yq '.mongo_root_username' $config_file_path)
export mongo_root_password=$(yq '.mongo_root_password' $config_file_path)

# open 27017 port for mongodb on nginx
helm upgrade ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --set tcp.27017="mongodb/mongodb:27017" --set controller.progressDeadlineSeconds=120
kubectl wait --for=condition=Ready --all pods --all-namespaces --timeout=3000s &
wait

# setting secret for tls certificate
mkdir $repository_root_dir/tls/mongodb
awk '/-----BEGIN PRIVATE KEY-----/,/-----END PRIVATE KEY-----/' $repository_root_dir/tls/tls-cert.pem > $repository_root_dir/tls/mongodb/mongodb-ca-key.pem
awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' $repository_root_dir/tls/tls-cert.pem > $repository_root_dir/tls/mongodb/mongodb-ca-cert.pem

kubectl -n mongodb create secret generic mongodb-ca-secret \
    --from-file=mongodb-ca-cert=$repository_root_dir/tls/mongodb/mongodb-ca-cert.pem \
    --from-file=mongodb-ca-key=$repository_root_dir/tls/mongodb/mongodb-ca-key.pem

# if a custom mongodb setup file (in .sh format) is provided then strip it (convert to unix format) and then execute it
if [[ "$custom_mongodb_setup" == "true" ]]; then
  dos2unix $repository_root_dir/user_custom_scripts/mongodb_setup.sh
  echo -e "${LPURPLE}Calling $repository_root_dir/user_custom_scripts/mongodb_setup.sh...${WHITE}"
  . $repository_root_dir/user_custom_scripts/mongodb_setup.sh
else
  kubectl apply -f $repository_root_dir/HyperKube/kubernetes/mongodb
fi

. /home/$USER/.profile
chmod 777 /home/$USER/mongodb_values.yaml

# use the provided /home/$USER/mongodb_values.yaml to configure the bitnami mongodb helm chart
# and substitute any environment variables
envsubst_preserve_empty_variables "/home/$USER/mongodb_values.yaml"
# echo "substituted variables in /home/$USER/mongodb_values.yaml: $(cat /home/$USER/mongodb_values.yaml)"
helm install mongodb oci://registry-1.docker.io/bitnamicharts/mongodb -n mongodb -f /home/$USER/mongodb_values.yaml

kubectl rollout status deployment mongodb -n mongodb --timeout=3000s > /dev/null 2>&1
kubectl wait --for=condition=Ready --all pods --all-namespaces --timeout=3000s &
wait

# # copy /certs/mongodb.pem from mongodb pod to local file system
# mongodb_podname=$(kubectl get pods -n mongodb | awk 'NR==2{print $1}')
# kubectl -n mongodb cp ${mongodb_podname}:/certs/mongodb.pem ${repository_root_dir}/tls/mongodb/mongodb.pem