#! /bin/bash
# © Copyright IBM Corporation 2021,2025
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

export TARGET_NAMESPACE=${2:-"cp4i"}
export QM_KEY=$(cat ../../genericresources/createcerts/server.key | base64 | tr -d '\n')
export QM_CERT=$(cat ../../genericresources/createcerts/server.crt | base64 | tr -d '\n')
export QM_KEY_LIVE=$(cat ../../genericresources/createcerts/server-live.key | base64 | tr -d '\n')
export QM_CERT_LIVE=$(cat ../../genericresources/createcerts/server-live.crt | base64 | tr -d '\n')
export QM_KEY_RECOVERY=$(cat ../../genericresources/createcerts/server-recovery.key | base64 | tr -d '\n')
export QM_CERT_RECOVERY=$(cat ../../genericresources/createcerts/server-recovery.crt | base64 | tr -d '\n')
export APP_CERT=$(cat ../../genericresources/createcerts/application.crt | base64 | tr -d '\n')

( echo "cat <<EOF" ; cat mtlsqm.yaml_template ; echo EOF ) | sh > mtlsqm.yaml

oc project $TARGET_NAMESPACE
oc apply -f mtlsqm.yaml

helm install secureapphelm ../../../charts/ibm-mq -f secureapp_nativeha.yaml --set queueManager.nativeha.nativehaGroup=$1
