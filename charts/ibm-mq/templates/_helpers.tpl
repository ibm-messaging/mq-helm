# © Copyright IBM Corporation 2021,2026
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
{{/*
Expand the name of the chart.
*/}}
{{- define "ibm-mq.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ibm-mq.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ibm-mq.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels

     Explictly decided not to include ibm-mq.additionalLabels
     In the future if this should be included then this is easy by
     copying the ibm-mq.selectorLabels approach

*/}}
{{- define "ibm-mq.labels" -}}
helm.sh/chart: {{ include "ibm-mq.chart" . }}
{{ include "ibm-mq.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common labels without version info

     Explictly decided not to include version numbers as this
     causes problems during a helm upgrade.

*/}}
{{- define "ibm-mq.labelsNoVersion" -}}
{{ include "ibm-mq.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ibm-mq.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ibm-mq.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* 
Pod Disruption Budget - selector label - used where traffic must
flow to the Active instance
*/}}
{{- define "ibm-mq.pdbSelectorLabels" -}}
{{- if .Values.queueManager.podDisruptionBudget.enable -}}
{{ .Values.queueManager.podDisruptionBudget.activeLabelKey }}: {{ .Values.queueManager.podDisruptionBudget.activeLabelValue }}
{{- end }}
{{ include "ibm-mq.selectorLabels" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ibm-mq.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ibm-mq.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the Data pvc claim
*/}}
{{- define "ibm-mq.pvcDataName" -}}
{{ .Values.persistence.dataPVC.name }}
{{- end }}

{{/*
Create the name of the Log pvc claim
*/}}
{{- define "ibm-mq.pvcLogName" -}}
{{ .Values.persistence.logPVC.name }}
{{- end }}

{{/*
Create the name of the QM pvc claim
*/}}
{{- define "ibm-mq.pvcQMName" -}}
{{ .Values.persistence.qmPVC.name }}
{{- end }}

{{/*
Create the name for the NativeHA pod0
*/}}
{{- define "ibm-mq.pod0.name" -}}
{{ include "ibm-mq.fullname" . }}-0
{{- end }}

{{/*
Create the name of the service dedicated to pod0
*/}}
{{- define "ibm-mq.pod0.service" -}}
{{ include "ibm-mq.fullname" . }}-replica-0
{{- end }}

{{/*
Create the name for the NativeHA pod1
*/}}
{{- define "ibm-mq.pod1.name" -}}
{{ include "ibm-mq.fullname" . }}-1
{{- end }}

{{/*
Create the name of the service dedicated to pod1
*/}}
{{- define "ibm-mq.pod1.service" -}}
{{ include "ibm-mq.fullname" . }}-replica-1
{{- end }}

{{/*
Create the name for the NativeHA pod2
*/}}
{{- define "ibm-mq.pod2.name" -}}
{{ include "ibm-mq.fullname" . }}-2
{{- end }}

{{/*
Create the name of the service dedicated to pod2
*/}}
{{- define "ibm-mq.pod2.service" -}}
{{ include "ibm-mq.fullname" . }}-replica-2
{{- end }}

{{/*
Additional annotations
*/}}
{{- define "ibm-mq.annotations" -}}
annotation1: "test"
annotation2: "test2"
{{- range $key, $value := .Values.metadata.annotations }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Additional additional labels
*/}}
{{- define "ibm-mq.additionalLabels" -}}
{{- range $key, $value := .Values.metadata.labels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{- define "ibm-mq.crr.localGroupsIndex" -}}
{{- $CRR_GROUP := .Values.queueManager.nativeha.nativehaGroup }}
{{- if not (quote $CRR_GROUP | empty) }}
  {{- range $index, $srcGroups := .Values.queueManager.nativeha.nativehaGroups }}
    {{- if eq $srcGroups.nativehaGroupId $CRR_GROUP }}
{{- $index }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "ibm-mq.crr.isLocalARecoveryGroup" -}}
{{- $CRR_GROUP := .Values.queueManager.nativeha.nativehaGroup }}
{{- if not (quote $CRR_GROUP | empty) }}
  {{- range $srcGroups := .Values.queueManager.nativeha.nativehaGroups }}
    {{- if (eq $srcGroups.nativehaGroupId $CRR_GROUP) }}
      {{- if (eq $srcGroups.role "Recovery") }}true{{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "ibm-mq.crr.remoteGroupsIndex" -}}
{{- $CRR_GROUP := .Values.queueManager.nativeha.nativehaGroup }}
{{- $count := 0 }}
{{- if not (quote $CRR_GROUP | empty) }}
 {{- range $index, $srcGroups := .Values.queueManager.nativeha.nativehaGroups }}
  {{- if not (eq $srcGroups.nativehaGroupId $CRR_GROUP) }}
   {{- if gt (int $count) 0 }};{{ end}}
{{- $index }}
   {{- $count = add1 $count }}
  {{- end }}
 {{- end }}
{{- end }}
{{- end }}

