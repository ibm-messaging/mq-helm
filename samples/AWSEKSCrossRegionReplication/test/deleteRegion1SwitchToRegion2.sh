#! /bin/bash
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


export LIVE_TARGET_NAMESPACE=${1:-"region1"}
export RECOVERY_TARGET_NAMESPACE=${2:-"region2"}

kubectl config set-context --current --namespace=$LIVE_TARGET_NAMESPACE
helm delete secureapphelm
kubectl delete secret helmsecure -n $LIVE_TARGET_NAMESPACE
kubectl delete secret nha-crr-secret-recovery -n $LIVE_TARGET_NAMESPACE
kubectl delete configmap helmsecure -n $LIVE_TARGET_NAMESPACE
kubectl delete pvc data-secureapphelm-ibm-mq-0 -n $LIVE_TARGET_NAMESPACE
kubectl delete pvc data-secureapphelm-ibm-mq-1 -n $LIVE_TARGET_NAMESPACE
kubectl delete pvc data-secureapphelm-ibm-mq-2 -n $LIVE_TARGET_NAMESPACE
kubectl delete pvc log-secureapphelm-ibm-mq-0 -n $LIVE_TARGET_NAMESPACE
kubectl delete pvc log-secureapphelm-ibm-mq-1 -n $LIVE_TARGET_NAMESPACE
kubectl delete pvc log-secureapphelm-ibm-mq-2 -n $LIVE_TARGET_NAMESPACE
kubectl delete pvc qm-secureapphelm-ibm-mq-0 -n $LIVE_TARGET_NAMESPACE
kubectl delete pvc qm-secureapphelm-ibm-mq-1 -n $LIVE_TARGET_NAMESPACE
kubectl delete pvc qm-secureapphelm-ibm-mq-2 -n $LIVE_TARGET_NAMESPACE

kubectl config set-context --current --namespace=$RECOVERY_TARGET_NAMESPACE

helm upgrade secureapphelm ../../../charts/ibm-mq -f region2Live.yaml 

export manualAcceptance=false
../../genericresources/rollingupdate/demoRollingUpdate.sh secureapphelm-ibm-mq $RECOVERY_TARGET_NAMESPACE