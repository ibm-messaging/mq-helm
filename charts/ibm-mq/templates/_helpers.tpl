# © Copyright IBM Corporation 2021
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
