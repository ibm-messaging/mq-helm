# Deploying the IBM MQ Native HA using the Helm Chart on minikube
These instructions will deploy a single instance Queue Manager on a single machine using [RKE2](https://docs.rke2.io).

## Pre-reqs
Prior to using the Helm chart you will need to install three dependencies:
1. [Helm version 3](https://helm.sh/docs/intro/install/)
2. [Kubectl](https://kubernetes.io/docs/tasks/tools/)
3. [RKE2](https://docs.rke2.io/install/quickstart)
4. [OpenEBS](https://openebs.io/docs/2.12.x/user-guides/installation)

## Installation
1. Install your RKE2 Cluster on a Cloud provider or a Linux box and deploy the OpenEBS chart. 
1. Run the installation command to deploy an instance of the helm chart: `./install.sh <namespace>`            
    Where \<namespace\> is the Kubernetes namespace where the resources should be deployed into. This will deploy a number of resources:
    * The IBM MQ Helm Chart using the properties within the [secureapp.yaml](deploy/secureapp.yaml) file.
    * A configMap with MQ configuration to define a default Queue, and the security required.
    * A secret that includes certificates and keys from the `genericresources/createcerts` directory. Assuring the communication in MQ is secure.
1. This will take a minute or so to deploy, and the status can be checked with the following command: `kubectl -n mqm rollout status statefulset secureapphelm-ibm-mq --watch`.

## Testing

Navigate to *../test* directory. No modifications should be required, as the endpoint configuration for your environment will be discovered automatically. The test scripts are using the IBM MQ docker container itself to invoke the client programs, so that it's not needed to install an IBM Client.

1. To initiate the testing, run the **./sendMessage.sh \<namespace\>** command. It will then connect to MQ and start sending messages immediately.

1. Open another terminal window and run the **./getMessage.sh \<namespace\>** command. You should see all of the messages being sent by the sendMessaging command.

1. You can clean up the resources by navigating to the *../deploy* directory and running the command **./cleanup.sh \<namespace\>**. This will delete everything. Do not worry if you receive messages about PVCs not being found, this is a generic clean-up script and assumes a worst case scenario.
