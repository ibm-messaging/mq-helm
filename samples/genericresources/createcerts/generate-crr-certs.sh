#!/bin/bash
# -*- mode: sh -*-
# © Copyright IBM Corporation 2025
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

KEY_LIVE=server-live.key
CERT_LIVE=server-live.crt
KEYP12_LIVE=server-live.p12
KEY_RECOVERY=server-recovery.key
CERT_RECOVERY=server-recovery.crt
KEYP12_RECOVERY=server-recovery.p12
PASSWORD=password

# Create a private key and certificate in PEM format, for the server to use
echo "#### Create a private key and certificate in PEM format, for the Live & Recovery groups to communicate securely"
openssl req \
       -newkey rsa:2048 -nodes -keyout ${KEY_LIVE} \
       -subj "/CN=mq queuemanager/OU=ibm mq" \
       -x509 -days 3650 -out ${CERT_LIVE}

openssl pkcs12 -export -out ${KEYP12_LIVE} -inkey ${KEY_LIVE} -in ${CERT_LIVE} -passout pass:password

openssl req \
       -newkey rsa:2048 -nodes -keyout ${KEY_RECOVERY} \
       -subj "/CN=mq queuemanager/OU=ibm mq" \
       -x509 -days 3650 -out ${CERT_RECOVERY}

openssl pkcs12 -export -out ${KEYP12_RECOVERY} -inkey ${KEY_RECOVERY} -in ${CERT_RECOVERY} -passout pass:password