# Deploying the IBM MQ Helm Chart on RedHat OpenShift with Pod Disruption Budget enabled

**The strategic deployment mechanism for IBM MQ on RedHat OpenShift is the [IBM MQ Operator](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=integration-using-mq-in-cloud-pak-openshift), the helm chart is only provided for customers who are unable to utilize the operator.**

## Pre-reqs
Prior to using the Helm chart you will need to install three dependencies:
1. [Helm version 3](https://helm.sh/docs/intro/install/)
2. [Kubectl](https://kubernetes.io/docs/tasks/tools/)
3. [OpenShift Command Line](https://docs.openshift.com/container-platform/4.8/cli_reference/openshift_cli/getting-started-cli.html#installing-openshift-cli)

## Licensing

When PDB is enabled, the IBM MQ Helm chart includes intelligent **role-based license annotation switching**. This feature ensures that license charges accurately reflect each pod's role (Active, Replica, or Standby) at runtime.

### How It Works

- **Initial state (Helm install):** All pods deploy with the `metadata.license_when_replica_or_standby` annotations, ensuring newly starting pods are charged at the replica/standby rate (typically free).
- **After startup:** The metadata sidecar detects the queue manager's role and dynamically patches pod annotations:
  - **Active pod:** Switches to `metadata.annotations` (charged rate, e.g., per virtual processor core for IBM MQ Advanced)
  - **Replica/Standby pods:** Remain on `metadata.license_when_replica_or_standby` (typically free or reduced charge)
- **During failover:** When a pod's role changes, the sidecar automatically adjusts its annotations to match the new role.

This ensures the IBM License Service always observes accurate, role-aware annotations — licensing charges match the pod's actual runtime state.

### Configuration

Update the `metadata.annotations` and `metadata.license_when_replica_or_standby` sections in [secureapp_nativeha.yaml](deploy/secureapp_nativeha.yaml) to match your license type and product edition:

- Refer to [IBM MQ container license annotations](https://www.ibm.com/docs/en/ibm-mq/latest?topic=reference-mq-container-license-annotations) for the correct `productID`, `productMetric`, and other values.
- Ensure the `productMetric` for replica/standby annotations is set to a non-charged or free metric.
- The annotations in the values file include commented examples of IBM MQ Advanced licensing configuration.

## Installation
1. Log into the OpenShift Cluster using the `oc` command line. If you are unsure how to do this please consult [here](https://docs.openshift.com/container-platform/4.8/cli_reference/openshift_cli/getting-started-cli.html#cli-logging-in_cli-developer-commands).
2. Change directories to *deploy*: `cd deploy`      
3. Run the installation command to deploy an instance of the helm chart: `./install.sh <namespace>`            
    Where \<namespace\> is the Kubernetes namespace where the resources should be deployed into. This will deploy a number of resources:
    * The IBM MQ Helm Chart using the properties within the [secureapp_nativeha.yaml](deploy/secureapp_nativeha.yaml) file.
    * A configMap with MQ configuration to define a default Queue, and the security required.
    * A secret that includes certificates and keys from the `genericresources/createcerts` directory. Assuring the communication in MQ is secure.
4. This will take a minute or so to deploy, and the status can be checked with the following command: `kubectl get pods -l app.kubernetes.io/instance=secureapphelm`. Wait until all of the three Pods are showing `2/2` under the ready status. To determine which is the
Active instance, issue the following command: `kubectl get pods -l mq.ibm.com/status=active`. All pods initially have `initializing` as the value for this
label, then when the labelling sidecar is active it will set that label's value
to `starting`, `active` or `replica`.

## Testing
The prerequisite is that the IBM MQ is installed under `/opt/mqm` directory or binaries (Redistributable client) are available in the same path on the host machine on which the testing is carried out. 

Navigate to *../test* directory. No modifications should be required, as the endpoint configuration for your environment will be discovered automatically.

1. To initiate the testing, run the **./sendMessage.sh \<namespace\>** command. It will then connect to MQ and start sending messages immediately.

2. Open another terminal window and run the **./getMessage.sh \<namespace\>** command. You should see all of the messages being sent by the sendMessaging command.

3. To see how the pods work together in action, run the **kubectl get pod -l app.kubernetes.io/instance=secureapphelm** command on another terminal windows to view the current pods, and then delete the Active pod (the one with a pod label of `mq.ibm.com/status=active`) by running the command: **kubectl delete pod secureapphelm-ibm-mq-0** (where the pod name is customized based on which one is active). Once the active pod is deleted, the application connections will then reconnect to the other pod.

| ℹ️ Note |
|---|
| To view the status of each of the pods, you can use the following command: |

`kubectl get pod -o custom-columns='NAME:.metadata.name,STATUS:.metadata.labels.mq\.ibm\.com/status' -l app.kubernetes.io/instance=secureapphelm`

```
secureapphelm-ibm-mq-0   active 
secureapphelm-ibm-mq-1   replica
secureapphelm-ibm-mq-2   replica
```
| |
|---|
| |

4. You can clean up the resources by navigating to the *../deploy* directory and running the command **./cleanup.sh \<namespace\>**. This will delete everything. Do not worry if you receive messages about PVCs not being found, this is a generic clean-up script and assumes a worst case scenario.

## Perform Rolling Update
If configuration changes on a Native HA queue manager are required, it may be necessary to restart (by deleting the pod and letting the statefulset start a new pod) each of the NativeHA pods. To minimise the impact on the consumers (e.g. applications needing to reconnect) it is advisable to restart the Replica pods first, and lastly the Active pod. The `./demoRollingUpdatePDB.sh` script in the `genericresources/rollingupdate` directory will:

1. Identify the NativeHA instance pods,

2. Confirm from the user that the rolling update should go ahead,

3. Restart and check each of the instance pods; Replica instances first, followed by the Active instance.

After each of the restarts the script will check that the pod is 'ready' and that the queue manager is back in-sync and regained 3/3 quorum. If these checks fail then the script will stop and prompt the user to manually check the instances. 
