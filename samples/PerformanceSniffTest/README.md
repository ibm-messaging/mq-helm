# Performance testing a Queue Manager

This sample allows users to complete a quick performance test against a Native HA queue manager in Kubernetes. The Queue Manager can be deployed to any Kubernetes environment, however small edits to the [resource.yaml_template](deploy/resource.yaml_template) may be required for your particular environment.

To run the performance test there are two key components:
* A deployed Queue Manager
* A "test application" that drives workload into the Queue Manager

This sample uses [cphtestp](https://github.com/ibm-messaging/cphtestp) as the "test application". To simplify the process, we have included a script that automatically builds this "test application" as a container image, pulling in all the dependencies.

Once the "test application" container image has been built, it is published to a container registry, allowing Kubernetes to deploy. This step will depend on your own environment and what container registry you use within your organization.

The test application is run four times:
* Non-Persistent Messaging
* Persistent Messaging
* Non-Persistent with TLS 1.2 Messaging
* Persistent with TLS 1.2 Messaging
Each test run will provide throughput numbers for 2k, 20k and 200k, across a range of client thread counts.

## Pre-reqs
Prior to using this sample, you will need to install two dependencies:
1. Git
2. docker


## Installation of the Queue Managers
You can run the performance tests against a new or existing queue manager. The instructions below document how to deploy a new queue manager which will be configured correctly for the performance test. If you decide to use an existing queue manager then you will need to complete additional customization of the certificates, qm.ini and MQSC. Using an existing queue manager is only recommended for experienced users.
1. Log into the Kubernetes cluster from the command line.
1. Change directories to *deploy*: `cd deploy`      
1. Run the installation command to deploy an instance of the helm chart: `./install.sh <namespace>`            
    Where \<namespace\> is the Kubernetes namespace where the resources should be deployed into. This script will deploy a number of resources:
    * The IBM MQ Helm Chart using the properties within the [perfhelm_nativeha.yaml](deploy/perfhelm_nativeha.yaml) file.
    * A configMap with MQ configuration to define a default Queue, and the security required.
    * A secret that includes certificates and keys from the `genericresources/createcerts` directory. Assuring the communication in MQ is secure.
1. This will take a minute or so to deploy, and the status can be checked with the following command: `kubectl get pods | grep perfhelm`. Wait until one of the three Pods is showing `1/1` under the ready status (only one will ever show this, the remainding two will be `0/1` showing they are replicas).

## Building the "Test application"
This section will build the "Test application" that will drive workload into the Queue Manager.
1. Change directories to `buildDrivingApp`:     
  ```cd buildDrivingApp```

1. Start the build by running:     
   ```./install.sh```

1. To verify that the build was successful run `docker images` and you should see:    
   ```
   REPOSITORY      TAG          IMAGE ID       CREATED        SIZE
cphtestp        latest       00900e75b54d   20 hours ago   650MB

   ```

## Pushing the "Test application" to a container registry

Now the "Test application" image has been built, this is published to a container registry which Kubernetes will use. There are different container registries that your organization may use. These instructions demonstrate how this can be published to the internal OpenShift container image registry. Clearly if you are not using OpenShift or have another registry this process will differ.     

1.	Log into the OpenShift environment from the command line:     
   ```oc login -u kubeadmin -p <password_from_install_log> https://api-int.<cluster_name>.<base_domain>:6443```

1.	The OpenShift container image registry may not be externalized. To push the new image this needs to be changed. This step will expose the OpenShift container registry outside of the OpenShift cluster and you should consider the security implications prior to completing. If you are comfortable proceeding run the following command:      
   ```oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge```

1.	Login into the OpenShift container image registry by running the following two commands:    
   ```
   HOST=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')

   docker login -u kubeadmin -p $(oc whoami -t) $HOST
   ```

1.	Create a new project in OpenShift that will be used for the deployment:    
   ```oc new-project cp4i```

1.	The image created on the local machine needs to be tagged correctly for the OpenShift container registry. To complete run the following command:    
   ```docker tag cphtestp:latest $HOST/cp4i/cphtestp:latest```

1.	The container image is ready to be published to the OpenShift container registry. Run the following command:      
   ```docker push $HOST/cp4i/cphtestp:latest```


## Running the performance test
1. The performance test runs four separate Kubernetes jobs. Each one pulls its configuration from the [control.prop](test/control.prop) file. This includes the following properties:
  * QUEUEMANAGER_TLS_HOST: hostname or IP address that the test application should use for the TLS tests
  * QUEUEMANAGER_TLS_PORT: port number that the test application should use for the TLS tests
  * QUEUEMANAGER_HOST: hostname or IP address that the test application should use for the non-TLS tests
  * QUEUEMANAGER_PORT: port number that the test   application should use for the non-TLS tests
  * IMAGE_LOCATION: container image repository address for the test application.
  * REGISTRY_PULL_SECRET: Kubernetes pull secret for the container repository (if required).
  * CORE: cores associated with the test application. It is recommended that you assign 150% of the Queue Manager cores to the application, to avoid any bottlenecks.
  * MEMORY: memory associated with the test application. It is suggested that a 1:1 ratio between cores and Gi is used (for instance if 2 core then 2 Gi).
  * QMGR_NAME: Name of the Queue Manager that will be tested
  * STATEFUL_SET_NAME_OF_QMGR: The name of the Queue Manager stateful set. This is used to set an anti-affinity rule to assure that the same worker node does not host the test application and the Queue Manager. If you are using Native HA and only have 3 worker nodes you will want to leave this value blank.

  In general you shouldn't need to customize this file, but if you use a different container registry or queue manager configuration some customization is likely.

1. To run all of the tests run the following:
   ```
   cd test
   ./testAll.sh
   ```
   If you would prefer to be selective, open the testAll.sh file and manually run the required commands. It is important to realize that the tests will take approximately 2 hours to complete, and the results will be outputted to a results.txt file.
