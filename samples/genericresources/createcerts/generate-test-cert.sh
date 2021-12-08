#!/bin/bash
# -*- mode: sh -*-
# © Copyright IBM Corporation 2021
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

KEY=server.key
CERT=server.crt
KEYDB=server.kdb
KEYP12=server.p12
KEY_APP=application.key
CERT_APP=application.crt
KEYDB_APP=application.kdb
KEYP12_APP=application.p12
PASSWORD=password

# Create a private key and certificate in PEM format, for the server to use
echo "#### Create a private key and certificate in PEM format, for the server to use"
openssl req \
       -newkey rsa:2048 -nodes -keyout ${KEY} \
       -subj "/CN=mq queuemanager/OU=ibm mq" \
       -x509 -days 3650 -out ${CERT}

openssl pkcs12 -export -out ${KEYP12} -inkey ${KEY} -in ${CERT} -passout pass:password

# Create a private key and certificate in PEM format, for the application to use
echo "#### Create a private key and certificate in PEM format, for the application to use"
openssl req \
       -newkey rsa:2048 -nodes -keyout ${KEY_APP} \
       -subj "/CN=application1/OU=app team1" \
       -x509 -days 3650 -out ${CERT_APP}

openssl pkcs12 -export -out ${KEYP12_APP} -inkey ${KEY_APP} -in ${CERT_APP} -passout pass:password

# Add the key and certificate to a kdb key store, for the server to use
echo "#### Creating kdb key store, for the server to use"
runmqckm -keydb -create -db ${KEYDB} -pw ${PASSWORD} -type cms -stash
echo "#### Adding certs and keys to kdb key store, for the server to use"
runmqckm -cert -add -db ${KEYDB} -file ${CERT_APP} -stashed
runmqckm -cert -import -file ${KEYP12} -pw password -target ${KEYDB} -target_stashed

# Add the key and certificate to a kdb key store, for the application to use
echo "#### Add the key and certificate to a kdb key store, for the application to use"
runmqckm -keydb -create -db ${KEYDB_APP} -pw ${PASSWORD} -type cms -stash
echo "#### Adding certs and keys to kdb key store, for the application to use"
runmqckm -cert -add -db ${KEYDB_APP} -file ${CERT} -stashed
runmqckm -cert -import -file ${KEYP12_APP} -pw password -target ${KEYDB_APP} -target_stashed -label 1 -new_label aceclient

# Add the certificate to a trust store in JKS format, for Server to use when connecting
echo "#### Creating JKS format, for Server to use when connecting"
runmqckm -keydb -create -db server.jks -type jks -pw password
echo "#### Adding certs and keys to JKS"
runmqckm -cert -add -db server.jks -file ${CERT_APP} -pw password
runmqckm -cert -import -file ${KEYP12} -pw password -target server.jks -target_pw password

# Add the certificate to a trust store in JKS format, for Client to use when connecting
echo "#### Creating JKS format, for application to use when connecting"
runmqckm -keydb -create -db application.jks -type jks -pw password
echo "#### Adding certs and keys to JKS"
runmqckm -cert -add -db application.jks -file ${CERT} -pw password
runmqckm -cert -import -file ${KEYP12_APP} -pw password -target application.jks -target_pw password
