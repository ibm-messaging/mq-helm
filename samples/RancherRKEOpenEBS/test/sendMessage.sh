#!/bin/bash
# © Copyright IBM Corporation 2023
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

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
export TARGET_NAMESPACE=${1:-"default"}
export MQCCDTURL="${DIR}/ccdt_generated.json"
export MQSSLKEYR="${DIR}/../../genericresources/createcerts/application"
export MQRCVBLKTO=5
export PORT="$(kubectl get services secureapphelm-ibm-mq-qm -n $TARGET_NAMESPACE -o jsonpath="{.spec.ports[?(@.port=="1414")].nodePort}" | awk '{print $1}')"
export IPADDRESS="$(kubectl get nodes -o jsonpath='{..addresses[1].address}' | awk '{print $1}')"

( echo "cat <<EOF" ; cat ccdt_template.json ; echo EOF ) | sh > ccdt_generated.json

echo "Starting amqsphac" secureapphelm
/opt/mqm/samp/bin/amqsphac APPQ secureapphelm