#!/bin/bash

# Install mongodb


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

# generate default mongodb_values.yaml
cat << EOF | tee -a /home/$USER/mongodb_values.yaml > /dev/null
architecture: standalone

tls:
  enabled: true
  existingSecret: mongodb-ca-secret
  extraDnsNames:
  - "$app_server_addr"
auth:
  enabled: true
  rootUser: $mongo_root_username
  rootPassword: $mongo_root_password
persistence:
  enabled: true
  existingClaim: mongodb-pvc
securityContext:
  runAsUser: 1001
  runAsGroup: 1001
  fsGroup: 1001

volumePermissions:
  enabled: true
EOF

# setting secret for tls certificate
mkdir $repository_root_dir/tls/mongodb
awk '/-----BEGIN PRIVATE KEY-----/,/-----END PRIVATE KEY-----/' $repository_root_dir/tls/tls-cert.pem > $repository_root_dir/tls/mongodb/mongodb-ca-key.pem
awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' $repository_root_dir/tls/tls-cert.pem > $repository_root_dir/tls/mongodb/mongodb-ca-cert.pem

kubectl -n mongodb create secret generic mongodb-ca-secret \
    --from-file=mongodb-ca-cert=$repository_root_dir/tls/mongodb/mongodb-ca-cert.pem \
    --from-file=mongodb-ca-key=$repository_root_dir/tls/mongodb/mongodb-ca-key.pem

kubectl apply -f $repository_root_dir/HyperKube/kubernetes/mongodb

helm install mongodb oci://registry-1.docker.io/bitnamicharts/mongodb -n mongodb -f /home/$USER/mongodb_values.yaml

kubectl rollout status deployment mongodb -n mongodb --timeout=3000s > /dev/null 2>&1
kubectl wait --for=condition=Ready --all pods --all-namespaces --timeout=3000s &
wait

# # copy /certs/mongodb.pem from mongodb pod to local file system
# mongodb_podname=$(kubectl get pods -n mongodb | awk 'NR==2{print $1}')
# kubectl -n mongodb cp ${mongodb_podname}:/certs/mongodb.pem ${repository_root_dir}/tls/mongodb/mongodb.pem