{{/*
Returns "true" if the PodDisruptionBudget should be created, empty string otherwise.
Usage: {{- if include "ibm-mq.pdbEnabled" . }}
*/}}
{{- define "ibm-mq.pdbEnabled" -}}
{{- if .Values.queueManager.podDisruptionBudget.enable -}}
true
{{- end -}}
{{- end -}}

{{/*
Validates PDB configuration and fails fast with a clear message when:
  - PDB is enabled but neither nativeha nor multiinstance is enabled
     (a single-replica deployment has no peer to absorb disruptions).
  - PDB is enabled and maxUnavailable is set but is not a positive integer
     or a valid percentage string (e.g. "50%").

Usage: place {{ include "ibm-mq.validatePdbMode" . }} near the top of any
template that creates the PDB resource, or once in a dedicated validate.yaml.
*/}}
{{- define "ibm-mq.validatePdbMode" -}}
{{- $nativeha      := .Values.queueManager.nativeha.enable -}}
{{- $multiinstance := .Values.queueManager.multiinstance.enable -}}
{{- $pdbEnabled    := .Values.queueManager.podDisruptionBudget.enable -}}
{{/* PDB requires a multi-replica topology */}}
{{- if and $pdbEnabled (not (or $nativeha $multiinstance)) -}}
  {{- fail "ibm-mq: podDisruptionBudget.enable requires either nativeha or multiinstance to be enabled (single-replica deployments cannot use a PDB)" -}}
{{- end -}}
{{/* PDB requires both annotation sets to be present */}}
{{- if $pdbEnabled -}}
  {{- if not .Values.metadata.annotations -}}
    {{- fail "ibm-mq: podDisruptionBudget.enable requires metadata.annotations to be set" -}}
  {{- end -}}
  {{- if not (index .Values.metadata "license_when_replica_or_standby") -}}
    {{- fail "ibm-mq: podDisruptionBudget.enable requires metadata.license_when_replica_or_standby to be set" -}}
  {{- end -}}
{{- end -}}
{{/* validate maxUnavailable when it is explicitly set */}}
{{- if $pdbEnabled -}}
  {{- $mu := .Values.queueManager.podDisruptionBudget.maxUnavailable -}}
  {{- if not (kindIs "invalid" $mu) -}}
    {{- if kindIs "string" $mu -}}
      {{- if not (regexMatch "^[1-9][0-9]*%$" $mu) -}}
        {{- fail (printf "ibm-mq: podDisruptionBudget.maxUnavailable \"%s\" is invalid. String values must be a percentage such as \"50%%\"" $mu) -}}
      {{- end -}}
    {{- else if kindIs "float64" $mu -}}
      {{- if or (lt (int $mu) 1) (gt (int $mu) 100) -}}
        {{- fail (printf "ibm-mq: podDisruptionBudget.maxUnavailable %d is invalid. Integer values must be between 1 and 100" (int $mu)) -}}
      {{- end -}}
    {{- else -}}
      {{- fail (printf "ibm-mq: podDisruptionBudget.maxUnavailable must be an integer or a percentage string (e.g. 1 or \"50%%\"), got type %s" (kindOf $mu)) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Returns the list of pod resourceNames for RBAC, scoped to the active topology:
  - nativeha:      pod-0, pod-1, pod-2
  - multiinstance: pod-0, pod-1
*/}}
{{- define "ibm-mq.pdb.podResourceNames" -}}
- {{ include "ibm-mq.pod0.name" . }}
- {{ include "ibm-mq.pod1.name" . }}
{{- if .Values.queueManager.nativeha.enable }}
- {{ include "ibm-mq.pod2.name" . }}
{{- end }}
{{- end }}
