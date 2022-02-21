# Deploying the IBM MQ Helm Chart on RedHat OpenShift using the IBM MQ Advanced container image

**The strategic deployment mechanism for IBM MQ on RedHat OpenShift is the [IBM MQ Operator](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=integration-using-mq-in-cloud-pak-openshift), the helm chart is only provided for customers who are unable to utilize the operator.**

**Although this sample uses the IBM MQ Advanced container image from the IBM entitled registry this is considered a custom built image from an IBM support statement. The IBM MQ Advanced container image is only supported by IBM support when deployed with the MQ operator. The MQ product code contained within the image continues to be supported as normal. If you have any questions please reach out to askmessaging@uk.ibm.com. The reason for demonstrating this option is to remove the need to re-build the container image locally.**

## Pre-reqs
Prior to using the Helm chart you will need to install three dependencies:
1. [Helm version 3](https://helm.sh/docs/intro/install/)
2. [Kubectl](https://kubernetes.io/docs/tasks/tools/)
3. [OpenShift Command Line](https://docs.openshift.com/container-platform/4.8/cli_reference/openshift_cli/getting-started-cli.html#installing-openshift-cli)

## Installation
1. Log into the OpenShift Cluster using the `oc` command line. If you are unsure how to do this please consult [here](https://docs.openshift.com/container-platform/4.8/cli_reference/openshift_cli/getting-started-cli.html#cli-logging-in_cli-developer-commands).
1. Change to the target namespace for the deployment using `oc project <namespace>`
1. The images for MQ Advanced are located in the IBM Entitled Registry. To access these, you will need to configure an API Key within the OpenShift Environment. This can be retrieved from the IBM website here: https://myibm.ibm.com/products-services/containerlibrary. In the Entitlement keys section, select Copy key to copy the entitlement key to the clipboard. This key needs to be associated with the OpenShift environment, to do this open a terminal window where you have configured the OpenShift command line utility *oc*, run the following command:     
   ```
   oc create secret docker-registry ibm-entitlement-key --docker-server=cp.icr.io --docker-username=cp --docker-password=<YOUR ENTITLEMENT_KEY> --docker-email=<email address> -n <namespace>
   ```
1. Change directories to *deploy*: `cd deploy`      
1. Run the installation command to deploy an instance of the helm chart: `./install.sh <namespace>`             
    Where \<namespace\> is the Kubernetes namespace where the resources should be deployed into. This will deploy a number of resources:
    * The IBM MQ Helm Chart using the properties within the [secureapp_nativeha.yaml](deploy/secureapp_nativeha.yaml) file.
    * A configMap with MQ configuration to define a default Queue, and the security required.
    * A secret that includes certificates and keys from the `genericresources/createcerts` directory. Assuring the communication in MQ is secure.
1. This will take a minute or so to deploy, and the status can be checked with the following command: `oc get pods | grep secureapp`. Wait until one of the three Pods is showing `1/1` under the read status (only one will ever show this, the remainding two will be `0/1` showing they are replicas).

## Testing
Navigate to *../test* directory. No modifications should be required, as the endpoint configuration for your environment will be discovered automatically.

1. To initiate the testing, run the **./sendMessage.sh \<namespace\>** command. It will then connect to MQ and start sending messages immediately.

1. Open another terminal window and run the **./getMessage.sh \<namespace\>** command. You should see all of the messages being sent by the sendMessaging command.

1. To see how the pods work together in action, run the **oc get pod | grep secureapp** command on another terminal windows to view the current pods, and then delete the running pod (the one with the ready state of `1/1`) by running the command: **oc delete pod secureapphelm-ibm-mq-0** (where the pod name is customized based on which one is active). Once the active pod is deleted, the application connections will then reconnect to the other pod.

1. You can clean up the resources by navigating to the *../deploy* directory and running the command **./cleanup.sh \<namespace\>**. This will delete everything. Do not worry if you receive messages about PVCs not being found, this is a generic clean-up script and assumes a worst case scenario.
