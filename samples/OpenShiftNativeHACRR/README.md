# Deploying the IBM MQ Helm Chart on RedHat OpenShift

**The strategic deployment mechanism for IBM MQ on RedHat OpenShift is the [IBM MQ Operator](https://www.ibm.com/docs/en/ibm-mq/9.4?topic=mq-in-containers-cloud-pak-integration), the helm chart is only provided for customers who are unable to utilize the operator.**

## Pre-reqs
Prior to using the Helm chart you will need to install three dependencies:
1. [Helm version 3](https://helm.sh/docs/intro/install/)
2. [Kubectl](https://kubernetes.io/docs/tasks/tools/)
3. [OpenShift Command Line](https://docs.openshift.com/container-platform/4.8/cli_reference/openshift_cli/getting-started-cli.html#installing-openshift-cli)

## Installation
1. Log into the OpenShift Cluster using the `oc` command line. If you are unsure how to do this please consult [here](https://docs.openshift.com/container-platform/4.8/cli_reference/openshift_cli/getting-started-cli.html#cli-logging-in_cli-developer-commands).
1. Change directories to *deploy*: `cd deploy`
2. Sample self-signed keys and certificates have been generated for the NativeHA CRR Live and Recovery groups to securely communicate in ../genericresources/createcerts . It is highly recommended to create new ones by running the script: `../genericresources/createcerts/generate-crr-certs.sh`
3. Log in to the cluster that has the CRR recovery namespace, then run the installation command to deploy an instance of the helm chart: `./install.sh qm-recovery <namespace_recovery>`            
    Where \<namespace_recovery\> is the Kubernetes namespace where the resources, for the Native HA CRR Recovery group, should be deployed into. This will deploy a number of resources:
    * The IBM MQ Helm Chart using the properties within the [secureapp_nativeha.yaml](deploy/secureapp_nativeha.yaml) file.
    * A configMap with MQ configuration to define a default Queue, and the security required.
    * A secret that includes certificates and keys from the `genericresources/createcerts` directory. Assuring the communication in MQ is secure.
4. This will take a minute or so to deploy, and the status can be checked with the following command: `oc get pods | grep secureapp`. Wait until one of the three Pods is showing `1/1` under the ready status (only one will ever show this, the remaining two will be `0/1` showing they are replicas).
5. Obtain the Replication address from the output of the Recovery group's install, and set the `address:` value to this address, in the recovery group of the nativehaGroups array, in secureapp_nativeha.yaml.
6. Log in to the cluster that has the CRR live namespace, then run the installation command to deploy an instance of the helm chart: `./install.sh qm-live <namespace_live>`            
    Where \<namespace_live\> is the Kubernetes namespace where the resources, for the Native HA CRR Live group, should be deployed into.

## Testing
The prerequisite is that the IBM MQ is installed under `/opt/mqm` directory or binaries (Redistributable client) are available in the same path on the host machine on which the testing is carried out. 

Navigate to *../test* directory. No modifications should be required, as the endpoint configuration for your environment will be discovered automatically.

1. To initiate the testing, run the **./sendMessage.sh \<namespace_live\>** command. It will then connect to MQ and start sending messages immediately.

2. Open another terminal window and run the **./getMessage.sh \<namespace_live\>** command. You should see all of the messages being sent by the sendMessaging command.

3. To see how the pods work together in action, run the **oc get pod | grep secureapp** command on another terminal windows to view the current pods, and then delete the running pod (the one with the ready state of `1/1`) by running the command: **oc delete pod secureapphelm-ibm-mq-0** (where the pod name is customized based on which one is active). Once the active pod is deleted, the application connections will then reconnect to the other pod.

4. You can clean up the resources by navigating to the *../deploy* directory and running the commands **./cleanup.sh \<namespace_live\>** and **./cleanup.sh \<namespace_recovery\>**. This will delete everything. Do not worry if you receive messages about PVCs not being found, this is a generic clean-up script and assumes a worst case scenario.
