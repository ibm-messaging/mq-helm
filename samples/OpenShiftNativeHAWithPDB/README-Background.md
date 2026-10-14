# Protecting IBM MQ Native HA with Pod Disruption Budgets

---

## Introduction

Running IBM MQ in a Kubernetes environment unlocks the power of cloud-native infrastructure — automatic pod scheduling, declarative configuration, and seamless integration with the rest of your platform. With that power comes a subtle risk: Kubernetes does not know that your IBM MQ pods are special. When a cluster administrator drains a node for maintenance, patches a worker, or performs a rolling upgrade, Kubernetes will evict pods according to its own scheduling logic — which, without guidance, may choose to evict too many pods preventing quorum and the ability to process messages.

The [IBM MQ Operator for IBM MQ v10.0.1](https://www.ibm.com/docs/en/ibm-mq/10.0.x?topic=support-mq-operator), supported on Red Hat® OpenShift® Container Platform and Amazon EKS, introduces first-class support for Kubernetes [PodDisruptionBudgets (PDB)](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) for both **Native HA** and **Multi-instance** deployments. This post explains why that matters, how it works under the hood, how to enable it, and how to perform a safe rolling update once PDB is active. Additionally, IBM MQ provides a [sample Helm chart](https://github.com/ibm-messaging/mq-helm) with a PDB sample, for use with the prebuilt IBM MQ container image, which can configure PDB for IBM MQ without requiring the IBM MQ Operator.

---

## A Brief Background to IBM MQ Native HA

IBM MQ Native HA provides high availability by running a single logical queue manager across **three Kubernetes pods** deployed as a StatefulSet. At any given moment:

- **One pod is Active** — it processes client connections and messages.
- **Two pods are Replicas** — they maintain a synchronised copy of the queue manager data and are ready to take over if the Active instance fails.

Replication between the three instances uses a dedicated replication channel (port 9414 by default). When the Active instance becomes unavailable, the remaining two Replicas elect a new Active through a quorum vote, and applications reconnect automatically.

The three-pod topology provides:
- **Zero data loss** — all messages are committed to at least two instances before the client receives acknowledgement.
- **Fast failover** — a new Active is elected in seconds, not minutes.
- **Geographic resilience** — pods can be spread across availability zones using pod anti-affinity rules.

Multi-instance queue managers follow the same principle but with two pods (one Active, one Standby) and rely on shared file storage rather than synchronous replication.

---

## Why Standard PodDisruptionBudgets Don't Work with Native HA

This is where things get interesting — and where IBM MQ v10.0.1 makes a crucial improvement.

### The Kubernetes Readiness Problem

Kubernetes uses a pod's **readiness probe** to decide whether a pod is healthy enough to receive traffic. The readiness probe is also what PodDisruptionBudgets use to count "available" pods when enforcing disruption limits.

In a Native HA deployment, the readiness probe is configured to return `Ready` only on the **Active** instance. The Replica pods are intentionally left in a non-ready state so that Kubernetes services route traffic exclusively to the Active pod. The result is that a standard `kubectl get pods` on a healthy Native HA deployment looks like this:

```
NAME                     READY   STATUS    RESTARTS   AGE
secureapphelm-ibm-mq-0   1/1     Running   0          12m
secureapphelm-ibm-mq-1   0/1     Running   0          12m
secureapphelm-ibm-mq-2   0/1     Running   0          12m
```

Only **one pod is `Ready`**, even though all three are running and healthy.

### Why This Breaks a Naive PDB

A PodDisruptionBudget works by comparing the number of ready pods against a threshold. Consider a PDB defined as:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: mq-nativeha-pdb
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: secureapphelm
```

With `maxUnavailable: 1`, Kubernetes allows at most one pod to be unavailable at any time. In normal operation, **two** of the three pods report `0/1 Ready` — they are already "unavailable" from the PDB's perspective. The PDB's budget is immediately exceeded before any disruption even begins, meaning Kubernetes cannot evict **any** pod. A node drain will stall indefinitely, blocking cluster maintenance.

Alternatively, if you set `minAvailable: 2`, the same situation applies: only one pod is currently ready, which is already below the threshold of 2 — again blocking all evictions.

This is not a bug in Kubernetes. The Replica pods are genuinely not ready to serve application traffic. But from a resilience perspective, those two pods are in perfect health. The problem is that Kubernetes has no way to distinguish "not ready because it is a healthy Replica" from "not ready because it has failed".

---

## The IBM MQ v10.0.1 Solution: Label-Aware PDB

IBM MQ v10.0.1 solves this by introducing a **lightweight metadata sidecar container** that runs alongside the queue manager in each pod. This sidecar watches the queue manager's state and dynamically labels the pod with its current role:

| Label key | Label value | Meaning |
|---|---|---|
| `mq.ibm.com/status` | `<none>` | Pod is starting up |
| `mq.ibm.com/status` | `starting` | Queue manager is starting |
| `mq.ibm.com/status` | `active` | This pod is the Active instance |
| `mq.ibm.com/status` | `replica` | This pod is a healthy Replica instance |

The PodDisruptionBudget's selector covers **all three pods** in the StatefulSet — Active and both Replicas — using the standard release selector labels:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ibm-mq
      app.kubernetes.io/instance: secureapphelm
```

This is the correct behaviour. With all three pods now reporting `2/2 Ready` (thanks to the sidecar), `maxUnavailable: 1` means Kubernetes may disrupt at most one pod at a time across the whole Native HA group. During a node drain it sees three healthy pods, permits one eviction, and blocks any further eviction until that pod recovers and becomes ready again. This prevents the most dangerous scenarios: two Replicas being removed simultaneously (destroying redundancy), or the Active being evicted before a Replica is ready to replace it.

> **Note:** The `ibm-mq.pdbSelectorLabels` helper in the chart — which *does* include `mq.ibm.com/status: active` — is a *service* selector used to route **application traffic** exclusively to the Active pod. It is a completely separate concern from the PDB definition.

The sidecar also updates the pod's ready state. With PDB enabled, a healthy deployment looks like this:

```
NAME                     READY   STATUS    RESTARTS   AGE
secureapphelm-ibm-mq-0   2/2     Running   0          12m
secureapphelm-ibm-mq-1   2/2     Running   0          12m
secureapphelm-ibm-mq-2   2/2     Running   0          12m
```

All three pods now show **`2/2` Ready** — the main `qmgr` container plus the `metadataserver` sidecar are both running and healthy. To identify which pod is Active, you query by label:

```bash
# Show the active instance only
kubectl get pods -l mq.ibm.com/status=active

# Show all pods with their role labels
kubectl get pod -o custom-columns='NAME:.metadata.name,STATUS:.metadata.labels.mq\.ibm\.com/status' \
  -l app.kubernetes.io/instance=secureapphelm
```

Example output:
```
NAME                     STATUS
secureapphelm-ibm-mq-0   active
secureapphelm-ibm-mq-1   replica
secureapphelm-ibm-mq-2   replica
```

---

## How the Sidecar Works

The metadata sidecar is a native sidecar container (using Kubernetes `initContainer` with `restartPolicy: Always`, which graduated to GA in Kubernetes v1.29). This means:

- It starts before the main `qmgr` container and restarts independently if it fails.
- It runs the `runmetadataserver` entrypoint from the same IBM MQ container image — no additional image is required.
- It mounts the pod's own metadata (labels and annotations) via the Kubernetes [Downward API](https://kubernetes.io/docs/concepts/workloads/pods/downward-api/).
- It uses a short-lived, scoped service account token (2-hour TTL) to call the Kubernetes API and `PATCH` its own pod's `mq.ibm.com/status` label and pod annotations.

The MQ queue manager is simultaneously configured with the environment variable `MQ_ENABLE_READY_REPLICAS=true`, which tells the MQ container to expose its current role state to the sidecar.

The RBAC model is minimal by design:

```yaml
# Role: permits patching only the specific pods in this release
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["patch"]
    resourceNames:
      - secureapphelm-ibm-mq-0
      - secureapphelm-ibm-mq-1
      - secureapphelm-ibm-mq-2
```

The sidecar cannot modify any other resource in the cluster. The `automountServiceAccountToken: false` is set on the pod spec; the sidecar receives the token only through an explicitly projected volume, keeping the attack surface minimal.

### Licensing Annotations: Role-Based Charging

A key feature of the metadata sidecar is its ability to dynamically adjust license metering metrics (via pod annotations) based on the queue manager's role, so that the **IBM License Service** can track and measure license consumption correctly. It is essential that accurate license metering can be performed so that Active and Replica instances can be charged differently.

The sidecar monitors the queue manager's active/replica state and applies the appropriate set of annotations:

- **`metadata.annotations`** — These are set outside a Native HA and Multi-instance setup, or applied when the pod is detected as **Active** by the sidecar. These annotations reflect the cost of running an active queue manager instance (e.g., charged per virtual processor core for IBM MQ Advanced).
- **`metadata.license_when_replica_or_standby`** — Applied as annotations at qmgr pod start-up, and when the pod is detected as a **Replica** (Native HA) or **Standby** (Multi-instance) by the sidecar. These annotations reflect the zero or reduced charge for standby instances.

#### How Annotation Switching Works

When a pod starts with PDB enabled, the Helm chart initially deploys it with the `license_when_replica_or_standby` metadata annotations. This conservative approach ensures that newly starting pods are charged at the replica rate, which is free for Native HA replicas. As soon as the metadata sidecar detects that the queue manager has become Active, it dynamically patches the pod's annotations to switch to the Active set. If a failover occurs and the pod transitions from Active to Replica, the sidecar reverses the switch, re-applying the replica annotations.

This dynamic switching ensures that the IBM License Service (or equivalent metering agents) observes accurate, role-aware annotations at all times — licensing charges match the pod's actual runtime state, not its initial deployment state.

#### Example: IBM MQ Advanced with PDB

For IBM MQ Advanced with licensing enabled, you would configure two annotation sets in your `values.yaml`:

```yaml
metadata:
  # Active pod annotations — charged per virtual processor core
  annotations:
    productName: "IBM MQ Advanced"
    productID: "208423bb063c43288328b1d788745b0c"
    productChargedContainers: "qmgr"
    productMetric: "VIRTUAL_PROCESSOR_CORE"
  # Replica/Standby pod annotations — free for Native HA replicas
  license_when_replica_or_standby:
    productName: "IBM MQ Native HA Replica"
    productID: "0d8c5097de514a3db4d8cb3b140a7957"
    productChargedContainers: "qmgr"
    productMetric: "FREE"
```

At deployment time (Helm install), all three pods initially report the replica annotations. Within seconds, as soon as the Active pod's sidecar detects that the queue manager is running and has become active, it patches its own pod's annotations to switch to the Active set. The other two Replicas remain on the replica annotations. During a failover, if pod-0 (previously Active) becomes a Replica and pod-1 becomes the new Active, the sidecars automatically adjust: pod-0's annotations revert to replica, and pod-1's annotations switch to active.


---

## Enabling PDB in the IBM MQ Helm Chart

### Prerequisites

- Kubernetes **1.29 or later** (the native sidecar `initContainer.restartPolicy: Always` feature is required).
- IBM MQ Helm chart **v3.4.0 or later** (shipped with IBM MQ v10.0.1).
- `queueManager.nativeha.enable: true` **or** `queueManager.multiinstance.enable: true` — PDB requires a multi-replica topology and the chart will fail fast with a clear error if you attempt to enable it for a single-instance deployment.

### Minimum Configuration

Add the following to your `values.yaml` file:

```yaml
queueManager:
  nativeha:
    enable: true
  podDisruptionBudget:
    enable: true
    maxUnavailable: 1
```

This is the only change required. The chart will automatically create:

1. A **`PodDisruptionBudget`** scoped to the active pod label.
2. A **`Role`** granting `patch` on the three StatefulSet pods.
3. A **`RoleBinding`** binding that role to the queue manager's service account.
4. A **native sidecar container** (`metadataserver`) alongside each queue manager pod.

> **Note:** `podDisruptionBudget.maxUnavailable` defaults to `1` when not set and accepts either a positive integer (e.g., `1`) or a percentage string (e.g., `"50%"`). For Native HA with `maxUnavailable: 1`, only one pod — the Active — is protected at any given time. This is the recommended setting.

### Full Native HA with PDB — Example Values File

The following is based on the sample from [`samples/OpenShiftNativeHAWithPDB/deploy/secureapp_nativeha.yaml`](samples/OpenShiftNativeHAWithPDB/deploy/secureapp_nativeha.yaml):

```yaml
license: accept

image:
  repository: icr.io/ibm-messaging/mq
  tag: 10.0.1.0-r1
  pullPolicy: IfNotPresent

queueManager:
  nativeha:
    enable: true
    tls:
      secretName: helmsecure
  mqscConfigMaps:
    - name: helmsecure
      items:
        - mq.mqsc
  qminiConfigMaps:
    - name: helmsecure
      items:
        - mq.ini
  podDisruptionBudget:
    enable: true
    maxUnavailable: 1

persistence:
  qmPVC:
    enable: true

pki:
  keys:
    - name: default
      secret:
        secretName: helmsecure
        items:
          - tls.key
          - tls.crt
  trust:
    - name: default
      secret:
        secretName: helmsecure
        items:
          - app.crt

metadata:
  # Annotations applied when the pod is Active
  annotations:
    productName: "IBM MQ Advanced for Developers"
    productID: "2f886a3eefbe4ccb89b2adb97c78b9cb"
    productChargedContainers: "qmgr"
    productMetric: "FREE"
  # Annotations applied when the pod is a Replica or Standby
  # The sidecar will dynamically switch between these two sets based on role
  license_when_replica_or_standby:
    productName: "IBM MQ Advanced for Developers"
    productID: "2f886a3eefbe4ccb89b2adb97c78b9cb"
    productChargedContainers: "qmgr"
    productMetric: "FREE"
```

> **Note:** The `metadata.annotations` and `metadata.license_when_replica_or_standby` sections are optional but recommended to comply with licensing requirements. They enable dynamic license annotation switching based on the queue manager's active/replica role. Update these values to match your licensing model and product edition. See the sample file for commented examples of IBM MQ Advanced licensing configuration.

Install with:

```bash
helm install secureapphelm ../../../charts/ibm-mq -f secureapp_nativeha.yaml
```

After deployment, wait until all three pods show `2/2` in the `READY` column:

```bash
kubectl get pods -l app.kubernetes.io/instance=secureapphelm
```

```
NAME                     READY   STATUS    RESTARTS   AGE
secureapphelm-ibm-mq-0   2/2     Running   0          3m
secureapphelm-ibm-mq-1   2/2     Running   0          3m
secureapphelm-ibm-mq-2   2/2     Running   0          3m
```

---

## Performing a Safe Rolling Update with PDB

When PDB is enabled or not, a safe rolling update requires a coordinated update. The PDB enforces `maxUnavailable: 1`, which means Kubernetes will not voluntarily evict more than one pod at a time. Without a coordinated rolling update strategy, deleting multiple pods simultaneously could result in more than one pod becoming unavailable, violating the PDB constraint and potentially losing quorum. The `demoRollingUpdatePDB.sh` script in [`samples/genericresources/rollingupdate/`](samples/genericresources/rollingupdate/demoRollingUpdatePDB.sh) handles this coordination automatically.

### What the Script Does

The script implements the following safe sequence:

1. **Discover the Active pod** by querying for pods with the label `mq.ibm.com/status=active` where the sidecar is ready.
2. **Present the plan** to the operator (interactive mode) before making any changes.
3. **Restart each Replica pod first**, one at a time. After each restart, it waits for the pod to become ready and verifies that the queue manager reports `INSYNC(yes)` and `QUORUM(3/3)` before proceeding to the next pod.
4. **Restart the Active pod last**, triggering a single controlled failover.
5. **Report the new Active pod** once the cycle is complete.

This ensures there is only ever **one failover** during the entire update and that the queue manager is always in a healthy, fully-synchronised state before the next pod is recycled.

### Usage

```bash
# Interactive mode (default — prompts for confirmation before starting)
./demoRollingUpdatePDB.sh <statefulSetName> <namespace>

# Automated mode (for CI/CD pipelines)
manualAcceptance=false ./demoRollingUpdatePDB.sh <statefulSetName> <namespace>
```

Where `statefulSetName` is the Helm release name with `-ibm-mq` appended. For example, if the Helm release is `secureapphelm`:

```bash
./demoRollingUpdatePDB.sh secureapphelm-ibm-mq cp4i
```

### Example Session

```
Found the following pods to recycle: secureapphelm-ibm-mq-0, secureapphelm-ibm-mq-1, secureapphelm-ibm-mq-2,
Determined secureapphelm-ibm-mq-0 is the Active instance and will leave until the end
To continue type 'accept' below:
accept

Recycling Replica instance pod: secureapphelm-ibm-mq-1
secureapphelm-ibm-mq-1 deleted. Waiting for the pod to become ready...
secureapphelm-ibm-mq-1 ready
Checking the queue manager INSYNC and QUORUM status ...
Queue Manager INSYNC: yes
Queue Manager QUORUM: 3/3

Recycling Replica instance pod: secureapphelm-ibm-mq-2
secureapphelm-ibm-mq-2 deleted. Waiting for the pod to become ready...
secureapphelm-ibm-mq-2 ready
Checking the queue manager INSYNC and QUORUM status ...
Queue Manager INSYNC: yes
Queue Manager QUORUM: 3/3

Recycling Active instance pod: secureapphelm-ibm-mq-0
secureapphelm-ibm-mq-0 deleted. Waiting for the pod to become ready...
secureapphelm-ibm-mq-0 ready
Checking the queue manager INSYNC and QUORUM status ...
Queue Manager INSYNC: yes
Queue Manager QUORUM: 3/3

Recycle complete.
The Active instance pod is now: secureapphelm-ibm-mq-1
```

### Why Replica-First Ordering Matters

By restarting Replica pods before the Active pod, the queue manager maintains uninterrupted quorum (`2/3` or `3/3`) enabling the Active pod to continue processing messages without interruption. Once the Replica recovers and re-synchronises (`INSYNC: yes`), the script moves on to the next pod. The single failover at the end is unavoidable but brief — applications that implement MQ reconnect logic will transparently reconnect to the newly elected Active pod within seconds.

---

## Conclusion

### When Should You Enable PDB?

You should enable `podDisruptionBudget` for any IBM MQ Native HA or Multi-instance deployment where:

- **Cluster maintenance is performed regularly** — node upgrades, security patches, or hardware refresh cycles will drain nodes and evict pods. Without a PDB, Kubernetes may evict too many MQ pods which would prevent message processing.
- **You are running on a managed Kubernetes service** — cloud providers such as AWS EKS, Azure AKS, Google GKE, and Red Hat OpenShift all perform routine node maintenance that can trigger pod evictions with little or no warning.
- **You need to demonstrate operational compliance** — in regulated environments, the ability to show that critical messaging infrastructure is protected from unplanned disruption during infrastructure maintenance is often a compliance requirement.

### What You Get

Enabling PDB for IBM MQ Native HA in v10.0.1 gives you:

| Benefit | Description |
|---|---|
| **Protected message processing** | Kubernetes will not evict more than one pod at a time during cluster maintenance, preventing quorum loss and ensuring uninterrupted message processing even when nodes are drained for upgrades or patches. |
| **Visible pod health** | All three pods now report `2/2 Ready`, giving operations teams immediate confidence that the full Native HA cluster is healthy and message processing is protected. |
| **Role transparency** | The `mq.ibm.com/status` label (`active` / `replica`) makes it trivially easy to identify which pod is serving traffic at any time, without needing to exec into a pod and run `dspmq`. |
| **Minimal privilege** | The metadata sidecar uses a scoped, short-lived token to patch only the pods it owns — no cluster-wide permissions are required. |
| **Safe, coordinated updates** | The rolling update script handles replica-first restarts automatically, ensuring quorum is maintained throughout the update. Both interactive and automated (`manualAcceptance=false`) modes integrate seamlessly into CI/CD pipelines. |

### The Single Helm Flag That Matters

```yaml
queueManager:
  podDisruptionBudget:
    enable: true
```

That is all it takes. The Helm chart handles the PodDisruptionBudget, the RBAC resources, the sidecar injection, and the `MQ_ENABLE_READY_REPLICAS` configuration automatically. If you are running IBM MQ Native HA or Multi-instance on Kubernetes today, there is no reason not to enable this feature when you upgrade to IBM MQ v10.0.1.

---

## Resources

- [IBM MQ Helm Chart — GitHub](https://github.com/ibm-messaging/mq-helm)
- [IBM MQ Documentation — Native HA](https://www.ibm.com/docs/en/ibm-mq/latest?topic=managers-native-ha-overview)
- [Kubernetes — Configure Pod Disruption Budgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
- [Kubernetes — Native Sidecar Containers (v1.29 GA)](https://kubernetes.io/blog/2023/08/25/native-sidecar-containers/)
- Sample: [`samples/OpenShiftNativeHAWithPDB`](samples/OpenShiftNativeHAWithPDB/README.md)
- Rolling update script: [`samples/genericresources/rollingupdate/demoRollingUpdatePDB.sh`](samples/genericresources/rollingupdate/demoRollingUpdatePDB.sh)


