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

NAMESPACE=${1:-"default"}
DEBUG=true

function line_separator () {
  echo "####################### $1 #######################"
}

function checkForUnschedulableNodes() {
    line_separator "Checking for unschedulable nodes"
    UNSCHEDULED_NODE_STRING=$(kubectl get nodes -o=jsonpath='{.items[?(@.spec.unschedulable==true)].metadata.name}')
    if [ -z "$UNSCHEDULED_NODE_STRING" ]
    then
        $DEBUG && echo "[DEBUG] No nodes found"
        NODE_ARRAY=''
        return
    else 
        $DEBUG && echo "[DEBUG] Found these nodes '$UNSCHEDULED_NODE_STRING'"
        NODE_ARRAY=("$UNSCHEDULED_NODE_STRING")
    fi
}

function findMQPodsOnNode(){
    TARGET_NODE=$1
    line_separator "Finding MQ Pods on $TARGET_NODE"
    MQ_PODS=$(kubectl get pods --field-selector spec.nodeName="$TARGET_NODE" -n "$NAMESPACE" -l app.kubernetes.io/name=ibm-mq -o jsonpath='{.items[*].metadata.name}')
    if [ -z "$MQ_PODS" ]
    then
        $DEBUG && echo "[DEBUG] No MQ pods found"
        return
    else
        $DEBUG && echo "[DEBUG] Found these pods '$MQ_PODS'"
        DELETE_POD=false
        MQ_PODS_ARRAY=("$MQ_PODS")
        for i in "${MQ_PODS_ARRAY[@]}"
        do
            $DEBUG && echo "[DEBUG] Checking if '$i' has quorum"
            QMGR_STATUS=$(kubectl exec "$i" -n "$NAMESPACE" -- dspmq -o nativeha)
            QUORUM_STATUS=${QMGR_STATUS#*QUORUM(}
            RUNNING_CONTAINERS=${QUORUM_STATUS%%/*}
            $DEBUG && echo "[DEBUG] '$i' has a quorum status of '$RUNNING_CONTAINERS'"
            QMGR_CONNECTIONS=$(kubectl exec "$i" -n "$NAMESPACE" -- dspmq -o nativeha -x | grep -c "CONNACTV(yes)" )
            $DEBUG && echo "[DEBUG] '$i' has active connections to '$QMGR_CONNECTIONS' instances"
            if [  "$RUNNING_CONTAINERS" -eq 3 ] && [ "$QMGR_CONNECTIONS" -eq 3 ]
            then
                $DEBUG && echo "[DEBUG] Queue Manager has $RUNNING_CONTAINERS containers so safe to delete one instance"
                DELETE_RESPONSE=$(kubectl delete pod "$i" -n "$NAMESPACE")
                $DEBUG && echo "[DEBUG] Pod delete response: $DELETE_RESPONSE"
                DELETE_POD=true
            else
                $DEBUG && echo "[DEBUG] Unsafe to delete Pod - doing nothing and will auto-retry during the next loop"
            fi            
        done
    fi

    if [ $DELETE_POD = "true" ]
    then
        $DEBUG && echo "[DEBUG] Deleted pods on worker node so sleeping for 10 seconds for quorum status to correct"
        sleep 10
    else
        $DEBUG && echo "[DEBUG] No pods deleted"
    fi
}

while true
do
    echo ""
    line_separator "Starting check"

    checkForUnschedulableNodes
    if [ -n "$NODE_ARRAY" ]
    then
        for node_item in "${NODE_ARRAY[@]}"
        do
            $DEBUG && echo "[DEBUG] Processing node '$node_item'"
            findMQPodsOnNode "$node_item"
        done
    fi
    echo ""
    sleep 30
done