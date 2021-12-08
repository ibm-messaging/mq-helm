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

# Read two parameters into variables
#     1 - statefulSetName that will be updated
#     2 - namespace of the statefulSet
# 'manualAcceptance' environment variable checked to determine if the update
# should be run in silent mode.
statefulSetName=${1}
namespace=${2}
manualAcceptance=${manualAcceptance:-'true'}

# Usage method for the script, used in error situtations
printUsage()
{
  echo "Usage: applyRollingUpdate [statefulSetName] [namespace]"
  echo "Applies a rolling update to an IBM MQ Native HA deployment."
  echo ""
  echo "Mandatory arguments:"
  echo "[statefulSetName]       name of the statefulSetName. This corresponds to the"
  echo "                        helm chart name with \"ibm-mq\" appended."
  echo ""
  echo "[namespace]             the Kubernetes namespace of the statefulSet"
  echo ""
  echo ""
  echo "By default this script is run in an interactive mode to avoid Pods being"
  echo "restarted by mistake. If you would prefer an non-interactive mode (for"
  echo "automation) then set the environment variable \"manualAcceptance\" to \"false\"."
}

# Method that deletes a running Pod and waits for this to complete
# The logic only waits for 10 mins, and if the Pod has not restarted the script
# will continue to recycle additional Pods. In certain situations this may
# cause all your Pods and therefore Queue Manager to be unavailable until
# the issue is fixed manually.
recycle()
{
  # Use parameter 1 into the method as the podName to be recycled
  recyclePodName=$1

  # Use kubectl to delete this Pod
  kubectl delete pods -n $namespace $recyclePodName
  echo "$recyclePodName deleted, waiting for it to become ready..."
  attempt=0

  # Entering a wait loop for the Pod to become available. Unfortunately its not
  # possible to use the `kubectl wait` function as it does not support the
  # containerStatuses.started field. This issue is being tracked here:
  # https://github.com/kubernetes/kubernetes/issues/83094 and in the future
  # once this is 'commonly' available then this logic can be simplified.
  while true; do
    containername=$(kubectl get pods -n $namespace $recyclePodName -o jsonpath='{.status.containerStatuses..name}')
    started=$(kubectl get pods -n $namespace $recyclePodName -o jsonpath='{.status.containerStatuses..started}')
    if [[ $started == "true" && $containername == "qmgr" ]]; then
      echo "Sleeping for 5 seconds to allow pod to resync with native ha pairs"
      echo "$recyclePodName ready"
      return
    fi
    if [ $attempt -gt 60 ]; then
      echo "$recyclePodName did not start in 10 mins"
      echo "exiting as manual recycling may be required"
      exit 1
    fi
    sleep 10
    attempt=$((attempt+1))
  done


}

# Check that all parameters have been set correctly
if [[ -z $statefulSetName || -z $namespace || -z $manualAcceptance ]]; then
  printUsage
  exit 1
fi

# Retrieve a list if all the Pods in the statefulSet and also the active Pod
# currently handling traffic.
IFS=$'\n' read -r -d '' -a readyPod < <( kubectl get pods -l statefulSetName=$statefulSetName -n $namespace -o go-template='{{range $index, $element := .items}}{{range .status.containerStatuses}}{{if .ready}}{{$element.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}')
IFS=$'\n' read -r -d '' -a allPods < <( kubectl get pods -l statefulSetName=$statefulSetName -n $namespace -o jsonpath='{range .items[*]}{.metadata.name}{ "\n"}{end}')

# If silent mode is disabled (the default) then print out all the Pods that
# will be restarted and ask for confirmation.
if [ "$manualAcceptance" = true ] ; then
  printf -v allPodsString '%s,' "${allPods[@]}"
  echo "Found the following pods to recycle: ${allPodsString}"
  echo "Determined ${readyPod} is the active instance and will leave until the end"
  echo "To continue type 'accept' below:"
  read acceptConfirmation
  if [ "$acceptConfirmation" != "accept" ] ; then
    echo "You responded with ${acceptConfirmation} therefore the program will end."
    exit 1
  fi
fi

# Iterate over all of the Pods, restarting each. The active pod will be skipped
# and this will be completed next. This assures there is only a single failover.
for pod in "${allPods[@]}"; do
  if [ "$pod" = "$readyPod" ] ; then
     echo "Leaving $pod pod until the end"
  else
    echo "Recycling $pod"
    recycle $pod
  fi
done

# Finally restart the active Pod, causing a failover of the queue manager.
echo "Now recycling $readyPod"
recycle $readyPod

# Print out the currently active Pod instance.
IFS=$'\n' read -r -d '' -a newReadyPod < <( kubectl get pods -l statefulSetName=$statefulSetName -n $namespace -o go-template='{{range $index, $element := .items}}{{range .status.containerStatuses}}{{if .ready}}{{$element.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}')
echo "Recycle complete, the active instance is now $newReadyPod"
