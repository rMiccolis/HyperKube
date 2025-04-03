#!/bin/bash

###############################################################################
echo -e "${LBLUE}Reading and processing application settings from input file...${WHITE}"

# Configuring application settings
export server_access_token_secret=$(echo -n $(yq '.server_access_token_secret' $config_file_path) | base64)

export server_refresh_token_secret=$(echo -n $(yq '.server_refresh_token_secret' $config_file_path) | base64)

export server_access_token_lifetime=$(yq '.server_access_token_lifetime' $config_file_path)

export server_refresh_token_lifetime=$(yq '.server_refresh_token_lifetime' $config_file_path)

export mongo_root_username=$(echo -n $(yq '.mongo_root_username' $config_file_path) | base64)

export mongo_root_password=$(echo -n $(yq '.mongo_root_password' $config_file_path) | base64)

mkdir /home/$USER/temp
cp -R $repository_root_dir/binanceB/kubernetes/app/* /home/$USER/temp

# function needs a file name parameter to operate the substitution on ${var} variables type
envsubst_preserve_empty_variables(){
file_name=$1
# Step 1: Extracts all variables in the format ${VAR} or $VAR from the file
vars=$(grep -oP '\$\{([a-zA-Z_][a-zA-Z0-9_]*)\}|\$([a-zA-Z_][a-zA-Z0-9_]*)' $file_name | sort -u)
echo $vars

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

# Now the $file_name contains only the replaced variables that are defined in the environment
}

# TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO
application_repositories=($application_repositories)
mkdir apps
cd apps
for h in "${application_repositories[@]}"; do
# cloning apps to run on k8s and use "envsubst_preserve_empty_variables() on each k8s file"
git clone $h
done
# TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO

echo -e "${LBLUE}Starting Application...${WHITE}"
kubectl wait --for=condition=ContainersReady --all pods --all-namespaces --timeout=1800s &
wait
kubectl apply -f /home/$USER/temp/1-namespaces/
kubectl apply -f /home/$USER/temp/2-mongodb/0-mongodb-namespace.yaml
kubectl apply -f /home/$USER/temp/2-mongodb/2-mongodb-rbac.yaml
kubectl apply -f /home/$USER/temp/2-mongodb/3-mongodb-secrets.yaml
kubectl apply -f /home/$USER/temp/2-mongodb/4-mongodb-pv.yaml
kubectl apply -f /home/$USER/temp/2-mongodb/5-mongodb-pvc.yaml

# create statefulset if mongodb replicas are more than 1
# instructions for statefulset mongodb
# if [ "$mongodb_replica_count" != "1" ]; then
#     kubectl apply -f /home/$USER/temp/2-mongodb/1-mongodb-headless_service.yaml
#     kubectl apply -f /home/$USER/temp/2-mongodb/6-mongodb-statefulset.yaml
#     # let's wait for mongodb stateful set to be ready
#     exit_loop=""
#     ready_sts_condition="$mongodb_replica_count/$mongodb_replica_count"
#     while [ "$exit_loop" != "$ready_sts_condition" ]; do
#         sleep 10
#         exit_loop=$(kubectl get sts -n mongodb | awk 'NR==2{print $2}')
#         echo "StatefulSet pod ready: $exit_loop"
#     done
#     echo -e "${LBLUE}Configuring Mongodb statefulset...${WHITE}"
#     # when all mongodb replicas are created, let's setup the replicaset
#     members=()
#     for i in $(seq $mongodb_replica_count); do
#         replica_index="$(($i-1))"
#         if [ "$i" != "$mongodb_replica_count" ]; then
#             member_str="{ _id: $replica_index, host : '"mongodb-replica-$replica_index.mongodb:27017"' },"
#         else
#             member_str="{ _id: $replica_index, host : '"mongodb-replica-$replica_index.mongodb:27017"' }"
#         fi
#         members+=($member_str)
#     done
#     initiate_command="rs.initiate({ _id: 'rs0',version: 1,members: [ ${members[@]} ] })"
#     kubectl exec -n mongodb mongodb-replica-0 -- mongosh --eval "$initiate_command"

#     echo -e "${LBLUE}EXECUTED: kubectl exec -n mongodb mongodb-replica-0 -- mongosh --eval '$initiate_command' ${WHITE}"

#     kubectl exec -n mongodb mongodb-replica-0 -- mongosh --eval "rs.status()"
# fi

kubectl apply -f /home/$USER/temp/2-mongodb/1-mongodb-service.yaml
kubectl apply -f /home/$USER/temp/2-mongodb/6-mongodb-deployment.yaml

# let's wait for mongodb deployment / stateful set to be ready
exit_loop=""
ready_deployment_condition="$mongodb_replica_count/$mongodb_replica_count"
while [ "$exit_loop" != "$ready_deployment_condition" ]; do
    sleep 10
    exit_loop=$(kubectl get deployment  -n mongodb mongodb | awk 'NR==2{print $2}')
    echo "Deployment / stateful pod ready: $exit_loop"
done

kubectl apply -f /home/$USER/temp/3-server/
kubectl apply -f /home/$USER/temp/4-client/

# rm -rf /home/$USER/temp
# rm -rf /home/$USER/main_config.yaml