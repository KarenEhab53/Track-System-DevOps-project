{{- define "track-system.fullname" -}}
track-system
{{- end -}}

{{- define "track-system.labels" -}}
app.kubernetes.io/part-of: track-system
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
