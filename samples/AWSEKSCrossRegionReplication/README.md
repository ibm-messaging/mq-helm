# Deploying IBM MQ Native HA Cross Region Replication on AWS EKS
This sample uses [IBM MQ Native HA Cross Region Replication](https://www.ibm.com/docs/en/ibm-mq/9.4.0?topic=containers-native-ha-cross-region-replication) to setup a queue manager with high availability and disaster recovery across AWS regions. To reduce the infrastructure required the cross region setup is simulated by having two namespaces within the same AWS EKS cluster. If two AWS EKS clusters in separate regions are available the reader can easily change the sample to support that setup. 

Within this sample we will deploy two Native HA deployments which are configured for replication. These two deployments work together to provide a single queue manager which is highly available within a region, and resilient across regions. Once configured, a sample message will be put on the queue manager in region 1. The deployment in region 1 will be removed and a switch over to region 2 completed. The message will then be received in region 2 showing the data has been replicated. 


## Pre-reqs
Prior to using the Helm chart you will need to install four dependencies:
1. [Helm version 3](https://helm.sh/docs/intro/install/)
2. [Kubectl](https://kubernetes.io/docs/tasks/tools/)
3. [AWS Command Line](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
4. Assure your AWS EKS Security Group allows communication on the assigned NodePorts.


## Installation
1. Log into the AWS EKS cluster using the `aws` command line. If you are unsure how to do this please consult [here](https://aws.amazon.com/premiumsupport/knowledge-center/eks-cluster-connection/).
1. Change directories to *deploy*: `cd deploy`      
1. Run the installation command to deploy an instance in the recovery namespace: `./installRegion2.sh <RecoveryNamespace>`            
    Where \<RecoveryNamespace\> is the Kubernetes namespace where the resources should be deployed into. By default a new namespace called `region2` is created. This will deploy a number of resources:
    * The IBM MQ Helm Chart using the properties within the [secureapp_nativeha.yaml_template](deploy/secureapp_nativeha.yaml_template) file. The `installRegion2.sh` script sets the `nativehaGroup` parameter to `qm-recovery`
    * A configMap with MQ configuration to define a default Queue, and the security required.
    * A secret that includes certificates and keys from the `genericresources/createcerts` directory. Assuring the communication in MQ is secure.
1. This will take a minute or so to deploy, and the status can be checked with the following command: `kubectl get pods | grep secureapp`. Wait until one of the three Pods is showing `1/1` under the ready status (only one will ever show this, the remainding two will be `0/1` showing they are replicas).
1. Run the installation command to deploy an in the live namespace: `./installRegion1.sh <LiveNamespace\> \<RecoveryNamespace\>`            
    Where \<LiveNamespace\> is the Kubernetes namespace where the resources should be deployed into. By default a new namespace called `region1` is created. \<RecoveryNamespace\> is the Kubernetes namespace where the recovery resources have already been deployed. This will deploy a number of resources:
    * The IBM MQ Helm Chart using the properties within the [secureapp_nativeha.yaml_template](deploy/secureapp_nativeha.yaml_template) file. The `installRegion1.sh` script sets the `nativehaGroup` parameter to `qm-live`, and the `address` parameter to the corresponding location for region2.
    * A configMap with MQ configuration to define a default Queue, and the security required.
    * A secret that includes certificates and keys from the `genericresources/createcerts` directory. Assuring the communication in MQ is secure.
1. This will take a minute or so to deploy, and the status can be checked with the following command: `kubectl get pods | grep secureapp`. Wait until one of the three Pods is showing `1/1` under the ready status (only one will ever show this, the remainding two will be `0/1` showing they are replicas).

## Testing
The prerequisite is that the IBM MQ is installed under `/opt/mqm` directory or binaries (Redistributable client) are available in the same path on the host machine on which the testing is carried out. 

Navigate to *../test* directory. No modifications should be required, as the endpoint configuration for your environment will be discovered automatically.

1. To initiate the testing, run the **./sendMessageRegion1.sh \<LiveNamespace\>** command. It will then connect to MQ. Type in a message such as `Message from Region1` and press enter twice. 

1. Run the **./deleteRegion1SwitchToRegion2.sh \<LiveNamespace\> \<RecoveryNamespace\>** command. You should see all of the messages being sent by the sendMessaging command.

1. Run **./getMessageRegion2.sh \<RecoveryNamespace\>** to retrieve the original message.

1. You can clean up the resources by navigating to the *../deploy* directory and running the command **./cleanup.sh \<LiveNamespace\> \<RecoveryNamespace\>**. This will delete everything. Do not worry if you receive messages about PVCs not being found, this is a generic clean-up script and assumes a worst case scenario.
