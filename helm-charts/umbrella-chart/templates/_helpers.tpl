{{/*
Expand the name of the chart.
*/}}
{{- define "enterprise-data-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "enterprise-data-platform.fullname" -}}
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
{{- define "enterprise-data-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "enterprise-data-platform.labels" -}}
helm.sh/chart: {{ include "enterprise-data-platform.chart" . }}
{{ include "enterprise-data-platform.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "enterprise-data-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "enterprise-data-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create image pull secret for tenant registry
*/}}
{{- define "enterprise-data-platform.imagePullSecret" -}}
{{- if .Values.global.imageRegistry.username }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .Values.global.imageRegistry.url .Values.global.imageRegistry.username .Values.global.imageRegistry.password (printf "%s:%s" .Values.global.imageRegistry.username .Values.global.imageRegistry.password | b64enc) | b64enc }}
{{- end }}
{{- end }}