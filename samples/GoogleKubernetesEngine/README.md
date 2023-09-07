# Deploying the IBM MQ Helm Chart on Google Kubernetes Engine

## Pre-reqs
Prior to using the Helm chart you will need to install three dependencies:
1. [Helm version 3](https://helm.sh/docs/intro/install/)
2. [Kubectl](https://kubernetes.io/docs/tasks/tools/)
3. [Google Cloud Command Line](https://cloud.google.com/sdk/docs/install)


## Installation

1. Log and create a new project on Google Cloud using the command line: `gcloud init`. You will be redirected to a browser to complete authentication. Once complete, the command line will ask if to use an existing or new project. It is recommended that a new project is selected to ensure the resources created are easy to remove. The name can be any valid value, but we used mq-gke in the example output below:
   ```
   laptop$ gcloud init
   Welcome! This command will take you through the configuration of gcloud.

   Your current configuration has been set to: [default]

   You can skip diagnostics next time by using the following flag:
     gcloud init --skip-diagnostics

   Network diagnostic detects and fixes local network connection issues.
   Checking network connection...done.                                                                                                                                                                                                                                                          
   Reachability Check passed.
   Network diagnostic passed (1/1 checks passed).

   You must log in to continue. Would you like to log in (Y/n)?  y

   Your browser has been opened to visit:

    https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=...

   You are logged in as: [running.the.number1.mq@gmail.com].

   Pick cloud project to use:
    [1] gentle-pier-342215
    [2] Enter a project ID
    [3] Create a new project
   Please enter numeric choice or text value (must exactly match list item):  3

   Enter a Project ID. Note that a Project ID CANNOT be changed later.
   Project IDs must be 6-30 characters (lowercase ASCII, digits, or
   hyphens) in length and start with a lowercase letter. mq-gke
   Waiting for [operations/cp.5182424457423345950] to finish...done.                                                                                                                                                                                                                            
   Your current project has been set to: [mq-gke].

   Not setting default zone/region (this feature makes it easier to use
   [gcloud compute] by setting an appropriate default value for the
   --zone and --region flag).
   See https://cloud.google.com/compute/docs/gcloud-compute section on how to set
   default compute region and zone manually. If you would like [gcloud init] to be
   able to do this for you the next time you run it, make sure the
   Compute Engine API is enabled for your project on the
   https://console.developers.google.com/apis page.

   Created a default .boto configuration file at [/home/callum/.boto]. See this file and
   [https://cloud.google.com/storage/docs/gsutil/commands/config] for more
   information about configuring Google Cloud Storage.
   Your Google Cloud SDK is configured and ready to use!

   * Commands that require authentication will use running.the.number1.mq@gmail.com by default
   * Commands will reference project `mq-gke` by default
   Run `gcloud help config` to learn how to change individual settings

   This gcloud configuration is called [default]. You can create additional configurations if you work with multiple accounts and/or projects.
   Run `gcloud topic configurations` to learn more.

   Some things to try next:

   * Run `gcloud --help` to see the Cloud Platform services you can interact with. And run `gcloud help COMMAND` to get help on any gcloud command.
   * Run `gcloud topic --help` to learn about advanced features of the SDK like arg files and output formatting   
   * Run `gcloud cheat-sheet` to see a roster of go-to `gcloud` commands.
   ```
   Depending on your setup, the creation of a new project may require a billing account to be associated. Complete the process documented [here](https://cloud.google.com/billing/docs/how-to/modify-project).
1. If this is the first time you have used GKE within your account the service needs to be enabled by running:
   ```
   gcloud services enable container.googleapis.com
   ```

1. Change directories to *deploy*: `cd deploy`
1. An optional script to create and connect to a new GKE cluster is included called [*./createGKECluster.sh \<ClusterName\> \<Google Cloud Region\> \<Google Cloud Zones\>*](deploy/createGKECluster.sh) which takes three optional parameters:
      * Parameter 1: GKE Cluster name - this will default to *mq-cluster*
      * Parameter 2: The Google Cloud region for the deployment - this will default to *europe-west2*. Available values can be found [here](https://cloud.google.com/compute/docs/regions-zones).
      * Parameter 3: The Google Cloud zones for the deployment - this will default to *europe-west2-a,europe-west2-b,europe-west2-c*. Available values can be found [here](https://cloud.google.com/compute/docs/regions-zones).
      For instance if you wanted the a cluster names *my-mq-cluster*, in *us-west1* region, in zones *us-west1-a,us-west1-b,us-west1-c* the command would be:
      ```
      ./createGKECluster.sh my-mq-cluster us-west1 us-west1-a,us-west1-b,us-west1-c
      ```
1. Run the installation command to deploy an instance of the helm chart: `./install.sh <namespace>`
    Where \<namespace\> is the Kubernetes namespace where the resources should be deployed into. If you are unsure this can be omitted and it will be installed into the default namespace. This will deploy a number of resources:
    * The IBM MQ Helm Chart using the properties within the [secureapp_nativeha.yaml](deploy/secureapp_nativeha.yaml) file.
    * A configMap with MQ configuration to define a default Queue, and the security required.
    * A secret that includes certificates and keys from the `genericresources/createcerts` directory. Assuring the communication in MQ is secure.
    * A Kubernete load balancer service to expose the Native HA Queue Manager to the internet.
1. This will take a minute or so to deploy, and the status can be checked with the following command: `kubectl get pods | grep secureapp`. Wait until one of the three Pods is showing `1/1` under the ready status (only one will ever show this, the remainding two will be `0/1` showing they are replicas).

## Testing
Navigate to the *../test* directory. No modifications should be required, as the endpoint configuration for your environment will be discovered automatically.

1. To initiate the testing, run the **./sendMessage.sh \<namespace\>** command. It will then connect to MQ and start sending messages immediately.

1. Open another terminal window and run the **./getMessage.sh \<namespace\>** command. You should see all of the messages being sent by the sendMessaging command.

1. To see how the pods work together in action, run the **kubectl get pod | grep secureapp** command on another terminal window to view the current pods, and then delete the running pod (the one with the ready state of `1/1`) by running the command: **kubectl delete pod secureapphelm-ibm-mq-0** (where the pod name is customized based on which one is active). Once the active pod is deleted, the application connections will then reconnect to the other pod.

1. You can clean up the resources by navigating to the *../deploy* directory and running the command **./cleanup.sh \<namespace\>**. This will delete everything from the GKE cluster, but leave the cluster itself. Do not worry if you receive messages about PVCs not being found, this is a generic clean-up script and assumes a worst case scenario.

1. If you want to remove the GKE cluster run the command: **./deleteGKECluster.sh \<ClusterName\> \<Google Cloud Region\>**
