# IBM MQ Helm Chart Sample

**This chart includes the capability to deploy IBM MQ Native HA. This feature is available to customers with entitlement to IBM MQ Advanced. For details on how to set the correct license annotations please consult [here](#Supplying-licensing-annotations).**

## Introduction

This chart deploys a single IBM® MQ server (Queue Manager) built from the [IBM MQ Container GitHub repository](https://github.com/ibm-messaging/mq-container), and has been verified using the [9.3.4 branch](https://github.com/ibm-messaging/mq-container/tree/9.3.4). IBM MQ is messaging middleware that simplifies and accelerates the integration of diverse applications and business data across multiple platforms.  It uses message queues, topics and subscriptions to facilitate the exchanges of information and offers a single messaging solution for cloud and on-premises environments.

## Chart Details

This chart will do the following:

* Create a single Queue Manager deployed as a [StatefulSet](http://kubernetes.io/docs/concepts/abstractions/controllers/statefulsets/) with one, two or three replicas depending on whether Native HA (High Availability option for IBM MQ with a Cloud Pak for Integration entitlement) or Multi-instance is enabled for high availability.  
* Create a [Service Account](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) which is used by the StatefulSet.
* Create a [Service](https://kubernetes.io/docs/concepts/services-networking/service/) of type ClusterIP.  This is used to ensure that other deployments within the Kubernetes Cluster have a consistent hostname/IP address to connect to the Queue Manager, regardless of where it is actually running.
* Create [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) for the storage of the Queue Manager data, one for each replica in the StatefulSet.
* [Optional] Create three [Services](https://kubernetes.io/docs/concepts/services-networking/service/) of type ClusterIP when Native HA is enabled. This provides internal communication between the three Pods of the StatefulSet.
* [Optional] Create a [Service](https://kubernetes.io/docs/concepts/services-networking/service/) of type NodePort for the MQ data traffic. This is used to ensure that MQ connections outside of the Kubernetes Cluster have a consistent entry point, regardless of where the Queue Manager is actually running.
* [Optional] Create a [Service](https://kubernetes.io/docs/concepts/services-networking/service/) of type NodePort for the MQ web console. This is used to ensure that connections to the Web Console from outside of the Kubernetes Cluster have a consistent entry point, regardless of where the Queue Manager is actually running.
* [Optional] Create an [OpenShift Route](https://docs.openshift.com/container-platform/4.8/networking/routes/route-configuration.html) for the MQ web console. This is used when accessing the Web Console from outside of an OpenShift Cluster.
* [Optional] Create an [OpenShift Route](https://docs.openshift.com/container-platform/4.8/networking/routes/route-configuration.html) for the MQ data traffic. This is used when accessing the MQ data port from outside of an OpenShift Cluster.
* [Optional] Create a metrics [Service](https://kubernetes.io/docs/concepts/services-networking/service/) for accessing Queue Manager metrics.

## Prerequisites

* Kubernetes 1.18 or later
* If a Storage Class is not specified then a suitable default [storage class](https://kubernetes.io/docs/concepts/storage/storage-classes/) must be available.


## Resources Required

This chart uses the following resources by default, but should be adjusted to meet requirements:

* Request 0.1 CPU core
* Limit 0.5 CPU core
* Request 512Mi memory
* Limit 1024Mi memory
* 2 Gi persistent volume.

See the **configuration** section for how to configure these values.

## Installing the Chart

> **Tip**: A [samples directory](../../samples/README.md) is available that demonstrates how to install the chart in a number of common environments. For first time users it is suggested that this is used.

To add the helm chart to your helm repository, run the command:

```sh
helm repo add ibm-messaging-mq https://ibm-messaging.github.io/mq-helm
```

Install the chart, specifying the release name (for example `nativeha`) and Helm chart name `ibm-mq` with the following command:

```sh
helm install nativeha ibm-mq --set license=accept
```
This command accepts the license, many of the samples use the [IBM MQ Advanced for Developers](https://www14.software.ibm.com/cgi-bin/weblap/lap.pl?la_formnum=Z125-3301-14&li_formnum=L-APIG-BYHCL7) license as a convenience, however depending on the container image, configuration of the chart, functionality enabled and your entitlement, this could be one of several. These are documented [here](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=mqibmcomv1beta1-licensing-reference). The **configuration** section lists the parameters that can be configured during installation.

> **Tip**: See all the resources deployed by the chart using `kubectl get all -l release=nativeha`


### Updating the Chart

To understand how to update a deployed chart there are two aspects that need to be understood:
1. The chart deploys a stateful set where the number of replicas depend on the high availability setting defined within the chart.
     * When the `queueManager.nativeha.enable` is set, the number of replicas will be defined as `3`
     * When the `queueManager.multiinstance.enable` is set the number of replicas will be defined as `2`
     * Otherwise only a single replica is deployed.
1. The `queueManager.updateStrategy` specify the update strategy for the StatefulSet. In the case of Native HA and Multi-instance this should always be onDelete, and therefore this parameter has no affect, while for other scenarios `RollingUpdate` is the default.

The Kubernetes [StatefulSet rolling update](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#rolling-updates) works by updating one replica at a time, not attempting to update another "until an updated Pod is Running and Ready". In many situations this is logical but in the case of Native HA and Multi-instance this prevents all the Pods from being updated automatically. For instance in a running environment prior to an upgrade there will be three pods running, but only one ready. The first Pod that is selected to be upgraded will be restarted and one of the remaining two instances will be elected the leader. The Pod being upgraded will restart and reach the running state, but will not become ready as there is another Pod acting as the leader. To avoid this situation the updateStrategy is always set to onDelete for Native HA and Multi-instance. This means that a script needs to be run after the helm update has been applied to ripple through the Pods deleting one after another once the previous Pod has reached a running state.

A [sample script](../../samples/genericresources/rollingupdate/demoRollingUpdate.sh) is provided that can be run in an interactive mode, or silently. The script has the following usage:
``demoRollingUpdate.sh [statefulSetName] [namespace]``
where:
* *statefulSetName*: name of the statefulSetName. This corresponds to the helm chart name with ibm-mq appended.
* *namespace*: the Kubernetes namespace of the statefulSet     

The following shows how to invoke in the two scenarios, where the helm chart deployment name is `myhelmdeployment` and the namespace is `mq`.
* Interactive: ```manualAcceptance=true ../../samples/genericresources/rollingupdate/demoRollingUpdate.sh myhelmdeployment-ibm-mq mq```
* Automated: ```manualAcceptance=false ../../samples/genericresources/rollingupdate/demoRollingUpdate.sh myhelmdeployment-ibm-mq mq```

> **Warning**: The `sample script` deletes Pods and there are many situations where this can cause an extended downtime or the queue manager becomes unavailable. The rolling update `sample script` may need extensive changes to meet your production cloud requirements.  

### Uninstalling the Chart

You can uninstall/delete the `nativeha` release as follows:

```sh
helm delete nativeha
```

The command removes all the Kubernetes components associated with the chart, except any Persistent Volume Claims (PVCs).  This is the default behaviour  of Kubernetes, and ensures that valuable data is not deleted.

## Configuration

The following table lists the configurable parameters of the `ibm-mq` chart and their default values.

A YAML file that specifies these values can be provided while installing the chart.

> **Tip**: You can use the default values.yaml as an example yaml file to customize

Alternatively, each parameter can be specified by using the `--set key=value[,key=value]` argument to `helm install`.

| Parameter                       | Description                                                     | Default                                    |
| ------------------------------- | --------------------------------------------------------------- | ------------------------------------------ |
| `license`                       | Set to `accept` to accept the terms of the IBM license          | `"not accepted"`                           |
| `image.repository`              | Image full name including repository                            | `ibmcom/mq`                                |
| `image.tag`                     | Image tag                                                       | `9.3.4.0-r1`                               |
| `image.pullPolicy`              | Setting that controls when the kubelet attempts to pull the specified image.                                               | `IfNotPresent`                             |
| `image.pullSecret`              | An optional list of references to secrets in the same namespace to use for pulling any of the images used by this QueueManager. If specified, these secrets will be passed to individual puller implementations for them to use. For example, in the case of docker, only DockerConfig type secrets are honoured. For more information, see [here](https://kubernetes.io/docs/concepts/containers/images#specifying-imagepullsecrets-on-a-pod)   | `nil`                                      |
| `metadata.labels`               | The labels field serves as a pass-through for Pod labels. Users can add any label to this field and have it apply to the Pod.                      | `{}`                                       |
| `metadata.annotations`          | Additional annotations to be added to the Pod annotations. This is required for licensing. Please consult [here](#Supplying-licensing-annotations)                 |`{}`                                      |
| `persistence.dataPVC.enable`           | By default all data and recovery logs are persisted to a Pod's qmPVC. dataPVC is an optional PersistentVolume which can be enabled using this field. This PersistentVolume is used for MQ persisted data, including configuration, queues and messages. If Multi-instance is enabled this value is set to true.                  | `false`                                     |
| `persistence.dataPVC.name`      |  Suffix for the PVC name               | `data`                                      |
| `persistence.dataPVC.size`      | Size of the PersistentVolume to pass to Kubernetes, including SI units. For example, 2Gi.             | `2Gi`                                      |
| `persistence.dataPVC.storageClassName`  | Storage class to use for this volume. This can be of type ReadWriteOnce or ReadWriteMany. However, IBM MQ only requires ReadWriteOnce in the configurations available via this chart and it is generally good practice to use the simpler Block Storage (ReadWriteOnce). If this value is not specified, then the default storage class will be used.                            | `""`                                       |
| `persistence.logPVC.enable`           | By default all data and recovery logs are persisted to a Pod's qmPVC. logPVC is an optional PersistentVolume which can be enabled using this field. This PersistentVolume is used for MQ recovery logs. If Multi-instance is enabled this value is set to true.                 | `false`                                     |
| `persistence.logPVC.name`      |  Suffix for the PVC name               | `data`                                      |
| `persistence.logPVC.size`      | Size of the PersistentVolume to pass to Kubernetes, including SI units. For example, 2Gi.              | `2Gi`                                      |
| `persistence.logPVC.storageClassName`  | Storage class to use for this volume. This can be of type ReadWriteOnce or ReadWriteMany, however it is generally good practice to use Block Storage (ReadWriteOnce) for Native HA deployments. If Multi-instance is enabled, the storage class must be of type ReadWriteMany. If this value is not specified, then the default storage class will be used.                            | `""`                                       |
| `persistence.qmPVC.enable`           | Default PersistentVolume for any data normally under /var/mqm. Will contain all persisted data and recovery logs, if no other volumes are specified. If Multi-instance is enabled this value is set to true.                 | `true`                                     |
| `persistence.qmPVC.name`      |  Suffix for the PVC name               | `data`                                      |
| `persistence.qmPVC.size`      | Size of the PersistentVolume to pass to Kubernetes, including SI units. For example, 2Gi.              | `2Gi`                                      |
| `persistence.qmPVC.storageClassName`  | Storage class to use for this volume. This can be of type ReadWriteOnce or ReadWriteMany, however it is generally good practice to use Block Storage (ReadWriteOnce) for Native HA deployments. If Multi-instance is enabled, the storage class must be of type ReadWriteMany. If this value is not specified, then the default storage class will be used.                            | `""`                                       |
| `resources.limits.cpu`          | Kubernetes CPU limit for each Pod of the Queue Manager container            | `500m`                                     |
| `resources.limits.memory`       | Kubernetes memory limit for each Pod of the Queue Manager container         | `0124Mi`                                    |
| `resources.requests.cpu`        | Kubernetes CPU request for each Pod of the Queue Manager container          | `100m`                                     |
| `resources.requests.memory`     | Kubernetes memory request for each Pod of the Queue Manager container       | `512Mi`                                    |
| `queueManager.multiinstance.enable`    | Whether to run in Multi-instance mode, with two Pods (one active and one passive Pods). | `false`                     |
| `queueManager.name`             | By default the Queue Manager will match the Helm release name. Use this field to change the Queue Manager name, for example if the Helm release name does not conform to the rules for naming a Queue Manager name (for example, a name longer than 48 characters).                                           | Helm release name                          |
| `queueManager.nativeha.enable`    | Whether to run in Native HA mode, with three Pods (one active and two replica Pods). Native HA is available on x86, Linux on IBM Power and Linux on IBM Z. | `false`                     |
| `queueManager.nativeha.tls.cipherSpec`    | Optional TLS settings for configuring secure communication between Native HA replicas. The name of the CipherSpec for Native HA TLS | `"ANY_TLS12_OR_HIGHER"`                     |
| `queueManager.nativeha.tls.secretName`    | Optional TLS settings for configuring secure communication between Native HA replicas. The name of the Kubernetes secret. | `""`                     |
| `queueManager.mqscConfigMaps` | An array of YAML objects that detail the Kubernetes configMap items that should be added.  For further details regarding how this is specified consult [Supplying custom mqsc using a configMap](#Supplying-custom-mqsc-using-a-configMap)  | `[]` |
| `queueManager.mqscSecrets` | An array of YAML objects that detail the Kubernetes secrets items that should be added. For further details regarding how this is specified consult [Supplying custom mqsc using a secret](#Supplying-custom-mqsc-using-a-secret)  | `[]` |
| `queueManager.qminiConfigMaps` | An array of YAML objects that detail the Kubernetes configMap items that should be added. For further details regarding how this is specified consult [Supplying QM INI using a configMap](#Supplying-QM-INI-using-a-configMap)  | `[]` |
| `queueManager.qminiSecrets` | An array of YAML objects that detail the Kubernetes secrets items that should be added.  For further details regarding how this is specified consult [Supplying QM INI using a secret](#Supplying-QM-ini-using-a-secret)  | `[]` |
| `queueManager.envVariables` | An array of YAML objects (name / value pairs) that detail the environment variables that should be associated with the Queue Manager container | `[]` |
| `queueManager.terminationGracePeriodSeconds` | Optional duration in seconds the Pod needs to terminate gracefully. Value must be non-negative integer. The value zero indicates delete immediately. The target time in which ending the queue manager is attempted, escalating the phases of application disconnection. Essential queue manager maintenance tasks are interrupted and applications disconnected if necessary. Defaults to 30 seconds. | 30                |
| `queueManager.updateStrategy`   | Specify the update strategy for the StatefulSet. In the case of Native HA and Multi-instance this should always be onDelete, and therefore this parameter has no affect. For further details regarding Native HA and Multi-instance update process consult the [Updating Native HA and Multi-instance section](#Updating-the-Chart). In the case of a single instance queue manager the default is RollingUpdate. | `RollingUpdate` - single instance, `onDelete` - Native HA  and Multi-instance |
| `web.enable`    | Whether or not to enable the web server. Default is empty string, which causes the default behaviour of the container. Set to `true` to enable the web console, and `false` to disable. | `` |
| `web.manualConfig.configMap.name`     | ConfigMap represents a Kubernetes ConfigMap that contains web server XML configuration. The web.manualConfig can only include either the configMap or secret parameter, not both. For further details regarding how this is specified consult [Supplying custom web console configuration](#Supplying-custom-web-console-configuration)| `` |
| `web.manualConfig.secret.name`     | Secret represents a Kubernetes Secret that contains web server XML configuration. The web.manualConfig can only include either the configMap or secret parameter, not both. For further details regarding how this is specified consult [Supplying custom web console configuration](#Supplying-custom-web-console-configuration)| `` |
| `pki.keys`                      | An array of YAML objects that detail Kubernetes secrets containing TLS Certificates with private keys. For further details regarding how this is specified consult [Supplying certificates to be used for TLS](#Supplying-certificates-to-be-used-for-TLS) | `[]` |
| `pki.trust`                     | An array of YAML objects that detail Kubernetes secrets or configMaps containing TLS Certificates. For further details regarding how this is specified consult [Supplying certificates using secrets to be used for TLS](#Supplying-certificates-to-be-used-for-TLS) and [Supplying certificates using a configMap](#Supplying-certificates-using-a-configMap)   | `[]` |
| `security.context.fsGroup`      | A special supplemental group that applies to all containers in a pod. Some volume types allow the Kubelet to change the ownership of that volume to be owned by the pod: 1. The owning GID will be the FSGroup 2. The setgid bit is set (new files created in the volume will be owned by FSGroup) 3. The permission bits are OR'd with rw-rw---- If unset, the Kubelet will not modify the ownership and permissions of any volume.          | `nil`                                      |
| `security.context.seccompProfile.type` | Seccomp stands for secure computing mode and when enabled restricts the calls that can be made to the kernel. For more information, see https://kubernetes.io/docs/tutorials/security/seccomp/ | `nil`                                  |
| `security.context.supplementalGroups` | A list of groups applied to the first process run in each container, in addition to the container's primary GID. If unspecified, no groups will be added to any container. | `nil`                                  |
| `security.initVolumeAsRoot`     | This affects the securityContext used by the container which initializes the PersistentVolume. Set this to true if you are using a storage provider which requires you to be the root user to access newly provisioned volumes. Setting this to true affects which Security Context Constraints (SCC) object you can use, and the Queue Manager may fail to start if you are not authorized to use an SCC which allows the root user. Defaults to false. For more information, see https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html. | `false`                  |
| `security.runAsUser` | Controls which user ID the containers are run with.  | `nil`                               |
| `livenessProbe.initialDelaySeconds` | Number of seconds after the container has started before the probe is initiated. Defaults to 90 seconds for SingleInstance. Defaults to 0 seconds for a Native HA and Multi-instance deployments. | `90` - single instance, `0` - Native HA and Multi-instance |
| `livenessProbe.periodSeconds`   | How often (in seconds) to perform the probe.                                       | 10                                         |
| `livenessProbe.timeoutSeconds`  | Number of seconds after which the probe times out               | 5                                          |
| `livenessProbe.failureThreshold` | Minimum consecutive failures for the probe to be considered failed after having succeeded | 1               |
| `readinessProbe.initialDelaySeconds` | Number of seconds after the container has started before the probe is initiated. Defaults to 10 seconds for SingleInstance. Defaults to 0 for a Native HA and Multi-instance deployment.      | 10                                         |
| `readinessProbe.periodSeconds`  | How often (in seconds) to perform the probe.                    | 5                                          |
| `readinessProbe.timeoutSeconds` | Number of seconds after which the probe times out               | 3                                          |
| `readinessProbe.failureThreshold` | Minimum consecutive failures for the probe to be considered failed after having succeeded | 1              |
| `startupProbe.timeoutSeconds` | Number of seconds after which the probe times out.        | 5                                         |
| `startupProbe.periodSeconds`  | How often (in seconds) to perform the probe.              | 5                                          |
| `startupProbe.successThreshold` | Minimum consecutive successes for the probe to be considered successful.               | 1                                          |
| `startupProbe.failureThreshold` | Minimum consecutive failures for the probe to be considered failed after having succeeded | 24              |
| `route.ingress.annotations`          | Additional annotations to be added to an ingress.                 |`{}`                                      |
| `route.ingress.webconsole.enable `     | Controls if an ingress is created for the MQ web console traffic. For more information, see https://kubernetes.io/docs/concepts/services-networking/ingress/ | `false`                                    |
| `route.ingress.webconsole.hostname `     | Specifies the host value of the ingress rule.     | `false`                                    |
| `route.ingress.webconsole.path `     | Specifies the path of the ingress rule.      | `/`                                    |
| `route.ingress.webconsole.tls.enable `     | If TLS is enabled for the web console ingress.      | `false`                                    |
| `route.ingress.webconsole.tls.secret `     | The kubernetes secret containing the certificates to be used.      | `false`                                   |
| `route.loadBalancer.annotations`          | Additional annotations to be added to the load balancer service.                 |`{}`                                      |
| `route.loadBalancer.loadBalancerSourceRanges`          | This is an array of CIDRs that can be added to a loadbalancer to restrict traffic      |`[]`                  |
| `route.loadBalancer.mqtraffic `     | Controls if a load balancer service is created for the MQ data traffic.      | `false`                                    |
| `route.loadBalancer.webconsole`     | Controls if a load balancer service is created for the MQ web console.       | `false`                                    |
| `route.nodePort.webconsole`     | Controls if a node port is created for the MQ web console.       | `false`                                    |
| `route.nodePort.mqtraffic `     | Controls if a node port is created for the MQ data traffic.      | `false`                                    |
| `route.openShiftRoute.webconsole`     | Controls if an OpenShift Route is created for the MQ web console.       | `false`                                    |
| `route.openShiftRoute.mqtraffic `     | Controls if an OpenShift Route is created for the MQ data traffic.      | `false`                                    |
| `log.format`                    | Which log format to use for this container. Use `json`` for JSON-formatted logs from the container. Use `basic` for text-formatted messages. | `basic`                                 |
| `log.debug`                     | Enables additional log output for debug purposes. | `false` |
| `trace.strmqm`                  | Whether to enable MQ trace on the `strmqm` command | `false` |
| `trace.crtmqdir`                | Whether to enable MQ trace on the `crtmqdir` command | `false` |
| `trace.crtmqm`                  | Whether to enable MQ trace on `crtmqm` command | `false` |
| `metrics.enabled`               | Whether or not to enable an endpoint for Prometheus-compatible metrics.                 | `true`                                     |
| `affinity.nodeAffinity.matchExpressions` | Force deployments to particular nodes. Corresponds to the Kubernetes specification for [NodeSelectorRequirement](https://v1-18.docs.kubernetes.io/docs/reference/generated/kubernetes-api/v1.18/#nodeselectorrequirement-v1-core)                  | ``                                     |
| `tolerations` | Allow pods to be scheduled on nodes with particular taints. Corresponds to the Kubernetes specification for [Torleration](https://v1-18.docs.kubernetes.io/docs/reference/generated/kubernetes-api/v1.18/#toleration-v1-core)                 | ``                                     |

## Storage

The chart mounts [Persistent Volumes](http://kubernetes.io/docs/user-guide/persistent-volumes/) for the storage of MQ configuration data and messages.  By using Persistent Volumes based on network-attached storage, Kubernetes can re-schedule the MQ server onto a different worker node.  You should not use "hostPath" or "local" volumes, because this will not allow moving between nodes.

If deploying a Multi-instance queue manager file storage must be used for the queue manager and log volumes. For further information regarding the file system characteristics please consult [here](https://www.ibm.com/support/pages/testing-statement-ibm-mq-multi-instance-queue-manager-file-systems).

It is recommended to use block storage for single instance and Native HA, instead of file storage for persistent volumes. This is due to the performance characteristics of block being (in general) superior to file storage. In the case of Native HA, all three Pods will have their own Persistent Volumes and IBM MQ will automatically replicate the MQ configuration data and messages across the three storage instances. These can be deployed across multiple availability zones.

## Limitations

You must not manually change the number of replicas in the StatefulSet.  The number of replicas controls whether or not Native HA or Multi-instance queue managers are used, and are changed in conjunction with other settings.

The recommended way to scale MQ is by deploying this chart multiple times, creating multiple unique Queue Managers, and connecting the Queue Managers together using MQ configuration, such as MQ clusters — see [Architectures based on multiple queue managers](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=planning-architectures-based-multiple-queue-managers).

## JSON log output

By default, the MQ container output is in a basic human-readable format.  You can change this to JSON format, to better integrate with log aggregation services.

## Connecting to the web console

The MQ image includes the MQ web server.  The web server runs the web console, and the MQ REST APIs.  By default, the MQ server deployed by this chart is accessible via a `ClusterIP` [Service](https://kubernetes.io/docs/concepts/services-networking/service/), which is only accessible from within the Kubernetes cluster.  Optionally an OpenShift Route, Load balancer or Kubernetes NodePort can be configured to connect to the web console from outside of the Kubernetes cluster.

## Considerations when upgrading the Kubernetes cluster

During a Kubernetes cluster upgrade the worker nodes are made unschedulable, to avoid new pods from being deployed, and drained to move the current workload to other worker nodes. Once all pods are removed, the worker node can be safely upgraded. Often additional worker nodes are created during the upgrade process to provide capacity for these drained pods. To preserve an applications availability pod disruption budget (PDB) allows you to declare the number of pods that should be available. This acts as a break in the upgrade process assuring a balance between the speed of the upgrade and application availability. The exact semantics of the upgrade process differs from one Kubernetes distribution to another but the high level process remains similar.

PDB’s allow you to define the minAvailable or maxUnavailable pods for a built-in Kubernetes Controller (such as a deployment, statefulSet etc). To determine the number of pods either available or not available, it uses the Readiness of the pod. In the case of Native HA during normal operations there are 2 un-ready pods (with liveness settings of true), and 1 ready pod. This design was taken as it allows Kubernetes to automatically route the traffic to the pod that is the leader for the Native HA queue manager. This causes an issue when using a PDB with either minAvailable set to 2, or maxUnavailable set to 1. In normal operations even before an upgrade the PDB will consider minAvailable to be 1, and maxUnavailable 2. Therefore, we need some additional intelligence to help the process. What we want to achieve is the following:

1.	Prevent the Kubernetes cluster upgrade from deleting MQ Native HA pods as it does not have the intelligence to do so.
2.	Delete, in a controlled manner, the MQ Native HA pods when a node is unschedulable.

The first is achieved by using a PDB, with either a minAvailable set to 2 or a maxUnavailable set to 1. A sample PDB is provider [here](../../samples/genericresources/kubernetesupgrade/mqnativeha-pdb.yaml). For the second, while the Kubernetes cluster upgrade is running, the [drainMQContainers](../../samples/genericresources/kubernetesupgrade/drainMQContainers.sh) script is run at the same time. While running, every 30 seconds it checks for unscheduled nodes, if one or more are identified it will query for IBM MQ pods, and check if the queue manager has connectivity and data is in-sync across the 3 containers. If so, it is safe to delete the one pod, as Native HA will be able to rapidly recover. 

The [drainMQContainer](../../samples/genericresources/kubernetesupgrade/drainMQContainers.sh) script is a sample that may require customization for your own environment and use case. The script has the following usage: 
``drainMQContainer.sh [namespace]`` where:

* *namespace*: the Kubernetes namespace of the statefulSets to be drained


## Supplying certificates to be used for TLS

The `pki.trust` and `pki.keys` allow you to supply details of Kubernetes secrets and configMaps that contain TLS certificates. Supplying certificates using configMaps is only permitted for `pki.trust`. By doing so the TLS certificates will be imported into the container at runtime and MQ will be configured to use them.

If you supply invalid configuration then the container will terminate with an appropriate termination message. The next 3 sections will detail the requirements for how this is specified.

### Supplying certificates which contain the public and private keys

When supplying a Kubernetes secret you must ensure that the secret item name ends in `.crt` for public certificates and `.key` for private keys. For example: `tls.crt` and `tls.key`. If your certificate has been issued by a Certificate Authority, then the certificate from the CA must be included as a separate item with the `.crt` extension. For example: `ca.crt`.

The format of the YAML objects for `pki.keys` value is as follows:

```YAML
pki:
  keys:
    - name: default
      secret:
        secretName: qmsecret
        items:
          - tls.key
          - tls.crt
          - ca.crt
```

`name` must be set to a lowercase alphanumeric value and will be used as the label for the certificate in the keystore and queue manager.

`secret.secretName` must match the name of a Kubernetes secret that contains the TLS certificates you wish to import

`secret.items` must list the TLS certificate files contained in `secret.secretName` you want to import.

If you supply multiple YAML objects then the queue manager will use the first object chosen by the label name alphabetically. For example if you supply the following labels: `alabel`, `blabel` and `clabel`. The queue manager will use the certificate with the label `alabel` for its identity. In this queue manager this can be changed by running the MQSC command: `ALTER QMGR CERTLABL('<new label>')`.

### Supplying certficates which contain only the public key
When supplying a Kubernetes secret that contains a certificate file with only the public key you must ensure that the secret contains files that have the extension `.crt`. For example: `app.crt`.

The format of the YAML objects for `pki.trust` value is as follows:

```YAML
pki:
  trust:
    - name: default
      secret:
        secretName: appsecret
        items:
          - app.crt
```

`secret.secretName` must match the name of a Kubernetes secret that contains the TLS certificates you wish to add.

`secret.items` must list the TLS certificate files contained in `secret.secretName` you want to add.

If you supply multiple YAML objects then all of the certificates specified will be added into the queue manager trust store.

## Supplying certificates using a configMap
When supplying a Kubernetes configMap that contains a certificate file with only the public key you must ensure that the configMap contains files that have the extension `.crt`. For example: `ca.crt`.

The format of the YAML objects for `pki.trust` value is as follows:

```YAML
pki:
  trust:
    - name: default
      configMap:
        configMapName: helmsecure
        items:
          - ca.crt
```

`configMap.configMapName` must match the name of a Kubernetes configMap that contains the TLS certificates you wish to add.

`configMap.items` must list the TLS certificate files contained in `configMap.configMapName` you want to add.

If you supply multiple YAML objects then all of the certificates specified will be added into the queue manager trust store.

## Supplying custom mqsc using a ConfigMap
Configuration of Queue Manager resources can be applied at Queue Manager creation and start time by providing mqsc ConfigMaps.

When supplying a Kubernetes ConfigMap you must ensure that the item name ends in `.mqsc`. For example: `mq.mqsc`.
The format of the YAML object for `queueManager.mqscConfigMaps` is as follows:
```YAML
queueManager:
  mqscConfigMaps:
    - name: myConfigMap
      items:
        - mq.mqsc
```
`queueManager.mqscConfigMaps.name` must match the name of a Kubernetes configMap that contains the MQSC you wish to add.

`queueManager.mqscConfigMaps.items` must list the MQSC files contained in ` queueManager.mqscConfigMaps.name ` you want to add.

## Supplying QM INI using a configMap
The Queue Manager's behaviour can be customised at creation and start time by providing qm.ini file settings.

When supplying a Kubernetes configMap you must ensure that the item name ends in `.ini`. For example: `qm.ini`.
The format of the YAML object for `queueManager.qminiConfigMaps` is as follows:
```YAML
queueManager:
  qminiConfigMaps:
    - name: myConfigMap
      items:
        - qm.ini
```
`queueManager.qminiConfigMaps.name` must match the name of a Kubernetes configMap that contains the qm.ini you wish to add.

`queueManager.qminiConfigMaps.items` must list the qm.ini files contained in ` queueManager.qminiConfigMaps.name ` you want to add.

## Supplying custom mqsc using a secret
You may choose to provide mqsc configuration as a secret rather than a ConfigMap.

When supplying a Kubernetes secret you must ensure that the item name ends in `.mqsc`. For example: `mq.mqsc`.
The format of the YAML object for `queueManager.mqscSecrets` is as follows:
```YAML
queueManager:
  mqscSecrets:
    - name: mqscsecret
      items:
        - secretmq.mqsc
```
`queueManager.mqscSecrets.name` must match the name of a Kubernetes secret that contains the MQSC you wish to add.

`queueManager.mqscSecrets.items` must list the MQSC files contained in ` queueManager.mqscSecrets.name ` you want to add.

## Supplying QM INI using a secret
You may choose to provide qm.ini configuration as a secret rather than a ConfigMap.

When supplying a Kubernetes secret you must ensure that the item name ends in `.ini`. For example: `qm.ini`.
The format of the YAML object for `queueManager.qminiConfigMaps` is as follows:
```YAML
qminiSecrets:
  - name: inisecret
    items:
      - secretmq.ini
```
`queueManager.qminiSecrets.name` must match the name of a Kubernetes secret that contains the qm.ini you wish to add.

`queueManager.qminiSecrets.items` must list the qm.ini files contained in ` queueManager.qminiSecrets.name ` you want to add.

##  Supplying custom web console configuration
The `web.manualConfig` parameter allows you to supply custom web console configuration. This is particularly useful when using a licensed image (non-Developer edition) as the web console is not configured in this environment. The custom configuration can be either stored within a Kubernetes configMap or secret, with two separate parameters available: `web.manualConfig.configMap.name` and `web.manualConfig.secret.name`. For example, if you wanted to set a variable using a configMap you would use the following:
```YAML
web:
  enable: true
  manualConfig:
    configMap:
      name: mywebconfig
```         

**Sample configMap configuration**
```YAML
kind: ConfigMap
apiVersion: v1
metadata:
  name: mywebconfig
data:
  mqwebuser.xml: |-
    <variable name="myCustomVariable" value="*"/>
```

## Supplying licensing annotations
IBM License Service annotations need to be specified to track the usage and meet the license requirements specified [here](https://www.ibm.com/software/passportadvantage/containerlicenses.html). To do this, metadata annotations need to be specified as shown below:
```YAML
metadata:
  annotations:
    productName: "IBM MQ Advanced for Non-Production with CP4I License"
    productID: "21dfe9a0f00f444f888756d835334909"
    productChargedContainers: "qmgr"
    productMetric: "VIRTUAL_PROCESSOR_CORE"
    productCloudpakRatio: "4:1"
    cloudpakName: "IBM Cloud Pak for Integration"
    cloudpakId: "c8b82d189e7545f0892db9ef2731b90d"
```
Depending on the deployment scenario different annotations should be used, for a complete list please consult the IBM MQ Knowledge Center [here](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=sbyomcic-license-annotations-when-building-your-own-mq-container-image#ctr_license_annot__annot8)

## Copyright

© Copyright IBM Corporation 2021
