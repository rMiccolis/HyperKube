#!/bin/bash

echo -e "${LBLUE}Installing NGINX to be reachble on $master_host_ip.${WHITE}"
#add nginx helm repository (kubernetes version)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx > /dev/null
helm repo update > /dev/null
# -------------------------------------------------------------------------------------------

# NGINX DOCUMENTATION:
# see https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
# see https://kubernetes.github.io/ingress-nginx

# -------------------------------------------------------------------------------------------

# externalIPs="$master_host_ip"
# externalIPs: [$master_host_ip $control_plane_hosts_string]

kubectl create namespace ingress-nginx
# # setting variables for tls certificate
# KEY_FILE='nginx-key-cert'
# CERT_FILE='filecert'
# HOST="$app_server_addr"
# cert_file_name='https-nginx-cert'
# # create a certificate for https protocol
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -subj "/CN=${HOST}/O=${HOST}" -addext "subjectAltName = DNS:${HOST}"
# # creating tls certificate in 'default' namespace
# kubectl create namespace binance-b
# kubectl -n binance-b create secret tls $cert_file_name --key ${KEY_FILE} --cert ${CERT_FILE}

# to set a tls certificate pass to helm: --set controller.extraArgs.default-ssl-certificate="__NAMESPACE__/_SECRET__"
# or set it into helm config file (like we do in next rows)
# EX: in nginx_helm_config.yaml type (inside controller section object):
#  extraArgs:
#    default-ssl-certificate: default/$cert_file_name

#tcp:
#  27017: "mongodb/mongodb:27017" => tcp_port_to_expose: namespace/service_name:service_port

helm install --namespace ingress-nginx ingress-nginx ingress-nginx/ingress-nginx -f $repository_root_dir/HyperKube/kubernetes/nginx/nginx_helm_config.yaml > /dev/null
# to expose port 27017 with nginx
# --set tcp.PORT="namespace/service_name:PORT"
# --set tcp.27017="mongodb/mongodb:27017"
echo -e "${LBLUE}Nginx successfully installed with Helm!${WHITE}"