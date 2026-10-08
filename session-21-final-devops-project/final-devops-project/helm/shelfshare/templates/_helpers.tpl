{{- define "shelfshare.name" -}}{{ .Release.Name | trunc 50 | trimSuffix "-" }}{{- end -}}

{{- define "shelfshare.labels" -}}
app.kubernetes.io/name: shelfshare
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "shelfshare.selector" -}}
app.kubernetes.io/name: shelfshare
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "shelfshare.image" -}}
{{ printf "%s/%s/shelfshare-%s:%s" .root.Values.image.registry .root.Values.image.owner .name .root.Values.image.tag }}
{{- end -}}

{{- define "shelfshare.dbHost" -}}
{{ .Values.database.host | default (printf "%s-postgres" (include "shelfshare.name" .)) }}
{{- end -}}

{{- define "shelfshare.restricted" -}}
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
{{- end -}}
