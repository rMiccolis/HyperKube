#!/bin/bash

# setting variables for tls certificate
KEY_FILE="tls-cert.key"
CERT_FILE="tls-cert.crt"
HOST="$app_server_addr"
#   cert_file_name='tls-cert'
# create a certificate for https protocol
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -subj "/CN=${HOST}/O=${HOST}" -addext "subjectAltName = DNS:${HOST}"

# create a tls-cert.pem file from combination of $CERT_FILE and $KEY_FILE
cat $KEY_FILE $CERT_FILE > $repository_root_dir/tls/tls-cert.pem

rm -rf $KEY_FILE $CERT_FILE