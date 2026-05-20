{{/*
Expand the name of the chart.
*/}}
{{- define "safaricom-cc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "safaricom-cc.fullname" -}}
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
{{- define "safaricom-cc.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "safaricom-cc.labels" -}}
helm.sh/chart: {{ include "safaricom-cc.chart" . }}
{{ include "safaricom-cc.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "safaricom-cc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "safaricom-cc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: safaricom-cc
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "safaricom-cc.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "safaricom-cc.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
