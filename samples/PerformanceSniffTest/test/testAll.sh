#! /bin/bash
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

export $(grep -v ^\# control.prop | xargs)
export RUN_ID=$(date +%s)

( echo "cat <<EOF" ; cat jobnonpersistencetls.yaml ; echo EOF ) | sh > jobnonpersistencetls_generated.yaml
( echo "cat <<EOF" ; cat jobpersistencetls.yaml ; echo EOF ) | sh > jobpersistencetls_generated.yaml
( echo "cat <<EOF" ; cat jobnonpersistence.yaml ; echo EOF ) | sh > jobnonpersistence_generated.yaml
( echo "cat <<EOF" ; cat jobpersistence.yaml ; echo EOF ) | sh > jobpersistence_generated.yaml


kubectl apply -f jobnonpersistencetls_generated.yaml
sleep 10s
kubectl wait --for=condition=complete job/cphtestnonpersistenttls$RUN_ID  --timeout=6000s

kubectl apply -f jobpersistencetls_generated.yaml
sleep 10s
kubectl wait --for=condition=complete job/cphtestpersistenttls$RUN_ID  --timeout=6000s


kubectl apply -f jobnonpersistence_generated.yaml
sleep 10s
kubectl wait --for=condition=complete job/cphtestnonpersistent$RUN_ID --timeout=6000s

kubectl apply -f jobpersistence_generated.yaml
sleep 10s
kubectl wait --for=condition=complete job/cphtestpersistent$RUN_ID --timeout=6000s


echo "**********************Non Persistent with TLS******************************"
echo "**********************Non Persistent with TLS******************************" >> ../results.txt
kubectl logs job/cphtestnonpersistenttls$RUN_ID >> ../results.txt
echo "**********************Persistent with TLS**********************************"
echo "**********************Persistent with TLS**********************************" >> ../results.txt
kubectl logs job/cphtestpersistenttls$RUN_ID >> ../results.txt
echo "**********************Non Persistent*********************"
echo "**********************Non Persistent*********************" >> ../results.txt
kubectl logs job/cphtestnonpersistent$RUN_ID >> ../results.txt
echo "**********************Persistent*********************"
echo "**********************Persistent*********************" >> ../results.txt
kubectl logs job/cphtestpersistent$RUN_ID >> ../results.txt
